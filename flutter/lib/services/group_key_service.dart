import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';

class GroupKeyService {
  static final GroupKeyService instance = GroupKeyService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final CryptoService _cryptoService = CryptoService.instance;

  GroupKeyService._init();

  // Generate random 256-bit AES session key
  Future<String> generateSessionKey() async {
    final secureRandom = _getSecureRandom();
    final keyBytes = secureRandom.nextBytes(32); // 256 bits
    return base64Encode(keyBytes);
  }

  // Encrypt session key with RSA public key
  Future<String> encryptSessionKey(
    String sessionKeyBase64,
    String publicKeyPem,
  ) async {
    try {
      final sessionKeyBytes = base64Decode(sessionKeyBase64);
      final publicKey = _parsePublicKey(publicKeyPem);

      // Use PKCS1 encoding instead of OAEP for now (more compatible)
      final cipher = PKCS1Encoding(RSAEngine());
      cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
      
      if (cipher.inputBlockSize == 0) {
        throw Exception('Cipher inputBlockSize is 0 - RSA key invalid');
      }

      final encrypted = _processInBlocks(cipher, sessionKeyBytes);
      return base64Encode(encrypted);
    } catch (e, stackTrace) {
      print('❌ Encryption error: $e');
      print('Stack: $stackTrace');
      throw Exception('Failed to encrypt session key: $e');
    }
  }

  // Decrypt session key with RSA private key
  Future<String> decryptSessionKey(
    String encryptedKeyBase64,
    String privateKeyPem,
  ) async {
    try {
      final encryptedBytes = base64Decode(encryptedKeyBase64);
      final privateKey = _parsePrivateKey(privateKeyPem);

      // Use PKCS1 encoding (matching encryption)
      final cipher = PKCS1Encoding(RSAEngine());
      cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final decrypted = _processInBlocks(cipher, encryptedBytes);
      return base64Encode(decrypted);
    } catch (e) {
      throw Exception('Failed to decrypt session key: $e');
    }
  }

  // Encrypt group message with AES-256-GCM
  Future<Map<String, String>> encryptGroupMessage(
    String message,
    String sessionKeyBase64,
  ) async {
    try {
      final sessionKeyBytes = base64Decode(sessionKeyBase64);
      final messageBytes = utf8.encode(message);

      // Generate random IV (12 bytes for GCM)
      final secureRandom = _getSecureRandom();
      final iv = secureRandom.nextBytes(12);

      // Initialize cipher
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          true,
          AEADParameters(
            KeyParameter(sessionKeyBytes),
            128, // tag length in bits
            iv,
            Uint8List(0), // additional data
          ),
        );

      // Encrypt
      final ciphertext = cipher.process(messageBytes);

      // Extract authentication tag (last 16 bytes)
      final encryptedData = ciphertext.sublist(0, ciphertext.length - 16);
      final authTag = ciphertext.sublist(ciphertext.length - 16);

      return {
        'content': base64Encode(encryptedData),
        'iv': base64Encode(iv),
        'authTag': base64Encode(authTag),
      };
    } catch (e) {
      throw Exception('Failed to encrypt group message: $e');
    }
  }

  // Decrypt group message with AES-256-GCM
  Future<String> decryptGroupMessage(
    String encryptedContentBase64,
    String ivBase64,
    String authTagBase64,
    String sessionKeyBase64,
  ) async {
    try {
      final sessionKeyBytes = base64Decode(sessionKeyBase64);
      final encryptedBytes = base64Decode(encryptedContentBase64);
      final iv = base64Decode(ivBase64);
      final authTag = base64Decode(authTagBase64);

      // Combine ciphertext and auth tag
      final ciphertext = Uint8List.fromList([...encryptedBytes, ...authTag]);

      // Initialize cipher
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(sessionKeyBytes),
            128,
            iv,
            Uint8List(0),
          ),
        );

      // Decrypt
      final decrypted = cipher.process(ciphertext);
      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Failed to decrypt group message: $e');
    }
  }

  // Store session key in secure storage
  Future<void> storeSessionKey(String roomId, String sessionKeyBase64) async {
    await _storage.write(key: 'session_key_$roomId', value: sessionKeyBase64);
  }

  // Retrieve session key from secure storage
  Future<String?> getSessionKey(String roomId) async {
    return await _storage.read(key: 'session_key_$roomId');
  }

  // Delete session key (when leaving group)
  Future<void> deleteSessionKey(String roomId) async {
    await _storage.delete(key: 'session_key_$roomId');
  }

  // Helper: Get secure random generator
  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  // Helper: Parse RSA public key from PEM
  RSAPublicKey _parsePublicKey(String pem) {
    try {
      // Remove PEM headers and decode base64
      final key = pem
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(' ', '')
          .trim();
      
      if (key.isEmpty) {
        throw Exception('Empty public key after removing PEM headers');
      }
      
      final bytes = base64Decode(key);
      
      if (bytes.isEmpty) {
        throw Exception('Empty bytes after base64 decode');
      }
      
      // Parse using ASN1Parser
      final parser = ASN1Parser(bytes);
      final topSeq = parser.nextObject() as ASN1Sequence;
      
      if (topSeq.elements == null || topSeq.elements!.length < 2) {
        throw Exception('Invalid top sequence: ${topSeq.elements?.length} elements');
      }
      
      // Get the bit string containing the public key
      final publicKeyBitString = topSeq.elements![1];
      
      Uint8List publicKeyBytes;
      if (publicKeyBitString is ASN1BitString) {
        // Try to get bytes from bit string
        var valueBytes = publicKeyBitString.valueBytes;
        
        if (valueBytes != null && valueBytes.isNotEmpty) {
          // Skip first byte (unused bits indicator in BIT STRING)
          if (valueBytes.length > 1 && valueBytes[0] == 0x00) {
            publicKeyBytes = valueBytes.sublist(1);
          } else {
            publicKeyBytes = valueBytes;
          }
        } else {
          // Fallback: parse from encoded bytes
          final encoded = publicKeyBitString.encode();
          print('🔑 Encoded bitstring length: ${encoded.length}');
          
          // Skip tag (1 byte), length bytes, and unused bits (1 byte)
          var offset = 0;
          offset++; // skip tag (0x03)
          
          var lengthByte = encoded[offset++];
          if (lengthByte & 0x80 != 0) {
            var numLengthBytes = lengthByte & 0x7f;
            offset += numLengthBytes;
          }
          
          offset++; // skip unused bits byte
          publicKeyBytes = encoded.sublist(offset);
        }
      } else {
        throw Exception('Element 1 is not ASN1BitString: ${publicKeyBitString.runtimeType}');
      }
      
      // Parse the public key sequence
      final pkParser = ASN1Parser(publicKeyBytes);
      final pkSeq = pkParser.nextObject() as ASN1Sequence;
      
      if (pkSeq.elements == null || pkSeq.elements!.length < 2) {
        throw Exception('Invalid public key sequence');
      }
      
      final modulus = pkSeq.elements![0] as ASN1Integer;
      final exponent = pkSeq.elements![1] as ASN1Integer;
      
      if (modulus.integer == null || exponent.integer == null) {
        throw Exception('Modulus or exponent is null');
      }
      
      return RSAPublicKey(modulus.integer!, exponent.integer!);
    } catch (e, stackTrace) {
      print('❌ Error parsing public key: $e');
      print('Stack: $stackTrace');
      rethrow;
    }
  }

  // Helper: Parse RSA private key from PEM
  RSAPrivateKey _parsePrivateKey(String pem) {
    // Remove PEM headers and decode base64
    final key = pem
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
    
    final bytes = base64Decode(key);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    
    final modulus = topLevelSeq.elements![1] as ASN1Integer;
    final publicExponent = topLevelSeq.elements![2] as ASN1Integer;
    final privateExponent = topLevelSeq.elements![3] as ASN1Integer;
    final p = topLevelSeq.elements![4] as ASN1Integer;
    final q = topLevelSeq.elements![5] as ASN1Integer;
    
    return RSAPrivateKey(
      modulus.integer!,
      privateExponent.integer!,
      p.integer,
      q.integer,
    );
  }

  // Helper: Process data in blocks (RSA limitation)
  Uint8List _processInBlocks(AsymmetricBlockCipher cipher, Uint8List data) {
    final inputBlockSize = cipher.inputBlockSize;
    
    if (inputBlockSize == 0) {
      throw Exception('Invalid cipher: inputBlockSize is 0. Cipher may not be initialized properly.');
    }
    
    final numBlocks = (data.length / inputBlockSize).ceil();
    final output = <int>[];

    for (int i = 0; i < numBlocks; i++) {
      final start = i * inputBlockSize;
      final end = (i + 1) * inputBlockSize;
      final block = data.sublist(start, end > data.length ? data.length : end);
      output.addAll(cipher.process(block));
    }

    return Uint8List.fromList(output);
  }
}

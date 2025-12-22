import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1/asn1_object.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  static final CryptoService instance = CryptoService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Key storage keys
  static const String _privateKeyKey = 'ecdh_private_key';
  static const String _publicKeyKey = 'ecdh_public_key';

  // RSA key storage keys
  static const String _rsaPrivateKeyKey = 'rsa_private_key';
  static const String _rsaPublicKeyKey = 'rsa_public_key';

  CryptoService._init();

  // Generate ECDH key pair
  Future<Map<String, String>> generateKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();

    // Get keys
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    // Convert to base64 for storage
    final privateKeyBase64 = base64Encode(privateKeyBytes);
    final publicKeyBase64 = base64Encode(publicKey.bytes);

    // Store private key securely
    await _storage.write(key: _privateKeyKey, value: privateKeyBase64);
    await _storage.write(key: _publicKeyKey, value: publicKeyBase64);

    return {'privateKey': privateKeyBase64, 'publicKey': publicKeyBase64};
  }

  // Generate RSA-2048 key pair
  Future<Map<String, String>> generateRSAKeyPair() async {
    final keyParams = pc.RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      2048,
      64,
    );

    final secureRandom = _getSecureRandom();
    final rngParams = pc.ParametersWithRandom(
      keyParams,
      secureRandom,
    );

    final keyGenerator = pc.RSAKeyGenerator()
      ..init(rngParams);

    final pair = keyGenerator.generateKeyPair();
    final publicKey = pair.publicKey as pc.RSAPublicKey;
    final privateKey = pair.privateKey as pc.RSAPrivateKey;

    // Convert to PEM format
    final publicKeyPem = _encodePublicKeyToPem(publicKey);
    final privateKeyPem = _encodePrivateKeyToPem(privateKey);

    // Store keys securely
    await _storage.write(key: _rsaPrivateKeyKey, value: privateKeyPem);
    await _storage.write(key: _rsaPublicKeyKey, value: publicKeyPem);

    return {
      'privateKey': privateKeyPem,
      'publicKey': publicKeyPem,
    };
  }

  // Get stored ECDH keys
  Future<Map<String, String>?> getStoredKeys() async {
    final privateKey = await _storage.read(key: _privateKeyKey);
    final publicKey = await _storage.read(key: _publicKeyKey);

    if (privateKey == null || publicKey == null) {
      return null;
    }

    return {'privateKey': privateKey, 'publicKey': publicKey};
  }

  // Get stored RSA keys
  Future<Map<String, String>?> getStoredRSAKeys() async {
    final privateKey = await _storage.read(key: _rsaPrivateKeyKey);
    final publicKey = await _storage.read(key: _rsaPublicKeyKey);

    if (privateKey == null || publicKey == null ||
        privateKey.isEmpty || publicKey.isEmpty) {
      print('⚠️ RSA keys not found in storage or empty');
      return null;
    }

    print('✅ RSA keys loaded from storage');
    return {'privateKey': privateKey, 'publicKey': publicKey};
  }

  // Get RSA public key only
  Future<String?> getRSAPublicKey() async {
    return await _storage.read(key: _rsaPublicKeyKey);
  }

  // Get RSA private key only
  Future<String?> getRSAPrivateKey() async {
    return await _storage.read(key: _rsaPrivateKeyKey);
  }

  // Compute shared secret using ECDH
  Future<String> computeSharedSecret(
    String myPrivateKeyBase64,
    String otherPublicKeyBase64,
  ) async {
    final algorithm = X25519();

    // Decode keys
    final myPrivateKeyBytes = base64Decode(myPrivateKeyBase64);
    final otherPublicKeyBytes = base64Decode(otherPublicKeyBase64);

    // Create key pair from private key
    final myKeyPair = await algorithm.newKeyPairFromSeed(myPrivateKeyBytes);

    // Create public key object
    final otherPublicKey = SimplePublicKey(
      otherPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // Compute shared secret
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: otherPublicKey,
    );

    final sharedSecretBytes = await sharedSecret.extractBytes();
    return base64Encode(sharedSecretBytes);
  }

  // Encrypt message using AES-256-GCM
  Future<String> encryptMessage(
    String message,
    String sharedSecretBase64,
  ) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);

      // Create secret key
      final secretKey = SecretKey(sharedSecretBytes);

      // Encrypt
      final secretBox = await algorithm.encrypt(
        utf8.encode(message),
        secretKey: secretKey,
      );

      // Combine nonce + ciphertext + mac
      final combined = <int>[
        ...secretBox.nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ];

      return base64Encode(combined);
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  // Decrypt message using AES-256-GCM
  Future<String> decryptMessage(
    String encryptedMessage,
    String sharedSecretBase64,
  ) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);
      final combined = base64Decode(encryptedMessage);

      // Extract components (nonce: 12 bytes, mac: 16 bytes, rest: ciphertext)
      final nonce = combined.sublist(0, 12);
      final mac = combined.sublist(combined.length - 16);
      final cipherText = combined.sublist(12, combined.length - 16);

      // Create secret key
      final secretKey = SecretKey(sharedSecretBytes);

      // Decrypt
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

      final decrypted = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  // Encrypt file data
  Future<Uint8List> encryptFile(
    Uint8List fileData,
    String sharedSecretBase64,
  ) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);
      final secretKey = SecretKey(sharedSecretBytes);

      final secretBox = await algorithm.encrypt(fileData, secretKey: secretKey);

      // Combine nonce + ciphertext + mac
      final combined = Uint8List.fromList([
        ...secretBox.nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      return combined;
    } catch (e) {
      print('File encryption error: $e');
      rethrow;
    }
  }

  // Decrypt file data
  Future<Uint8List> decryptFile(
    Uint8List encryptedData,
    String sharedSecretBase64,
  ) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);
      final secretKey = SecretKey(sharedSecretBytes);

      // Extract components
      final nonce = encryptedData.sublist(0, 12);
      final mac = encryptedData.sublist(encryptedData.length - 16);
      final cipherText = encryptedData.sublist(12, encryptedData.length - 16);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

      final decrypted = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      print('File decryption error: $e');
      rethrow;
    }
  }

  // Clear stored keys
  Future<void> clearKeys() async {
    await _storage.delete(key: _privateKeyKey);
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _rsaPrivateKeyKey);
    await _storage.delete(key: _rsaPublicKeyKey);
  }

  // Helper: Get secure random generator
  pc.SecureRandom _getSecureRandom() {
    final secureRandom = pc.FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  // Helper: Encode RSA public key to PEM
  String _encodePublicKeyToPem(pc.RSAPublicKey publicKey) {
    try {
      // Create the inner RSA public key sequence
      final publicKeySeq = ASN1Sequence();
      publicKeySeq.add(ASN1Integer(publicKey.modulus!));
      publicKeySeq.add(ASN1Integer(publicKey.exponent!));
      final publicKeySeqBytes = publicKeySeq.encode();
      
      print('🔨 Public key seq bytes length: ${publicKeySeqBytes.length}');
      
      // Create algorithm identifier
      final algorithmSeq = ASN1Sequence();
      final algorithmOid = ASN1Object.fromBytes(Uint8List.fromList([
        0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01
      ]));
      final algorithmParams = ASN1Object.fromBytes(Uint8List.fromList([0x05, 0x00]));
      algorithmSeq.add(algorithmOid);
      algorithmSeq.add(algorithmParams);
      
      // Manually create BIT STRING wrapper
      // BIT STRING format: tag(0x03) + length + unused_bits(0x00) + data
      final bitStringContent = [0x00] + publicKeySeqBytes.toList();
      final bitStringBytes = _encodeDER(0x03, bitStringContent);
      
      print('🔨 BitString bytes length: ${bitStringBytes.length}');
      
      // Create outer SEQUENCE manually
      final algorithmSeqBytes = algorithmSeq.encode();
      final outerSeqContent = algorithmSeqBytes.toList() + bitStringBytes;
      final outerSeqBytes = _encodeDER(0x30, outerSeqContent);
      
      print('🔨 Final DER bytes length: ${outerSeqBytes.length}');
      
      // Encode to base64
      final base64Str = base64.encode(outerSeqBytes);
      
      print('🔨 Base64 length: ${base64Str.length}');
      
      // Format as PEM with line breaks every 64 characters
      final pemLines = <String>[];
      for (var i = 0; i < base64Str.length; i += 64) {
        final end = (i + 64 < base64Str.length) ? i + 64 : base64Str.length;
        pemLines.add(base64Str.substring(i, end));
      }
      
      final pem = '-----BEGIN PUBLIC KEY-----\n${pemLines.join('\n')}\n-----END PUBLIC KEY-----';
      print('🔨 Final PEM length: ${pem.length}');
      
      return pem;
    } catch (e, stack) {
      print('❌ Error encoding public key to PEM: $e');
      print('Stack: $stack');
      rethrow;
    }
  }
  
  // Helper: Encode DER format (tag + length + value)
  List<int> _encodeDER(int tag, List<int> value) {
    final result = <int>[tag];
    
    // Encode length
    if (value.length < 128) {
      result.add(value.length);
    } else {
      final lengthBytes = <int>[];
      var len = value.length;
      while (len > 0) {
        lengthBytes.insert(0, len & 0xff);
        len >>= 8;
      }
      result.add(0x80 | lengthBytes.length);
      result.addAll(lengthBytes);
    }
    
    result.addAll(value);
    return result;
  }

  // Helper: Encode RSA private key to PEM
  String _encodePrivateKeyToPem(pc.RSAPrivateKey privateKey) {
    final version = ASN1Integer(BigInt.from(0));
    final modulus = ASN1Integer(privateKey.n!);
    final publicExponent = ASN1Integer(privateKey.exponent!);
    final privateExponent = ASN1Integer(privateKey.privateExponent!);
    final p = ASN1Integer(privateKey.p!);
    final q = ASN1Integer(privateKey.q!);
    final dP = privateKey.privateExponent! % (privateKey.p! - BigInt.one);
    final dQ = privateKey.privateExponent! % (privateKey.q! - BigInt.one);
    final iQ = privateKey.q!.modInverse(privateKey.p!);

    final seq = ASN1Sequence();
    seq.add(version);
    seq.add(modulus);
    seq.add(publicExponent);
    seq.add(privateExponent);
    seq.add(p);
    seq.add(q);
    seq.add(ASN1Integer(dP));
    seq.add(ASN1Integer(dQ));
    seq.add(ASN1Integer(iQ));

    final encodedSeqBytes = seq.encodedBytes;
    final dataBase64 = base64.encode(encodedSeqBytes != null ? encodedSeqBytes.toList() : []);
    return '-----BEGIN RSA PRIVATE KEY-----\n$dataBase64\n-----END RSA PRIVATE KEY-----';
  }
}

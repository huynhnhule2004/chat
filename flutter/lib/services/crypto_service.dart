import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  static final CryptoService instance = CryptoService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Key storage keys
  static const String _privateKeyKey = 'ecdh_private_key';
  static const String _publicKeyKey = 'ecdh_public_key';

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
    
    return {
      'privateKey': privateKeyBase64,
      'publicKey': publicKeyBase64,
    };
  }

  // Get stored keys
  Future<Map<String, String>?> getStoredKeys() async {
    final privateKey = await _storage.read(key: _privateKeyKey);
    final publicKey = await _storage.read(key: _publicKeyKey);
    
    if (privateKey == null || publicKey == null) {
      return null;
    }
    
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
    };
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
  Future<String> encryptMessage(String message, String sharedSecretBase64) async {
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
  Future<String> decryptMessage(String encryptedMessage, String sharedSecretBase64) async {
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
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      
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
  Future<Uint8List> encryptFile(Uint8List fileData, String sharedSecretBase64) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);
      final secretKey = SecretKey(sharedSecretBytes);
      
      final secretBox = await algorithm.encrypt(
        fileData,
        secretKey: secretKey,
      );
      
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
  Future<Uint8List> decryptFile(Uint8List encryptedData, String sharedSecretBase64) async {
    try {
      final algorithm = AesGcm.with256bits();
      final sharedSecretBytes = base64Decode(sharedSecretBase64);
      final secretKey = SecretKey(sharedSecretBytes);
      
      // Extract components
      final nonce = encryptedData.sublist(0, 12);
      final mac = encryptedData.sublist(encryptedData.length - 16);
      final cipherText = encryptedData.sublist(12, encryptedData.length - 16);
      
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      
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
  }
}

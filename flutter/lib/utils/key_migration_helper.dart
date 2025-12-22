import '../services/crypto_service.dart';

/// Helper class to ensure RSA keys exist for group chat functionality
class KeyMigrationHelper {
  static final CryptoService _cryptoService = CryptoService.instance;

  /// Check if RSA keys exist, generate if not
  /// Call this after login for existing users who registered before RSA support
  static Future<void> ensureRSAKeysExist() async {
    try {
      final existingKeys = await _cryptoService.getStoredRSAKeys();
      
      if (existingKeys == null) {
        print('⚠️ RSA keys not found. Generating new RSA keys for group chat...');
        final newKeys = await _cryptoService.generateRSAKeyPair();
        print('✅ RSA keys generated successfully');
        print('📋 Public key preview: ${newKeys['publicKey']?.substring(0, 50)}...');
        
        // TODO: Optionally sync public key with server
        // await ApiService.instance.updateRSAPublicKey(newKeys['publicKey']!);
      } else {
        print('✅ RSA keys already exist');
      }
    } catch (e) {
      print('❌ Error ensuring RSA keys: $e');
      // Don't throw - allow app to continue functioning
    }
  }

  /// Get RSA public key, generate if not exists
  static Future<String> getRSAPublicKey() async {
    await ensureRSAKeysExist();
    final publicKey = await _cryptoService.getRSAPublicKey();
    if (publicKey == null) {
      throw Exception('Failed to get or generate RSA public key');
    }
    return publicKey;
  }

  /// Get RSA private key, generate if not exists
  static Future<String> getRSAPrivateKey() async {
    await ensureRSAKeysExist();
    final privateKey = await _cryptoService.getRSAPrivateKey();
    if (privateKey == null) {
      throw Exception('Failed to get or generate RSA private key');
    }
    return privateKey;
  }
}

class AppConfig {
  // Server configuration
  // Use 'http://10.0.2.2:3000' for Android Emulator
  // Use 'http://localhost:3000' for iOS Simulator, Windows, or Web
  // Use 'http://YOUR_IP:3000' for physical device
  static const String baseUrl = 'http://localhost:3000';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;
  
  // Message limits
  static const int messagesPerPage = 50;
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  
  // Encryption
  static const String keyAlgorithm = 'ECDH';
  static const String encryptionAlgorithm = 'AES-256-GCM';
}

class StorageInfo {
  final int totalBytes;
  final int freeBytes;
  final int usedByApp;
  final Map<String, ChatStorageInfo> chatStorages;

  StorageInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.usedByApp,
    required this.chatStorages,
  });

  int get usedBytes => totalBytes - freeBytes;

  double get usedPercentage =>
      totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0;

  double get appPercentage =>
      totalBytes > 0 ? (usedByApp / totalBytes) * 100 : 0;

  String get totalSize => formatBytes(totalBytes);
  String get freeSize => formatBytes(freeBytes);
  String get usedSize => formatBytes(usedBytes);
  String get appSize => formatBytes(usedByApp);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class ChatStorageInfo {
  final String userId;
  final String username;
  final int messageCount;
  final int databaseSize;
  final int mediaSize;
  final int cacheSize;
  final List<FileStorageInfo> files;

  ChatStorageInfo({
    required this.userId,
    required this.username,
    required this.messageCount,
    required this.databaseSize,
    required this.mediaSize,
    required this.cacheSize,
    required this.files,
  });

  int get totalSize => databaseSize + mediaSize + cacheSize;

  String get formattedTotal => StorageInfo.formatBytes(totalSize);
  String get formattedMedia => StorageInfo.formatBytes(mediaSize);
  String get formattedCache => StorageInfo.formatBytes(cacheSize);
}

class FileStorageInfo {
  final String path;
  final String type; // 'image', 'video', 'file'
  final int size;
  final DateTime uploadedAt;

  FileStorageInfo({
    required this.path,
    required this.type,
    required this.size,
    required this.uploadedAt,
  });

  String get formattedSize => StorageInfo.formatBytes(size);
}

class StorageAnalysisParams {
  final String appDir;
  final String dbPath;

  StorageAnalysisParams({required this.appDir, required this.dbPath});
}

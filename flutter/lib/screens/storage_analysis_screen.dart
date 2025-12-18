import 'package:flutter/material.dart';
import '../models/storage_info.dart';
import '../services/storage_service.dart';

class StorageAnalysisScreen extends StatefulWidget {
  const StorageAnalysisScreen({super.key});

  @override
  State<StorageAnalysisScreen> createState() => _StorageAnalysisScreenState();
}

class _StorageAnalysisScreenState extends State<StorageAnalysisScreen> {
  final _storageService = StorageService();
  StorageInfo? _storageInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _analyzeStorage();
  }

  Future<void> _analyzeStorage() async {
    setState(() => _isLoading = true);

    try {
      final info = await _storageService.analyzeStorage();
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error analyzing storage: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _analyzeStorage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing storage...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take a while',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _storageInfo == null
          ? const Center(child: Text('No storage data available'))
          : RefreshIndicator(
              onRefresh: _analyzeStorage,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDeviceStorageCard(),
                  const SizedBox(height: 16),
                  _buildAppStorageCard(),
                  const SizedBox(height: 16),
                  _buildCleanupSection(),
                  const SizedBox(height: 16),
                  _buildChatStorageList(),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceStorageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Device Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _storageInfo!.usedPercentage / 100,
                minHeight: 24,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(
                  _getStorageColor(_storageInfo!.usedPercentage),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Storage info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStorageInfoItem(
                  'Used',
                  _storageInfo!.usedSize,
                  '${_storageInfo!.usedPercentage.toStringAsFixed(1)}%',
                ),
                _buildStorageInfoItem(
                  'Free',
                  _storageInfo!.freeSize,
                  '${(100 - _storageInfo!.usedPercentage).toStringAsFixed(1)}%',
                ),
                _buildStorageInfoItem('Total', _storageInfo!.totalSize, '100%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppStorageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.app_shortcut,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'App Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total app usage', style: TextStyle(fontSize: 16)),
                Text(
                  _storageInfo!.appSize,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_storageInfo!.appPercentage.toStringAsFixed(2)}% of device storage',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cleaning_services,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Storage Cleanup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Level 1: Clear Cache
            _buildCleanupOption(
              icon: Icons.cached,
              title: 'Clear Cache',
              subtitle: 'Remove temporary files and thumbnails',
              level: 'Level 1',
              color: Colors.green,
              onTap: () => _clearCache(),
            ),
            const Divider(),

            // Level 2: Delete Old Messages
            _buildCleanupOption(
              icon: Icons.access_time,
              title: 'Delete Old Messages',
              subtitle: 'Remove messages older than selected period',
              level: 'Level 3',
              color: Colors.orange,
              onTap: () => _showDeleteOldMessagesDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String level,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          Text(title),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildChatStorageList() {
    if (_storageInfo!.chatStorages.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No chat data found')),
        ),
      );
    }

    final sortedChats = _storageInfo!.chatStorages.values.toList()
      ..sort((a, b) => b.totalSize.compareTo(a.totalSize));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Storage by Chat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...sortedChats.map((chat) => _buildChatStorageItem(chat)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatStorageItem(ChatStorageInfo chat) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(chat.username[0].toUpperCase())),
          title: Text(chat.username),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${chat.messageCount} messages',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (chat.mediaSize > 0) ...[
                    Icon(Icons.image, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      chat.formattedMedia,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (chat.cacheSize > 0) ...[
                    Icon(Icons.cached, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      chat.formattedCache,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                chat.formattedTotal,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _showDeleteChatDialog(chat),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildStorageInfoItem(String label, String value, String percentage) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          percentage,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Color _getStorageColor(double percentage) {
    if (percentage < 70) return Colors.green;
    if (percentage < 85) return Colors.orange;
    return Colors.red;
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove temporary files and thumbnails. Your messages and media will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final deletedSize = await _storageService.clearCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cleared ${StorageInfo.formatBytes(deletedSize)} of cache',
              ),
            ),
          );
          await _analyzeStorage();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
        }
      }
    }
  }

  Future<void> _showDeleteChatDialog(ChatStorageInfo chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat History'),
        content: Text(
          'Delete all messages and files from ${chat.username}?\n\n'
          'This will free up ${chat.formattedTotal}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final deletedSize = await _storageService.deleteChatHistory(
          chat.userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${StorageInfo.formatBytes(deletedSize)}'),
            ),
          );
          await _analyzeStorage();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting chat: $e')));
        }
      }
    }
  }

  Future<void> _showDeleteOldMessagesDialog() async {
    Duration? selectedDuration;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Old Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Delete messages older than:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('3 months'),
              onTap: () {
                selectedDuration = const Duration(days: 90);
                Navigator.pop(context, true);
              },
            ),
            ListTile(
              title: const Text('6 months'),
              onTap: () {
                selectedDuration = const Duration(days: 180);
                Navigator.pop(context, true);
              },
            ),
            ListTile(
              title: const Text('1 year'),
              onTap: () {
                selectedDuration = const Duration(days: 365);
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && selectedDuration != null && mounted) {
      setState(() => _isLoading = true);

      try {
        final deletedSize = await _storageService.deleteOldMessages(
          selectedDuration!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${StorageInfo.formatBytes(deletedSize)}'),
            ),
          );
          await _analyzeStorage();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting old messages: $e')),
          );
        }
      }
    }
  }
}

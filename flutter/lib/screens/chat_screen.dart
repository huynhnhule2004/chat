import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/forward_service.dart';
import 'forward_contact_selection_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String username;

  const ChatScreen({super.key, required this.userId, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _isSending = false; // Prevent duplicate sends

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.userId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTyping() {
    context.read<ChatProvider>().sendTyping(widget.userId, true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      context.read<ChatProvider>().sendTyping(widget.userId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Prevent duplicate sends
    if (_isSending) return;
    _isSending = true;

    _messageController.clear();
    context.read<ChatProvider>().sendTyping(widget.userId, false);

    try {
      await context.read<ChatProvider>().sendMessage(
        widget.userId,
        text,
        'text',
      );
      _scrollToBottom();
      // Auto-focus for next message
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      _isSending = false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _uploadAndSendFile(result.files.single.path!, 'image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final fileType =
            result.files.single.extension == 'mp4' ||
                result.files.single.extension == 'mov'
            ? 'video'
            : 'file';

        await _uploadAndSendFile(result.files.single.path!, fileType);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  Future<void> _uploadAndSendFile(String filePath, String messageType) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading...')));
      }

      // Upload file
      final chatProvider = context.read<ChatProvider>();
      final fileUrl = await chatProvider.uploadFile(filePath);

      // Send message with file URL
      await chatProvider.sendMessage(widget.userId, fileUrl, messageType);

      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.username),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final isTyping = chatProvider.isUserTyping(widget.userId);
                return Text(
                  isTyping ? 'typing...' : '',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.getMessages(widget.userId);
                final currentUserId = chatProvider.currentUser?.id;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return _MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () => _showAttachmentOptions(context),
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _onTyping(),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery / Images'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Files'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, message),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Forward badge
              if (message.isForwarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forward,
                        size: 12,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Forwarded${message.forwardedFrom != null ? ' from ${message.forwardedFrom}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

              // Message content
              _buildMessageContent(context),
              const SizedBox(height: 4),

              // Timestamp
              Text(
                DateFormat.jm().format(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _forwardMessage(context, message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy to clipboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement delete message
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forwardMessage(BuildContext context, Message message) async {
    try {
      // Step 1: Show contact selection screen
      final selectedContacts = await Navigator.push<List<User>>(
        context,
        MaterialPageRoute(
          builder: (context) => const ForwardContactSelectionScreen(),
        ),
      );

      if (selectedContacts == null || selectedContacts.isEmpty) {
        return;
      }

      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Step 2: Get current user info
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final currentUser = chatProvider.currentUser;

      if (currentUser == null) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Current user not found')),
        );
        return;
      }

      // Step 3: Forward message with re-encryption
      final forwardedMessages = await ForwardService.instance.forwardMessage(
        originalMessage: message,
        recipients: selectedContacts,
        currentUserId: currentUser.id,
        originalSenderUsername: currentUser.username,
      );

      // Step 4: Send forwarded messages via socket
      for (final forwardedMsg in forwardedMessages) {
        await chatProvider.sendMessage(
          forwardedMsg.receiverId,
          forwardedMsg.content,
          forwardedMsg.messageType,
          fileUrl: forwardedMsg.fileUrl,
          encryptedFileKey: forwardedMsg.encryptedFileKey,
          isForwarded: true,
          originalSenderId: forwardedMsg.originalSenderId,
          forwardedFrom: forwardedMsg.forwardedFrom,
        );
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message forwarded to ${selectedContacts.length} contact(s)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading if open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to forward message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.messageType) {
      case 'image':
        return Image.network(
          message.content,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Text('Failed to load image');
          },
        );

      case 'video':
        return InkWell(
          onTap: () {
            // TODO: Open video player
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video player not implemented')),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, size: 32),
                SizedBox(width: 8),
                Text('Play Video'),
              ],
            ),
          ),
        );

      case 'file':
        return InkWell(
          onTap: () {
            // TODO: Download file
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download not implemented')),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 32),
                SizedBox(width: 8),
                Text('Download File'),
              ],
            ),
          ),
        );

      default:
        return Text(
          message.content,
          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
        );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/room.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../services/group_key_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../database/database_helper.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final Room room;

  const GroupChatScreen({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroupKeyService _groupKeyService = GroupKeyService.instance;
  final SocketService _socketService = SocketService.instance;
  final ApiService _apiService = ApiService.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _sessionKey;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    try {
      // Get current user from provider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _currentUserId = chatProvider.currentUser?.id;
      
      print('📋 Current user: $_currentUserId');
      print('📋 Token exists: ${chatProvider.token != null}');
      print('📋 Socket connected: ${_socketService.isConnected}');

      // Try to ensure socket is connected
      if (!_socketService.isConnected) {
        print('⚠️ Socket not connected, attempting to reconnect...');
        final token = chatProvider.token;
        if (token != null) {
          print('🔑 Token found, connecting socket...');
          _socketService.connect(token);
          // Wait for connection with timeout
          int attempts = 0;
          while (!_socketService.isConnected && attempts < 10) {
            await Future.delayed(const Duration(milliseconds: 300));
            attempts++;
            print('⏳ Waiting for socket... attempt $attempts/10');
          }
          
          if (_socketService.isConnected) {
            print('✅ Socket reconnected successfully');
          } else {
            print('⚠️ Socket connection timeout - continuing without real-time updates');
          }
        } else {
          print('❌ No token found');
        }
      } else {
        print('✅ Socket already connected');
      }

      // Get session key from secure storage
      _sessionKey = await _groupKeyService.getSessionKey(widget.room.id);

      if (_sessionKey == null) {
        print('⚠️ No session key found - pending approval');
      } else {
        print('🔑 Session key found');
        // Join group room via socket if connected
        if (_socketService.isConnected) {
          _socketService.joinGroup(widget.room.id);
          print('✅ Joined group room: ${widget.room.id}');
        }
      }

      // Load messages from database
      await _loadMessages();
    } catch (e) {
      print('❌ Error loading group data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesData = await _db.getRoomMessages(widget.room.id);

      // Convert to Message objects and decrypt
      final decryptedMessages = <Message>[];
      for (final msgData in messagesData) {
        try {
          final msg = Message.fromJson(msgData);
          if (_sessionKey != null && msg.iv != null && msg.authTag != null) {
            final decryptedContent = await _groupKeyService.decryptGroupMessage(
              msg.content,
              msg.iv!,
              msg.authTag!,
              _sessionKey!,
            );
            decryptedMessages.add(msg.copyWith(content: decryptedContent));
          } else {
            decryptedMessages.add(msg);
          }
        } catch (e) {
          print('Failed to decrypt message: $e');
        }
      }

      setState(() => _messages = decryptedMessages);
      _scrollToBottom();
    } catch (e) {
      print('Failed to load messages: $e');
    }
  }

  void _setupSocketListeners() {
    _socketService.onGroupMessage((message) {
      if (message.roomId == widget.room.id) {
        _decryptAndAddMessage(message);
      }
    });

    _socketService.onMemberJoined((data) {
      if (data['roomId'] == widget.room.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data['username']} joined the group')),
        );
      }
    });

    _socketService.onMemberLeft((data) {
      if (data['roomId'] == widget.room.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data['username']} left the group')),
        );
      }
    });
  }

  Future<void> _decryptAndAddMessage(Message message) async {
    try {
      if (_sessionKey != null && message.iv != null && message.authTag != null) {
        final decryptedContent = await _groupKeyService.decryptGroupMessage(
          message.content,
          message.iv!,
          message.authTag!,
          _sessionKey!,
        );
        setState(() {
          _messages.add(message.copyWith(content: decryptedContent));
        });
      } else {
        setState(() => _messages.add(message));
      }
      _scrollToBottom();
    } catch (e) {
      print('Failed to decrypt incoming message: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    
    final text = _messageController.text.trim();
    if (text.isEmpty || _sessionKey == null) return;

    // Check socket connection
    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please check your connection.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Encrypt message with session key
      final encrypted = await _groupKeyService.encryptGroupMessage(
        text,
        _sessionKey!,
      );

      // Send via socket
      _socketService.sendGroupMessage(
        roomId: widget.room.id,
        encryptedContent: encrypted['content']!,
        iv: encrypted['iv']!,
        authTag: encrypted['authTag']!,
        messageType: 'text',
      );

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.leaveGroup(widget.room.id);
      
      // Delete local data
      await _groupKeyService.deleteSessionKey(widget.room.id);
      await _db.deleteRoom(widget.room.id);
      
      if (!mounted) return;
      
      Navigator.pop(context); // Close info sheet
      Navigator.pop(context); // Go back to group list
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave group: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
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

    if (confirm != true) return;

    try {
      await _apiService.deleteGroup(widget.room.id);
      
      // Delete local data
      await _groupKeyService.deleteSessionKey(widget.room.id);
      await _db.deleteRoom(widget.room.id);
      
      if (!mounted) return;
      
      Navigator.pop(context); // Close info sheet
      Navigator.pop(context); // Go back to group list
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete group: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildGroupInfoSheet(),
    );
  }

  Widget _buildGroupInfoSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Group avatar & name
              CircleAvatar(
                radius: 50,
                backgroundImage: widget.room.avatar != null
                    ? NetworkImage(widget.room.avatar!)
                    : null,
                child: widget.room.avatar == null
                    ? const Icon(Icons.group, size: 50)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.room.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.room.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.room.description!,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              // Group stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    Icons.people,
                    '${widget.room.memberCount ?? 0}',
                    'Members',
                  ),
                  _buildStatItem(
                    Icons.lock,
                    'E2EE',
                    'Encrypted',
                  ),
                  _buildStatItem(
                    widget.room.isPrivate
                        ? Icons.lock_outline
                        : Icons.public,
                    widget.room.isPrivate ? 'Private' : 'Public',
                    'Privacy',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('View Members'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Show members list
                      },
                    ),
                    if (_currentUserId == widget.room.ownerId) ...[
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Group Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Show settings
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.vpn_key),
                        title: const Text('Rotate Session Key'),
                        subtitle: const Text('Generate new encryption key'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Rotate key
                        },
                      ),
                    ],
                    const Divider(),
                    if (_currentUserId == widget.room.ownerId)
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text(
                          'Delete Group',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: _deleteGroup,
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.exit_to_app, color: Colors.red),
                        title: const Text(
                          'Leave Group',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: _leaveGroup,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.room.avatar != null
                  ? NetworkImage(widget.room.avatar!)
                  : null,
              child: widget.room.avatar == null
                  ? const Icon(Icons.group, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${widget.room.memberCount ?? 0} members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // E2EE indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green[50],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Messages are end-to-end encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Say hi to the group!',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return MessageBubble(
                            message: message,
                            isMe: false, // TODO: Check if current user
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
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // TODO: Attach file
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

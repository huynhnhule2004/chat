import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../models/conversation.dart';
import '../widgets/user_avatar.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (chatProvider.currentUser?.isAdmin == true) {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'Admin Dashboard',
                  onPressed: () {
                    Navigator.of(context).pushNamed('/admin');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showUserSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final conversations = chatProvider.conversations;

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the search icon to find users',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationTile(conversation: conversation);
            },
          );
        },
      ),
    );
  }

  Future<void> _showUserSearch(BuildContext context) async {
    final result = await showSearch(
      context: context,
      delegate: UserSearchDelegate(),
    );

    if (result != null && context.mounted) {
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {'userId': result['id'], 'username': result['username']},
      );
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: UserAvatar(
        username: conversation.username,
        avatarUrl: conversation.avatar,
        size: 48,
      ),
      title: Text(
        conversation.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _getMessagePreview(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastTimestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).pushNamed(
          '/chat',
          arguments: {
            'userId': conversation.userId,
            'username': conversation.username,
          },
        );
      },
    );
  }

  String _getMessagePreview() {
    switch (conversation.messageType) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'file':
        return '📎 File';
      default:
        return conversation.lastMessage;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat.jm().format(time);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat.E().format(time);
    } else {
      return DateFormat.yMd().format(time);
    }
  }
}

class UserSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Search for users...'));
    }

    return FutureBuilder(
      future: context.read<ChatProvider>().searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(user.username[0].toUpperCase()),
              ),
              title: Text(user.username),
              onTap: () {
                close(context, {'id': user.id, 'username': user.username});
              },
            );
          },
        );
      },
    );
  }
}

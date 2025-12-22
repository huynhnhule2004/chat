import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../database/database_helper.dart';
import '../../models/room.dart';
import 'create_group_screen.dart';
import 'join_group_dialog.dart';
import 'group_chat_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({Key? key}) : super(key: key);

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Room> _myGroups = [];
  List<Room> _publicGroups = [];
  bool _isLoadingMy = true;
  bool _isLoadingPublic = false;

  final ApiService _apiService = ApiService.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Delay to ensure context is ready
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _loadMyGroups();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyGroups() async {
    setState(() => _isLoadingMy = true);
    try {
      print('🔄 Loading my groups...');
      // Load from server
      final response = await _apiService.getMyGroups();
      print('📦 Server response: $response');
      final serverGroups = (response['rooms'] as List)
          .map((json) => Room.fromJson(json))
          .toList();
      print('✅ Loaded ${serverGroups.length} groups');

      // Clear old groups from database first
      final db = await _db.database;
      await db.delete('rooms');

      // Update local database with fresh data from server
      for (final room in serverGroups) {
        await _db.insertRoom(room.toJson());
      }

      if (mounted) {
        setState(() => _myGroups = serverGroups);
      }
    } catch (e) {
      print('❌ Failed to load groups: $e');
      // Don't show error on 404 - it's normal when no groups exist
      if (mounted && !e.toString().contains('404')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load groups: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMy = false);
      }
    }
  }

  Future<void> _loadPublicGroups() async {
    setState(() => _isLoadingPublic = true);
    try {
      final response = await _apiService.discoverPublicGroups();
      final groups = (response['rooms'] as List)
          .map((json) => Room.fromJson(json))
          .toList();
      if (mounted) {
        setState(() => _publicGroups = groups);
      }
    } catch (e) {
      print('Failed to load public groups: $e');
      // Don't show error on 404 - it's normal when no groups exist
      if (mounted && !e.toString().contains('404')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load public groups: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPublic = false);
      }
    }
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push<Room>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );

    if (result != null) {
      // Switch to My Groups tab
      _tabController.animateTo(0);
      _loadMyGroups();
    }
  }

  Future<void> _joinGroup(Room room) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => JoinGroupDialog(room: room),
    );

    if (result == true) {
      _loadMyGroups();
    }
  }

  void _openGroupChat(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'My Groups'),
              Tab(text: 'Discover'),
            ],
            onTap: (index) {
              if (index == 1 && _publicGroups.isEmpty) {
                _loadPublicGroups();
              }
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Groups Tab
          _buildMyGroupsTab(),
          // Discover Tab
          _buildDiscoverTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    if (_isLoadingMy) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group or join one to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyGroups,
      child: ListView.builder(
        itemCount: _myGroups.length,
        itemBuilder: (context, index) {
          final room = _myGroups[index];
          return _buildGroupTile(room, isMember: true);
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_isLoadingPublic) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No public groups available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicGroups,
      child: ListView.builder(
        itemCount: _publicGroups.length,
        itemBuilder: (context, index) {
          final room = _publicGroups[index];
          final isMember = _myGroups.any((r) => r.id == room.id);
          return _buildGroupTile(room, isMember: isMember);
        },
      ),
    );
  }

  Widget _buildGroupTile(Room room, {required bool isMember}) {
    // Convert relative path to full URL
    final avatarUrl = room.avatar != null && !room.avatar!.startsWith('http')
        ? 'http://localhost:3000${room.avatar}'
        : room.avatar;
    
    if (room.avatar != null) {
      print('📸 Room ${room.name} - Original avatar: ${room.avatar}');
      print('📸 Room ${room.name} - Full URL: $avatarUrl');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? const Icon(Icons.group) : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(room.name)),
            if (room.isPasswordProtected)
              const Icon(Icons.lock, size: 16, color: Colors.orange),
            if (room.isPrivate)
              const Icon(Icons.lock_outline, size: 16, color: Colors.blue),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (room.description != null) ...[
              Text(
                room.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${room.memberCount ?? 0} members',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.lock, size: 14, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'E2EE',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ),
          ],
        ),
        trailing: isMember
            ? const Icon(Icons.chevron_right)
            : ElevatedButton(
                onPressed: () => _joinGroup(room),
                child: const Text('Join'),
              ),
        onTap: isMember ? () => _openGroupChat(room) : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../models/user.dart';
import '../widgets/user_avatar.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  List<User> _users = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String _roleFilter = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final response = await ApiService.instance.getAdminStats();
      setState(() {
        _stats = response['stats'];
      });
    } catch (e) {
      print('Failed to load stats: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.getUsers(
        page: _currentPage,
        search: _searchController.text,
        role: _roleFilter,
        status: _statusFilter,
      );

      setState(() {
        _users = (response['users'] as List)
            .map((u) => User.fromJson(u))
            .toList();
        _totalPages = response['pagination']['pages'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _banUser(User user) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _BanUserDialog(user: user),
    );

    if (reason == null) return;

    try {
      await ApiService.instance.banUser(user.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isBanned
                  ? 'User unbanned successfully'
                  : 'User banned successfully',
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<ChatProvider>().currentUser;

    if (currentUser == null || !currentUser.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied. Admin privileges required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadStats();
              _loadUsers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          if (_stats != null) _buildStatsSection(),

          // Search and filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search users',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _roleFilter.isEmpty ? null : _roleFilter,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All')),
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _roleFilter = value ?? '');
                          _loadUsers();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter.isEmpty ? null : _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All')),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'banned',
                            child: Text('Banned'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _statusFilter = value ?? '');
                          _loadUsers();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return _UserListTile(
                        user: user,
                        onBan: () => _banUser(user),
                      );
                    },
                  ),
          ),

          // Pagination
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.people,
              label: 'Total Users',
              value: _stats!['totalUsers'].toString(),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle,
              label: 'Active',
              value: _stats!['activeUsers'].toString(),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.block,
              label: 'Banned',
              value: _stats!['bannedUsers'].toString(),
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.new_releases,
              label: 'New (30d)',
              value: _stats!['newUsersLast30Days'].toString(),
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadUsers();
                  }
                : null,
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadUsers();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final User user;
  final VoidCallback onBan;

  const _UserListTile({required this.user, required this.onBan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: UserAvatar(
          avatarUrl: user.avatar,
          username: user.username,
          size: 50,
        ),
        title: Row(
          children: [
            Text(user.username),
            const SizedBox(width: 8),
            if (user.isAdmin)
              const Chip(
                label: Text('Admin', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.blue,
                labelStyle: TextStyle(color: Colors.white),
                visualDensity: VisualDensity.compact,
              ),
            if (user.isBanned)
              const Chip(
                label: Text('Banned', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            if (user.createdAt != null)
              Text(
                'Joined: ${DateFormat.yMMMd().format(user.createdAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(user.isBanned ? Icons.check_circle : Icons.block),
                  const SizedBox(width: 8),
                  Text(user.isBanned ? 'Unban' : 'Ban'),
                ],
              ),
              onTap: onBan,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _BanUserDialog extends StatefulWidget {
  final User user;

  const _BanUserDialog({required this.user});

  @override
  State<_BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<_BanUserDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.user.isBanned ? 'Unban' : 'Ban'} User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to ${widget.user.isBanned ? 'unban' : 'ban'} ${widget.user.username}?',
          ),
          const SizedBox(height: 16),
          if (!widget.user.isBanned)
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _reasonController.text.trim());
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(widget.user.isBanned ? 'Unban' : 'Ban'),
        ),
      ],
    );
  }
}

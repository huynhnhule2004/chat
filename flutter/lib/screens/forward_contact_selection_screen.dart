import 'package:flutter/material.dart';
import '../models/user.dart';
import '../database/database_helper.dart';

class ForwardContactSelectionScreen extends StatefulWidget {
  const ForwardContactSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ForwardContactSelectionScreen> createState() =>
      _ForwardContactSelectionScreenState();
}

class _ForwardContactSelectionScreenState
    extends State<ForwardContactSelectionScreen> {
  List<User> _allContacts = [];
  final Set<String> _selectedContactIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('users');

      setState(() {
        _allContacts = maps.map((map) => User.fromDatabase(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    }
  }

  List<User> get _filteredContacts {
    if (_searchQuery.isEmpty) return _allContacts;

    return _allContacts.where((user) {
      return user.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedContactIds.contains(userId)) {
        _selectedContactIds.remove(userId);
      } else {
        _selectedContactIds.add(userId);
      }
    });
  }

  void _confirmSelection() {
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    // Return selected contacts
    final selectedContacts = _allContacts
        .where((user) => _selectedContactIds.contains(user.id))
        .toList();

    Navigator.of(context).pop(selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedContactIds.isEmpty
              ? 'Forward Message'
              : 'Forward to ${_selectedContactIds.length} contact${_selectedContactIds.length > 1 ? 's' : ''}',
        ),
        actions: [
          if (_selectedContactIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _confirmSelection,
              tooltip: 'Forward',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Contact list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No contacts available'
                          : 'No contacts found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final isSelected = _selectedContactIds.contains(
                        contact.id,
                      );

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(contact.id),
                        title: Text(
                          contact.username,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'User ID: ${contact.id.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          child: Text(
                            contact.username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedContactIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.send),
              label: Text('Forward (${_selectedContactIds.length})'),
            )
          : null,
    );
  }
}

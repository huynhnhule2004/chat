import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/group_key_service.dart';
import '../../services/crypto_service.dart';
import '../../database/database_helper.dart';
import '../../models/room.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordProtected = false;
  bool _isPrivate = true;
  bool _isLoading = false;
  File? _avatarFile;
  String? _avatarUrl;

  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService.instance;
  final GroupKeyService _groupKeyService = GroupKeyService.instance;
  final CryptoService _cryptoService = CryptoService.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isPasswordProtected && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔨 Creating group: ${_nameController.text.trim()}');
      
      // Upload avatar if selected
      if (_avatarFile != null) {
        print('📤 Uploading avatar...');
        final uploadResult = await _apiService.uploadFile(_avatarFile!.path);
        _avatarUrl = uploadResult['fileUrl'];
        print('✅ Avatar uploaded: $_avatarUrl');
      }

      // Generate session key for the group
      print('🔑 Generating session key...');
      final sessionKey = await _groupKeyService.generateSessionKey();

      // Ensure RSA keys exist - use stored keys if available
      var rsaKeys = await _cryptoService.getStoredRSAKeys();
      if (rsaKeys == null || 
          rsaKeys['publicKey'] == null || 
          rsaKeys['publicKey']!.isEmpty) {
        print('🔑 Generating RSA keys...');
        rsaKeys = await _cryptoService.generateRSAKeyPair();
      }
      
      final publicKey = rsaKeys['publicKey']!;

      // Encrypt session key with owner's public key
      print('🔐 Encrypting session key...');
      final encryptedKey = await _groupKeyService.encryptSessionKey(
        sessionKey,
        publicKey,
      );

      // Create group via API
      print('🌐 Calling API to create group...');
      
      // Get current user ID from storage/provider
      final currentUser = await _apiService.getCurrentUser();
      print('📋 Current user data: $currentUser');
      
      // Backend returns {user: {...}} format
      final userData = currentUser['user'] ?? currentUser;
      final userId = (userData['_id'] ?? userData['id'] ?? '').toString();
      
      if (userId.isEmpty) {
        throw Exception('Cannot get current user ID');
      }
      
      print('📋 User ID: $userId');
      print('📋 Encrypted key length: ${encryptedKey.length}');
      
      print('📸 Avatar URL to send: $_avatarUrl');
      
      final response = await _apiService.createGroup(
        name: _nameController.text.trim(),
        avatar: _avatarUrl,
        description: _descriptionController.text.trim(),
        password: _isPasswordProtected ? _passwordController.text : null,
        isPrivate: _isPrivate,
        encryptedSessionKeys: [
          {
            'userId': userId,
            'encryptedKey': encryptedKey,
          }
        ],
      );
      print('✅ Group created successfully: ${response['room']}');
      print('📸 Received avatar: ${response['room']['avatar']}');

      final room = Room.fromJson(response['room']);

      // Store session key locally
      await _groupKeyService.storeSessionKey(room.id, sessionKey);

      // Save room to local database
      await DatabaseHelper.instance.insertRoom(room.toJson());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully!')),
      );

      Navigator.pop(context, room);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _avatarFile != null ? FileImage(_avatarFile!) : null,
                      child: _avatarFile == null
                          ? const Icon(Icons.group, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Group name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter group name';
                }
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Privacy settings
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Private Group'),
                    subtitle: const Text('Only invited members can join'),
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Password Protection'),
                    subtitle: const Text('Require password to join'),
                    value: _isPasswordProtected,
                    onChanged: (value) =>
                        setState(() => _isPasswordProtected = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Password field (if enabled)
            if (_isPasswordProtected) ...[
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Group Password *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Minimum 6 characters',
                ),
                validator: (value) {
                  if (_isPasswordProtected) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Info card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'End-to-End Encrypted',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All messages in this group will be encrypted with a unique session key. Only group members can read the messages.',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/group_key_service.dart';
import '../../services/crypto_service.dart';
import '../../database/database_helper.dart';
import '../../models/room.dart';

class JoinGroupDialog extends StatefulWidget {
  final Room room;

  const JoinGroupDialog({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final ApiService _apiService = ApiService.instance;
  final GroupKeyService _groupKeyService = GroupKeyService.instance;
  final CryptoService _cryptoService = CryptoService.instance;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    if (widget.room.isPasswordProtected && _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter the password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure RSA keys exist for decryption
      var rsaKeys = await _cryptoService.getStoredRSAKeys();
      if (rsaKeys == null) {
        rsaKeys = await _cryptoService.generateRSAKeyPair();
      }

      final privateKey = rsaKeys['privateKey']!;

      // Join group via API - backend will return encrypted session key if owner added us
      final response = await _apiService.joinGroup(
        roomId: widget.room.id,
        password: widget.room.isPasswordProtected
            ? _passwordController.text
            : null,
      );

      // Check if join is pending (public group without encrypted key)
      final isPending = response['pending'] == true;
      final serverEncryptedKey = response['encryptedSessionKey'];

      if (isPending || serverEncryptedKey == null) {
        // Joined but pending owner approval - can't send messages yet
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined group! You can view messages after owner grants access.'),
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      // Decrypt session key with our private key
      final decryptedSessionKey = await _groupKeyService.decryptSessionKey(
        serverEncryptedKey,
        privateKey,
      );

      // Store session key locally
      await _groupKeyService.storeSessionKey(
        widget.room.id,
        decryptedSessionKey,
      );

      // Update room in local database
      final updatedRoom = widget.room.copyWith(
        memberCount: (widget.room.memberCount ?? 0) + 1,
      );
      await DatabaseHelper.instance.insertRoom(updatedRoom.toJson());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('401')
            ? 'Incorrect password'
            : 'Failed to join group: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: widget.room.avatar != null
                ? NetworkImage(widget.room.avatar!)
                : null,
            child: widget.room.avatar == null
                ? const Icon(Icons.group)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.name,
                  style: const TextStyle(fontSize: 18),
                ),
                if (widget.room.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.room.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group info
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '${widget.room.memberCount ?? 0} members',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Icon(
                widget.room.isPrivate
                    ? Icons.lock
                    : Icons.public,
                size: 48,
                color: Colors.grey[700],
              ),
              const SizedBox(height: 16),
              Text(
                widget.room.isPrivate ? 'Private' : 'Public',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Password field (if required)
          if (widget.room.isPasswordProtected) ...[
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Group Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _joinGroup(),
            ),
            const SizedBox(height: 8),
          ],

          // E2EE info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'End-to-end encrypted',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _joinGroup,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}

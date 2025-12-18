import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import 'storage_analysis_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: ListView(
        children: [
          // Dark Mode Section
          _buildSectionHeader(context, 'Appearance'),
          _DarkModeSettingTile(),

          const Divider(),

          // Storage Section
          _buildSectionHeader(context, 'Storage & Data'),
          _StorageOverviewTile(),
          _buildSettingTile(
            context,
            icon: Icons.storage,
            title: 'Storage Usage',
            subtitle: 'Manage your storage',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StorageAnalysisScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildSettingTile(
            context,
            icon: Icons.person,
            title: 'Profile',
            subtitle: 'Edit your profile information',
            onTap: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),

          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (chatProvider.currentUser?.isAdmin == true) {
                return _buildSettingTile(
                  context,
                  icon: Icons.admin_panel_settings,
                  title: 'Admin Dashboard',
                  subtitle: 'Manage users and settings',
                  onTap: () {
                    Navigator.of(context).pushNamed('/admin');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const Divider(),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildSettingTile(
            context,
            icon: Icons.info,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () {
              _showAboutDialog(context);
            },
          ),

          const SizedBox(height: 16),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final shouldLogout = await _showLogoutDialog(context);
                if (shouldLogout == true && context.mounted) {
                  await context.read<ChatProvider>().logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'E2EE Chat',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.lock, size: 48),
      children: [
        const SizedBox(height: 16),
        const Text('End-to-End Encrypted Messaging'),
        const SizedBox(height: 8),
        const Text('Your privacy is our priority.'),
      ],
    );
  }
}

class _DarkModeSettingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: const Text('Dark Mode'),
          subtitle: Text(
            themeProvider.isDarkMode
                ? 'Dark theme enabled'
                : 'Light theme enabled',
          ),
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            themeProvider.setDarkMode(value);
          },
        );
      },
    );
  }
}

class _StorageOverviewTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getQuickStorageInfo(),
      builder: (context, snapshot) {
        final subtitle = snapshot.hasData ? snapshot.data! : 'Loading...';

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.pie_chart,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: const Text('Storage Overview'),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StorageAnalysisScreen(),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getQuickStorageInfo() async {
    try {
      // Quick calculation without full analysis
      return 'Tap to view details';
    } catch (e) {
      return 'Unable to calculate';
    }
  }
}

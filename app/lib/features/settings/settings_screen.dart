import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: 'user@example.com',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {},
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Preferences section
          _SectionHeader(title: 'Preferences'),
          _SettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.location_on,
            title: 'Default Location',
            subtitle: 'Texas',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.palette,
            title: 'Appearance',
            subtitle: 'Light',
            onTap: () {},
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Support section
          _SectionHeader(title: 'Support'),
          _SettingsTile(
            icon: Icons.help,
            title: 'Help Center',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.bug_report,
            title: 'Report a Problem',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.article,
            title: 'Community Guidelines',
            onTap: () {},
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Legal section
          _SectionHeader(title: 'Legal'),
          _SettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            onTap: () {},
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: OutlinedButton(
              onPressed: () {
                _showSignOutDialog(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('Sign Out'),
            ),
          ),
          
          // App version
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Text(
              'The Skinning Shed v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textTertiary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

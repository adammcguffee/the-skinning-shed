import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../services/push_notification_service.dart';

/// Notification preferences settings page
class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends ConsumerState<NotificationsSettingsPage> {
  NotificationPrefs? _prefs;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }
  
  Future<void> _loadPrefs() async {
    final service = ref.read(notificationsServiceProvider);
    final prefs = await service.getPreferences();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _isLoading = false;
      });
    }
  }
  
  void _updatePref(NotificationPrefs Function(NotificationPrefs) update) {
    if (_prefs == null) return;
    setState(() {
      _prefs = update(_prefs!);
      _hasChanges = true;
    });
  }
  
  Future<void> _savePrefs() async {
    if (_prefs == null || !_hasChanges) return;
    
    setState(() => _isSaving = true);
    
    final service = ref.read(notificationsServiceProvider);
    final success = await service.updatePreferences(_prefs!);
    
    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _savePrefs,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Master toggle
                _buildSection(
                  title: 'Push Notifications',
                  children: [
                    _buildToggleTile(
                      title: 'Enable Push Notifications',
                      subtitle: 'Receive notifications on this device',
                      value: _prefs?.pushEnabled ?? true,
                      onChanged: (v) => _updatePref((p) => p.copyWith(pushEnabled: v)),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Category toggles
                _buildSection(
                  title: 'Notification Types',
                  subtitle: 'Choose what you want to be notified about',
                  enabled: _prefs?.pushEnabled ?? true,
                  children: [
                    _buildToggleTile(
                      title: 'Club Posts',
                      subtitle: 'New posts in your hunting clubs',
                      value: _prefs?.clubPostPush ?? true,
                      enabled: _prefs?.pushEnabled ?? true,
                      onChanged: (v) => _updatePref((p) => p.copyWith(clubPostPush: v)),
                      icon: Icons.article_outlined,
                    ),
                    _buildToggleTile(
                      title: 'Stand Sign-ins',
                      subtitle: 'When someone signs in to a stand',
                      value: _prefs?.standPush ?? true,
                      enabled: _prefs?.pushEnabled ?? true,
                      onChanged: (v) => _updatePref((p) => p.copyWith(standPush: v)),
                      icon: Icons.person_pin_circle_outlined,
                    ),
                    _buildToggleTile(
                      title: 'Messages',
                      subtitle: 'New direct messages',
                      value: _prefs?.messagePush ?? true,
                      enabled: _prefs?.pushEnabled ?? true,
                      onChanged: (v) => _updatePref((p) => p.copyWith(messagePush: v)),
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Info card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'You can always view notifications in the app even if push is disabled.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    IconData? icon,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

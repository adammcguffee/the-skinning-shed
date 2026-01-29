import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/features/settings/background_theme_selector.dart';
import 'package:shed/services/ad_service.dart';
import 'package:shed/services/auth_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/ad_slot.dart';
import 'package:shed/shared/widgets/widgets.dart';

// Note: isAdminProvider is imported from supabase_service.dart

/// ⚙️ SETTINGS SCREEN - 2026 PRODUCTION
/// 
/// Complete settings with:
/// - Account management
/// - Help & Support
/// - Legal pages
/// - App info
/// - Admin section (gated)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          const AppTopBar(
            title: 'Settings',
          ),

        // Content
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Mobile header
              if (!isWide)
                const SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: 'Settings',
                  ),
                ),

              // Account section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Account',
                  children: [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      subtitle: 'Display name, bio, avatar',
                      onTap: () => context.push('/profile/edit'),
                    ),
                  ],
                ),
              ),

              // Help & Support section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Help & Support',
                  children: [
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      subtitle: 'How to use The Skinning Shed',
                      onTap: () => context.push('/settings/help'),
                    ),
                    _SettingsItem(
                      icon: Icons.feedback_outlined,
                      title: 'Send Feedback',
                      subtitle: 'Report bugs or suggest features',
                      onTap: () => context.push('/settings/feedback'),
                    ),
                  ],
                ),
              ),

              // Legal section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Legal',
                  children: [
                    _SettingsItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () => context.push('/settings/privacy'),
                    ),
                    _SettingsItem(
                      icon: Icons.article_outlined,
                      title: 'Terms of Service',
                      onTap: () => context.push('/settings/terms'),
                    ),
                    _SettingsItem(
                      icon: Icons.warning_amber_outlined,
                      title: 'Content Disclaimer',
                      subtitle: 'Important notices',
                      onTap: () => context.push('/settings/disclaimer'),
                    ),
                  ],
                ),
              ),

              // App Info section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'App Info',
                  children: [
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version 1.0.0',
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
              ),

              // Admin section (only visible to admins)
              Consumer(
                builder: (context, ref, child) {
                  final isAdminAsync = ref.watch(isAdminProvider);
                  
                  return isAdminAsync.when(
                    data: (isAdmin) {
                      if (!isAdmin) return const SliverToBoxAdapter(child: SizedBox.shrink());
                      
                      return SliverToBoxAdapter(
                        child: _SettingsSection(
                          title: 'Admin',
                          titleColor: AppColors.warning,
                          children: [
                            _SettingsItem(
                              icon: Icons.flag_outlined,
                              title: 'Reports',
                              subtitle: 'Review user reports',
                              onTap: () => context.push('/admin/reports'),
                            ),
                            _SettingsItem(
                              icon: Icons.link_outlined,
                              title: 'Official Links Admin',
                              subtitle: 'Manage state portal links',
                              onTap: () => context.push('/admin/official-links'),
                            ),
                            _SettingsItem(
                              icon: Icons.palette_outlined,
                              title: 'Background Theme',
                              subtitle: 'Change app background style',
                              onTap: () {
                                showBackgroundThemeSelector(context);
                              },
                            ),
                            // Dev tools (admin + debug only)
                            if (kDebugMode) ...[
                              _SettingsToggleItem(
                                icon: Icons.bug_report_outlined,
                                title: 'Show Ad Slot Overlay',
                                subtitle: 'Display ad slot boundaries',
                                provider: showAdDebugOverlayProvider,
                              ),
                              _SettingsItem(
                                icon: Icons.refresh_rounded,
                                title: 'Clear Ad Cache',
                                subtitle: 'Force reload all ads',
                                onTap: () {
                                  ref.read(adServiceProvider).clearCache();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ad cache cleared'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  );
                },
              ),

              // Danger Zone section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Danger Zone',
                  titleColor: AppColors.error,
                  children: [
                    _SettingsItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your account and data',
                      iconColor: AppColors.error,
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                  ],
                ),
              ),

              // Sign out
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: AppButtonSecondary(
                    label: 'Sign Out',
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();
                    },
                    isExpanded: true,
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _DeleteAccountDialog(ref: ref),
    );
  }
}

/// Delete account confirmation dialog.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.ref});
  
  final WidgetRef ref;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _isDeleting = false;
  bool _confirmed = false;

  Future<void> _deleteAccount() async {
    if (!_confirmed) return;
    
    setState(() => _isDeleting = true);
    
    try {
      final client = widget.ref.read(supabaseClientProvider);
      if (client == null) throw Exception('Not connected');
      
      // Call the delete account RPC (which handles cascading deletes)
      await client.rpc('delete_user_account');
      
      // Sign out
      final authService = widget.ref.read(authServiceProvider);
      await authService.signOut();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
          const SizedBox(width: AppSpacing.sm),
          const Text('Delete Account?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action cannot be undone. The following will be permanently deleted:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDeleteItem('Your profile and preferences'),
          _buildDeleteItem('All trophy posts'),
          _buildDeleteItem('All swap shop listings'),
          _buildDeleteItem('All land listings'),
          _buildDeleteItem('Message history'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Checkbox(
                value: _confirmed,
                onChanged: (value) {
                  setState(() => _confirmed = value ?? false);
                },
                activeColor: AppColors.error,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Text(
                    'I understand this is permanent',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed && !_isDeleting ? _deleteAccount : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete Account'),
        ),
      ],
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            size: 14,
            color: AppColors.error.withOpacity(0.7),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: titleColor ?? AppColors.textSecondary,
                  fontWeight: titleColor != null ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final isLast = entry.key == children.length - 1;
                return Column(
                  children: [
                    entry.value,
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatefulWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (widget.iconColor ?? AppColors.textSecondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.iconColor ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings item with a toggle switch.
class _SettingsToggleItem extends ConsumerWidget {
  const _SettingsToggleItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.provider,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final StateProvider<bool> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              ref.read(provider.notifier).state = newValue;
            },
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

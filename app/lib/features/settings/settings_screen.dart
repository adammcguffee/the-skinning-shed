import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/auth_service.dart';
import 'package:shed/services/dev_auth_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// ⚙️ SETTINGS SCREEN - 2025 PREMIUM
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        // Banner header is now rendered by AppScaffold

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
                      onTap: () => _showComingSoon(context, 'Edit Profile'),
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => _showComingSoon(context, 'Notifications'),
                    ),
                    _SettingsItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy',
                      onTap: () => _showComingSoon(context, 'Privacy settings'),
                    ),
                  ],
                ),
              ),

              // Preferences section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Preferences',
                  children: [
                    _SettingsItem(
                      icon: Icons.location_on_outlined,
                      title: 'Default Location',
                      subtitle: 'Texas',
                      onTap: () => _showComingSoon(context, 'Default Location'),
                    ),
                    _SettingsItem(
                      icon: Icons.straighten_outlined,
                      title: 'Units',
                      subtitle: 'Imperial',
                      onTap: () => _showComingSoon(context, 'Units'),
                    ),
                  ],
                ),
              ),

              // Support section
              SliverToBoxAdapter(
                child: _SettingsSection(
                  title: 'Support',
                  children: [
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      onTap: () => _showComingSoon(context, 'Help Center'),
                    ),
                    _SettingsItem(
                      icon: Icons.feedback_outlined,
                      title: 'Send Feedback',
                      onTap: () => _showComingSoon(context, 'Send Feedback'),
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version 1.0.0',
                      onTap: () => _showComingSoon(context, 'About'),
                    ),
                  ],
                ),
              ),

              // Sign out section
              SliverToBoxAdapter(
                child: _SignOutSection(),
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
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
                  color: AppColors.textSecondary,
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

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
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  widget.icon,
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
                      widget.title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
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

/// Sign out section that handles both real auth and dev bypass.
class _SignOutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider);
    final isDevBypass = authNotifier.isDevBypass;
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          // Dev bypass indicator
          if (isDevBypass) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Dev Mode Active',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          'No Supabase session - using local bypass',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          
          // Sign out button
          AppButtonSecondary(
            label: isDevBypass ? 'Sign Out (Dev Mode)' : 'Sign Out',
            icon: Icons.logout_rounded,
            onPressed: () async {
              if (isDevBypass) {
                // Clear dev bypass state
                await ref.read(devAuthNotifierProvider).deactivate();
              } else {
                // Real sign out
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
                // Also clear any dev bypass state
                await DevAuthService.clearDevBypassState();
              }
            },
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}
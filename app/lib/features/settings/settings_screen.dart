import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/ad_service.dart';
import 'package:shed/services/auth_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/ad_slot.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Provider to check if current user is admin.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return false;
  
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;
  
  try {
    final response = await client
        .from('profiles')
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();
    
    return response?['is_admin'] == true;
  } catch (e) {
    return false;
  }
});

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
                          children: [
                            _SettingsItem(
                              icon: Icons.gavel_outlined,
                              title: 'Regulations Admin',
                              subtitle: 'Review pending updates',
                              onTap: () => context.push('/admin/regulations'),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  );
                },
              ),

              // Debug section (only in debug builds)
              if (kDebugMode)
                SliverToBoxAdapter(
                  child: _SettingsSection(
                    title: 'Developer',
                    children: [
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
                      _AuthDebugItem(),
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
                    style: Theme.of(context).textTheme.bodySmall,
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

/// Debug auth info panel (kDebugMode only).
class _AuthDebugItem extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(supabaseServiceProvider);
    final client = service.client;
    final session = client?.auth.currentSession;
    final user = client?.auth.currentUser;
    
    final hasSession = session != null;
    final hasUser = user != null;
    final accessTokenLength = session?.accessToken.length ?? 0;
    final hasRefreshToken = session?.refreshToken != null;
    final authReadyState = service.authReadyState;
    
    return _SettingsItem(
      icon: Icons.security_rounded,
      title: 'Auth Debug',
      subtitle: hasSession ? 'Session OK' : 'No session',
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Auth Debug Info'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AuthDebugRow('Auth Ready State', authReadyState.name),
                  _AuthDebugRow('Session Present', hasSession.toString()),
                  _AuthDebugRow('User Present', hasUser.toString()),
                  _AuthDebugRow('User ID', user?.id ?? 'N/A'),
                  _AuthDebugRow('User Email', user?.email ?? 'N/A'),
                  _AuthDebugRow('Access Token Length', accessTokenLength.toString()),
                  _AuthDebugRow('Refresh Token Present', hasRefreshToken.toString()),
                  if (session != null) ...[
                    _AuthDebugRow(
                      'Token Expires At',
                      session.expiresAt != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                              session.expiresAt! * 1000,
                            ).toIso8601String()
                          : 'N/A',
                    ),
                    _AuthDebugRow(
                      'Token Expired',
                      session.isExpired.toString(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await client?.auth.refreshSession();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session refreshed!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Refresh failed: $e'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Refresh Token'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthDebugRow extends StatelessWidget {
  const _AuthDebugRow(this.label, this.value);
  
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

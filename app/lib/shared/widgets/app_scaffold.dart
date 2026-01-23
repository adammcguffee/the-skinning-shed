import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/banner_header.dart';
import 'app_nav_rail.dart';

/// 🏗️ 2025 PREMIUM APP SCAFFOLD - DARK THEME
///
/// Responsive layout with:
/// - Slim nav rail on web/tablet
/// - Bottom nav on mobile
/// - Floating post button (FAB)
/// - Max-width content container
/// - Dark forest-green aesthetic
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  static const _destinations = [
    AppNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Feed',
    ),
    AppNavDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    AppNavDestination(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      label: 'Trophy Wall',
    ),
    AppNavDestination(
      icon: Icons.landscape_outlined,
      selectedIcon: Icons.landscape_rounded,
      label: 'Land',
    ),
    AppNavDestination(
      icon: Icons.cloud_outlined,
      selectedIcon: Icons.cloud_rounded,
      label: 'Weather',
    ),
    AppNavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/trophy-wall');
        break;
      case 3:
        context.go('/land');
        break;
      case 4:
        context.go('/weather');
        break;
      case 5:
        context.go('/settings');
        break;
    }
  }

  void _onPostTap(BuildContext context) {
    context.push('/post');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    if (isWide) {
      return _buildWideLayout(context);
    } else {
      return _buildNarrowLayout(context);
    }
  }

  Widget _buildWideLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Nav rail
          AppNavRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onDestinationSelected(context, index),
            destinations: _destinations,
            onPostTap: () => _onPostTap(context),
          ),

          // Main content - MUST give child space via Expanded
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Column(
                children: [
                  // Header zone
                  const Padding(
                    padding: EdgeInsets.only(top: 12, left: 16, right: 16),
                    child: BannerHeader.appTop(),
                  ),
                  const SizedBox(height: 12),
                  // Subtle divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Content frame
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header zone
            SafeArea(
              bottom: false,
              child: const Padding(
                padding: EdgeInsets.only(top: 12, left: 16, right: 16),
                child: BannerHeader.appTop(),
              ),
            ),
            const SizedBox(height: 12),
            // Subtle divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            const SizedBox(height: 16),
            // Content frame
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _MobileBottomNav(
        currentIndex: currentIndex,
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
      ),
      floatingActionButton: _MobilePostFab(
        onTap: () => _onPostTap(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// Mobile bottom navigation bar - Dark theme
class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MobileNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Feed',
                isSelected: currentIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _MobileNavItem(
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
                label: 'Explore',
                isSelected: currentIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              // Spacer for FAB
              const SizedBox(width: 64),
              _MobileNavItem(
                icon: Icons.emoji_events_outlined,
                selectedIcon: Icons.emoji_events_rounded,
                label: 'Trophy',
                isSelected: currentIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
              _MobileNavItem(
                icon: Icons.more_horiz_rounded,
                selectedIcon: Icons.more_horiz_rounded,
                label: 'More',
                isSelected: currentIndex >= 3,
                onTap: () => _showMoreSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MoreSheet(
        currentIndex: currentIndex,
        onDestinationSelected: (index) {
          Navigator.pop(context);
          onDestinationSelected(index);
        },
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 24,
              color: isSelected ? AppColors.accent : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobilePostFab extends StatelessWidget {
  const _MobilePostFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowAccent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: AppColors.textInverse,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        boxShadow: AppColors.shadowElevated,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Options
            _MoreSheetItem(
              icon: Icons.landscape_outlined,
              label: 'Land Listings',
              isSelected: currentIndex == 3,
              onTap: () => onDestinationSelected(3),
            ),
            _MoreSheetItem(
              icon: Icons.cloud_outlined,
              label: 'Weather & Tools',
              isSelected: currentIndex == 4,
              onTap: () => onDestinationSelected(4),
            ),
            _MoreSheetItem(
              icon: Icons.storefront_outlined,
              label: 'Swap Shop',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                context.push('/swap-shop');
              },
            ),
            _MoreSheetItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              isSelected: currentIndex == 5,
              onTap: () => onDestinationSelected(5),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _MoreSheetItem extends StatelessWidget {
  const _MoreSheetItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.accent : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

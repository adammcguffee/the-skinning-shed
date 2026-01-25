import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/ad_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/ad_slot.dart';
import 'package:shed/shared/widgets/banner_header.dart';
import 'package:shed/shared/widgets/camo_background.dart';
import 'package:shed/shared/widgets/modals/create_menu_sheet.dart';
import 'package:shed/services/messaging_service.dart';
import 'app_nav_rail.dart';

/// 🏗️ 2025 PREMIUM APP SCAFFOLD - DARK THEME
///
/// Responsive layout with:
/// - Slim nav rail on web/tablet
/// - Bottom nav on mobile
/// - Floating post button (FAB)
/// - Max-width content container
/// - Dark forest-green aesthetic
/// - Ad slots in header (desktop/tablet only)
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  /// Map navigation index to page identifier for ad targeting.
  /// Indices: 0=Feed, 1=Explore, 2=TrophyWall, 3=Land, 4=Messages,
  ///          5=Weather, 6=Research, 7=Regulations, 8=Settings
  String get _currentPageId {
    switch (currentIndex) {
      case 0: return AdPages.feed;
      case 1: return AdPages.explore;
      case 2: return AdPages.trophyWall;
      case 3: return AdPages.land;
      case 4: return AdPages.messages;
      case 5: return AdPages.weather;
      case 6: return AdPages.research;
      case 7: return AdPages.regulations;
      case 8: return AdPages.settings;
      default: return AdPages.feed;
    }
  }

  static const _destinationsBase = [
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
    // Messages is index 4 - badge added dynamically
    AppNavDestination(
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    AppNavDestination(
      icon: Icons.cloud_outlined,
      selectedIcon: Icons.cloud_rounded,
      label: 'Weather',
    ),
    AppNavDestination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Research',
    ),
    AppNavDestination(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      label: 'Regulations',
    ),
    AppNavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];
  
  /// Build destinations with unread badge for messages.
  static List<AppNavDestination> _buildDestinations(int unreadCount) {
    return _destinationsBase.asMap().entries.map((entry) {
      final index = entry.key;
      final dest = entry.value;
      
      // Add badge to Messages (index 4)
      if (index == 4 && unreadCount > 0) {
        return AppNavDestination(
          icon: dest.icon,
          selectedIcon: dest.selectedIcon,
          label: dest.label,
          badgeCount: unreadCount,
        );
      }
      return dest;
    }).toList();
  }

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
        context.go('/messages');
        break;
      case 5:
        context.go('/weather');
        break;
      case 6:
        context.go('/research');
        break;
      case 7:
        context.go('/regulations');
        break;
      case 8:
        context.go('/settings');
        break;
    }
  }

  /// Get the create context based on current page.
  CreateContext get _createContext {
    switch (currentIndex) {
      case 0: return CreateContext.feed;
      case 1: return CreateContext.explore;
      case 2: return CreateContext.trophyWall;
      case 3: return CreateContext.land;
      case 4: return CreateContext.other; // Messages
      case 5: return CreateContext.other; // Weather
      case 6: return CreateContext.other; // Research
      case 7: return CreateContext.other; // Regulations
      case 8: return CreateContext.other; // Settings
      default: return CreateContext.other;
    }
  }
  
  void _onCreateTap(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    
    showCreateMenu(
      context: context,
      createContext: _createContext,
      isAuthenticated: isAuthenticated,
      onLoginRequired: () {
        // Navigate to auth
        context.go('/auth');
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    if (isWide) {
      return _buildWideLayout(context, ref);
    } else {
      return _buildNarrowLayout(context, ref);
    }
  }

  Widget _buildWideLayout(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final destinations = _buildDestinations(unreadCount);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= AppSpacing.breakpointDesktop;
    final isUltrawide = screenWidth >= 1600;
    
    // Wider content on desktop: 1100-1280 depending on screen
    final contentMaxWidth = isUltrawide ? 1280.0 : (isDesktop ? 1100.0 : 900.0);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Nav rail with subtle camo
          NavRailCamoBackground(
            child: AppNavRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _onDestinationSelected(context, index),
              destinations: destinations,
              onPostTap: () => _onCreateTap(context, ref),
            ),
          ),

          // Main content - MUST give child space via Expanded
          Expanded(
            child: ScaffoldCamoBackground(
              child: Column(
                children: [
                  // Header zone with camo behind hero
                  HeroCamoBackground(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: const BannerHeader.appTop(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtle divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content frame with optional ad rail
                  Expanded(
                    child: Row(
                      children: [
                        // Main content area - WIDER on desktop
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: contentMaxWidth,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06),
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
                        // Right ad rail (desktop only)
                        if (isDesktop)
                          Padding(
                            padding: const EdgeInsets.only(right: 24, top: 4, bottom: 8),
                            child: SizedBox(
                              width: 180,
                              child: Column(
                                children: [
                                  AdSlot(
                                    page: _currentPageId,
                                    position: AdPosition.right,
                                    maxWidth: 180,
                                    maxHeight: 280,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildNarrowLayout(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScaffoldCamoBackground(
        child: Column(
          children: [
            // Header zone with camo behind hero
            SafeArea(
              bottom: false,
              child: HeroCamoBackground(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: const BannerHeader.appTop(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Subtle divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(height: 8),
            // Content frame
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
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
        onTap: () => _onCreateTap(context, ref),
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
      useRootNavigator: true, // Ensures modal sits above entire app shell
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

class _MobilePostFab extends StatefulWidget {
  const _MobilePostFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MobilePostFab> createState() => _MobilePostFabState();
}

class _MobilePostFabState extends State<_MobilePostFab> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Create',
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: AppColors.shadowCard,
        ),
        textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        child: GestureDetector(
          onLongPress: () {
            // Show tooltip-like feedback on long press (mobile)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Create new content'),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 8),
            transform: _isHovered 
                ? (Matrix4.identity()..scale(1.08))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isHovered 
                  ? [
                      ...AppColors.shadowAccent,
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppColors.shadowAccent,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
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
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              isSelected: currentIndex == 4,
              onTap: () => onDestinationSelected(4),
            ),
            _MoreSheetItem(
              icon: Icons.cloud_outlined,
              label: 'Weather & Tools',
              isSelected: currentIndex == 5,
              onTap: () => onDestinationSelected(5),
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
              icon: Icons.gavel_outlined,
              label: 'Regulations',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                context.push('/regulations');
              },
            ),
            _MoreSheetItem(
              icon: Icons.insights_outlined,
              label: 'Research & Patterns',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                context.push('/research');
              },
            ),
            _MoreSheetItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              isSelected: currentIndex == 8,
              onTap: () => onDestinationSelected(8),
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

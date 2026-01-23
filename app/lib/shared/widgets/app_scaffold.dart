import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

/// Responsive scaffold with bottom navigation (mobile) or navigation rail (tablet/web).
/// 
/// Provides consistent navigation across all screen sizes.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  // Navigation items configuration
  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Feed',
      path: '/',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
      path: '/explore',
    ),
    _NavItem(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: 'Post',
      path: '/post',
      isPrimary: true,
    ),
    _NavItem(
      icon: Icons.cloud_outlined,
      selectedIcon: Icons.cloud,
      label: 'Weather',
      path: '/weather',
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
      label: 'Trophy Wall',
      path: '/trophy-wall',
    ),
  ];

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    
    for (int i = 0; i < _navItems.length; i++) {
      if (_navItems[i].path == location) {
        return i;
      }
    }
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    final item = _navItems[index];
    
    // Post action is handled differently (full screen)
    if (item.isPrimary) {
      context.push(item.path);
    } else {
      context.go(item.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 800;

    if (isWideScreen) {
      return _buildWideLayout(context, currentIndex);
    } else {
      return _buildMobileLayout(context, currentIndex);
    }
  }

  Widget _buildMobileLayout(BuildContext context, int currentIndex) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == currentIndex;

                if (item.isPrimary) {
                  return _buildPrimaryButton(context, item);
                }

                return _buildNavItem(
                  context,
                  item,
                  isSelected,
                  () => _onItemTapped(context, index),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, int currentIndex) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onItemTapped(context, index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildPrimaryButton(context, _navItems[2]),
            ),
            destinations: _navItems.where((item) => !item.isPrimary).map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    _NavItem item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: isSelected
                  ? AppColors.forest
                  : AppColors.charcoalLight,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.forest
                    : AppColors.charcoalLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, _NavItem item) {
    return Material(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(item.path),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.selectedIcon,
                color: AppColors.bone,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.bone,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    this.isPrimary = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final bool isPrimary;
}

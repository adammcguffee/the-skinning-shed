import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../branding_assets.dart';

/// Responsive scaffold with bottom navigation (mobile) or navigation rail (tablet/web).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  // Navigation items (excluding Post which is a primary action)
  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Feed',
      path: '/',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Explore',
      path: '/explore',
    ),
    _NavItem(
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny_rounded,
      label: 'Weather',
      path: '/weather',
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      label: 'Trophy Wall',
      path: '/trophy-wall',
    ),
  ];

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    
    for (var i = 0; i < _navItems.length; i++) {
      if (_navItems[i].path == location) {
        return i;
      }
    }
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    context.go(_navItems[index].path);
  }

  void _onPostTapped(BuildContext context) {
    context.push('/post');
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
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // First two nav items
              for (var i = 0; i < 2; i++)
                _buildNavItem(context, i, currentIndex == i),
              
              // Spacer for FAB
              const SizedBox(width: 64),
              
              // Last two nav items
              for (var i = 2; i < 4; i++)
                _buildNavItem(context, i, currentIndex == i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, bool isSelected) {
    final item = _navItems[index];
    
    return InkWell(
      onTap: () => _onItemTapped(context, index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _onPostTapped(context),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  Widget _buildWideLayout(BuildContext context, int currentIndex) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                
                // Logo icon at top of rail
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Image.asset(
                    BrandingAssets.icon,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Post button
                _buildRailPostButton(context),
                
                const SizedBox(height: 20),
                
                // Navigation items
                Expanded(
                  child: Column(
                    children: List.generate(_navItems.length, (index) {
                      return _buildRailItem(context, index, currentIndex == index);
                    }),
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildRailPostButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _onPostTapped(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailItem(BuildContext context, int index, bool isSelected) {
    final item = _navItems[index];
    
    return InkWell(
      onTap: () => _onItemTapped(context, index),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primaryContainer.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
}

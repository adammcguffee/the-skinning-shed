import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding_assets.dart';

/// A modern, slim navigation rail for web/tablet.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.onPostTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;
  final VoidCallback? onPostTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.navRailWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          // Logo
          const SizedBox(height: AppSpacing.lg),
          _NavLogo(),
          const SizedBox(height: AppSpacing.xxl),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final isSelected = index == selectedIndex;
                return _NavItem(
                  icon: dest.icon,
                  selectedIcon: dest.selectedIcon,
                  label: dest.label,
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected(index),
                );
              },
            ),
          ),

          // Post FAB
          if (onPostTap != null) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _PostButton(onTap: onPostTap!),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _NavLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        BrandingAssets.markIcon,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : _isHovered
                      ? AppColors.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(
              child: Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                size: 22,
                color: widget.isSelected
                    ? AppColors.primary
                    : _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostButton extends StatefulWidget {
  const _PostButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PostButton> createState() => _PostButtonState();
}

class _PostButtonState extends State<_PostButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: _isHovered ? AppColors.primaryGradient : null,
            color: _isHovered ? null : AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: _isHovered ? AppColors.shadowButton : null,
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: AppColors.textInverse,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation destination data.
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

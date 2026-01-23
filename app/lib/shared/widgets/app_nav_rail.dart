import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding/brand_assets.dart';

/// 🧭 PREMIUM NAVIGATION RAIL - 2025 DARK THEME
///
/// Slim, icon-based nav rail with:
/// - Minimal chrome
/// - Icon mark branding
/// - Floating post button
/// - Active pill indicator
/// - Hover effects
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.onPostTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;
  final VoidCallback onPostTap;

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
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),

            // Logo/Brand mark
            _buildBrandMark(),

            const SizedBox(height: AppSpacing.xxxl),

            // Navigation items
            Expanded(
              child: Column(
                children: [
                  for (int i = 0; i < destinations.length; i++)
                    _NavItem(
                      destination: destinations[i],
                      isSelected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                ],
              ),
            ),

            // Post button
            _PostButton(onTap: onPostTap),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandMark() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset(
        BrandAssets.crest,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.sm,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tooltip(
          message: widget.destination.label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 500),
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
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.accent.withOpacity(0.15)
                    : _isHovered
                        ? AppColors.surfaceHover
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: widget.isSelected
                    ? Border.all(color: AppColors.accent.withOpacity(0.3))
                    : null,
              ),
              child: Center(
                child: Icon(
                  widget.isSelected
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  size: 22,
                  color: widget.isSelected
                      ? AppColors.accent
                      : _isHovered
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                ),
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
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: _isHovered ? AppColors.shadowAccent : AppColors.shadowButton,
          ),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: AppColors.textInverse,
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation destination data
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

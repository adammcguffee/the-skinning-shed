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
      // Background and border handled by NavRailCamoBackground wrapper
      child: SafeArea(
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl + 4),

            // Logo/Brand mark - clickable to go Home
            _buildBrandMark(context),

            const SizedBox(height: AppSpacing.xxxl + 8),

            // Navigation items - scrollable if needed
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
            ),

            // Create button area - fixed at bottom with proper spacing
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _PostButton(onTap: onPostTap),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandMark(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Tooltip(
        message: 'Home',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              // Navigate to feed (index 0) regardless of current page
              onDestinationSelected(0);
            },
            child: SizedBox(
              width: 52,
              height: 52,
              child: Image.asset(
                BrandAssets.crest,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
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
        vertical: AppSpacing.xs + 2,
        horizontal: AppSpacing.sm,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tooltip(
          message: widget.destination.label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 400),
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
              curve: Curves.easeOut,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : _isHovered
                        ? AppColors.surfaceHover
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: widget.isSelected
                    ? Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        width: 1.5,
                      )
                    : null,
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
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
                  // Badge
                  if (widget.destination.hasBadge)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          widget.destination.badgeCount! > 99 
                              ? '99+' 
                              : widget.destination.badgeCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extended Create button for nav rail - constrained to fit nav width
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
    // Constrain button width to fit within nav rail (100 - 16 padding = 84)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 84),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: _isHovered ? AppColors.shadowAccent : AppColors.shadowButton,
            ),
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.03))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.textInverse,
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textInverse,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;
  
  bool get hasBadge => badgeCount != null && badgeCount! > 0;
}

import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// A modern chip component for tags, filters, and categories.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
    this.onDelete,
    this.isSelected = false,
    this.size = AppChipSize.medium,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final AppChipSize size;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppChipSize.small => 26.0,
      AppChipSize.medium => 32.0,
      AppChipSize.large => 38.0,
    };

    final fontSize = switch (size) {
      AppChipSize.small => 11.0,
      AppChipSize.medium => 12.0,
      AppChipSize.large => 13.0,
    };

    final iconSize = switch (size) {
      AppChipSize.small => 14.0,
      AppChipSize.medium => 16.0,
      AppChipSize.large => 18.0,
    };

    final effectiveColor = color ?? AppColors.primary;
    final effectiveBgColor = backgroundColor ??
        (isSelected
            ? effectiveColor.withOpacity(0.12)
            : AppColors.surfaceHover);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: size == AppChipSize.small ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: isSelected
                ? Border.all(color: effectiveColor.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? effectiveColor : AppColors.textSecondary,
                ),
                SizedBox(width: size == AppChipSize.small ? 4 : 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? effectiveColor : AppColors.textPrimary,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.close,
                    size: iconSize - 2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A category chip with predefined colors.
class AppCategoryChip extends StatelessWidget {
  const AppCategoryChip({
    super.key,
    required this.category,
    this.onTap,
    this.size = AppChipSize.medium,
  });

  final String category;
  final VoidCallback? onTap;
  final AppChipSize size;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getCategoryStyle(category);

    return AppChip(
      label: category,
      icon: icon,
      color: color,
      backgroundColor: color.withOpacity(0.15),
      onTap: onTap,
      isSelected: true,
      size: size,
    );
  }

  (Color, IconData?) _getCategoryStyle(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('deer') || lower.contains('buck') || lower.contains('doe')) {
      return (AppColors.categoryDeer, null);
    }
    if (lower.contains('turkey')) {
      return (AppColors.categoryTurkey, null);
    }
    if (lower.contains('bass') || lower.contains('fish')) {
      return (AppColors.categoryBass, null);
    }
    if (lower.contains('game')) {
      return (AppColors.categoryOtherGame, null);
    }
    return (AppColors.categoryOtherFishing, null);
  }
}

/// A location chip for displaying state/county.
class AppLocationChip extends StatelessWidget {
  const AppLocationChip({
    super.key,
    required this.location,
    this.onTap,
    this.size = AppChipSize.small,
  });

  final String location;
  final VoidCallback? onTap;
  final AppChipSize size;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: location,
      icon: Icons.location_on_outlined,
      color: AppColors.textSecondary,
      backgroundColor: Colors.black.withOpacity(0.5),
      onTap: onTap,
      size: size,
    );
  }
}

enum AppChipSize { small, medium, large }

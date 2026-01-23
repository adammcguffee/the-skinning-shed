import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// A surface container with consistent styling.
/// Use for cards, sections, and elevated content.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.border = true,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool border;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg),
        border: border ? Border.all(color: AppColors.borderSubtle) : null,
        boxShadow: shadow ? AppColors.shadowCard : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg),
          hoverColor: AppColors.surfaceHover,
          splashColor: AppColors.primary.withOpacity(0.08),
          child: content,
        ),
      );
    }

    return content;
  }
}

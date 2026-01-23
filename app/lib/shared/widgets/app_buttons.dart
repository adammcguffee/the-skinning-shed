import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// Primary action button with modern styling.
class AppButtonPrimary extends StatefulWidget {
  const AppButtonPrimary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final AppButtonSize size;

  @override
  State<AppButtonPrimary> createState() => _AppButtonPrimaryState();
}

class _AppButtonPrimaryState extends State<AppButtonPrimary> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final height = switch (widget.size) {
      AppButtonSize.small => AppSpacing.buttonHeightSm,
      AppButtonSize.medium => AppSpacing.buttonHeightMd,
      AppButtonSize.large => AppSpacing.buttonHeightLg,
    };

    final fontSize = switch (widget.size) {
      AppButtonSize.small => 13.0,
      AppButtonSize.medium => 14.0,
      AppButtonSize.large => 15.0,
    };

    final horizontalPadding = switch (widget.size) {
      AppButtonSize.small => 16.0,
      AppButtonSize.medium => 24.0,
      AppButtonSize.large => 32.0,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          gradient: widget.onPressed != null
              ? (_isHovered ? AppColors.primaryGradient : null)
              : null,
          color: widget.onPressed != null
              ? (_isHovered ? null : AppColors.primary)
              : AppColors.textDisabled,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: widget.onPressed != null && _isHovered
              ? AppColors.shadowButton
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              constraints: widget.isExpanded
                  ? const BoxConstraints(minWidth: double.infinity)
                  : null,
              child: Row(
                mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.textInverse),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: AppColors.textInverse),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textInverse,
                      letterSpacing: 0.1,
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

/// Secondary/outline button.
class AppButtonSecondary extends StatefulWidget {
  const AppButtonSecondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isExpanded = false,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;
  final AppButtonSize size;

  @override
  State<AppButtonSecondary> createState() => _AppButtonSecondaryState();
}

class _AppButtonSecondaryState extends State<AppButtonSecondary> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final height = switch (widget.size) {
      AppButtonSize.small => AppSpacing.buttonHeightSm,
      AppButtonSize.medium => AppSpacing.buttonHeightMd,
      AppButtonSize.large => AppSpacing.buttonHeightLg,
    };

    final fontSize = switch (widget.size) {
      AppButtonSize.small => 13.0,
      AppButtonSize.medium => 14.0,
      AppButtonSize.large => 15.0,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _isHovered ? AppColors.borderStrong : AppColors.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              constraints: widget.isExpanded
                  ? const BoxConstraints(minWidth: double.infinity)
                  : null,
              child: Row(
                mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
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

/// Icon-only button.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.backgroundColor ?? AppColors.surfaceHover)
              : (widget.backgroundColor ?? Colors.transparent),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.color ?? AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

enum AppButtonSize { small, medium, large }

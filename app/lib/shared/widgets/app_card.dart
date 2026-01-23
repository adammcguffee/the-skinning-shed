import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// A modern card component with hover/press states.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.aspectRatio,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? aspectRatio;
  final Clip clipBehavior;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isPressed
            ? AppColors.surfacePressed
            : _isHovered
                ? AppColors.surfaceHover
                : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
        ),
        boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
      ),
      child: widget.child,
    );

    if (widget.aspectRatio != null) {
      content = AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          clipBehavior: widget.clipBehavior,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A card specifically for image-first content (feed items).
class AppImageCard extends StatefulWidget {
  const AppImageCard({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 4 / 3,
    this.overlayWidgets = const [],
    this.bottomContent,
    this.onTap,
    this.placeholder,
  });

  final String? imageUrl;
  final double aspectRatio;
  final List<Widget> overlayWidgets;
  final Widget? bottomContent;
  final VoidCallback? onTap;
  final Widget? placeholder;

  @override
  State<AppImageCard> createState() => _AppImageCardState();
}

class _AppImageCardState extends State<AppImageCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -2.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image section
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                      Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    else
                      _buildPlaceholder(),

                    // Gradient overlay for text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Overlay widgets (chips, etc.)
                    ...widget.overlayWidgets,
                  ],
                ),
              ),

              // Bottom content
              if (widget.bottomContent != null) widget.bottomContent!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          color: AppColors.backgroundAlt,
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
        );
  }
}

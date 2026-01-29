import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// Category data for explore tiles.
class ExploreCategoryData {
  const ExploreCategoryData({
    required this.name,
    required this.categoryKey,
    required this.color,
    this.imageUrl,
    this.assetPath,
    this.semanticLabel,
  });

  final String name;
  final String categoryKey;
  final Color color;
  
  /// Network image URL (e.g., Unsplash, Supabase storage)
  final String? imageUrl;
  
  /// Local asset path (takes precedence over imageUrl if both provided)
  final String? assetPath;
  
  /// Accessibility label for screen readers
  final String? semanticLabel;
}

/// Premium image-based category tile for Explore screen.
/// 
/// Displays a category with:
/// - Full-bleed background image (local or network)
/// - Gradient overlay for text contrast
/// - Category label at bottom
/// - Hover/tap effects
class ExploreCategoryTile extends StatefulWidget {
  const ExploreCategoryTile({
    super.key,
    required this.data,
    required this.onTap,
  });

  final ExploreCategoryData data;
  final VoidCallback onTap;

  @override
  State<ExploreCategoryTile> createState() => _ExploreCategoryTileState();
}

class _ExploreCategoryTileState extends State<ExploreCategoryTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.data.semanticLabel ?? 'Browse ${widget.data.name}',
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: _isHovered
                ? (Matrix4.identity()..translate(0.0, -4.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: _isHovered
                    ? widget.data.color.withValues(alpha: 0.6)
                    : AppColors.borderSubtle,
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.data.color.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : AppColors.shadowCard,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                _buildBackgroundImage(),

                // Gradient overlay for text contrast (WCAG compliant)
                _buildGradientOverlay(),

                // Category accent indicator (top-left colored bar)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.data.color,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Content (bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category name
                        Text(
                          widget.data.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Browse button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 2,
                            vertical: AppSpacing.xxs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.data.color,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            boxShadow: [
                              BoxShadow(
                                color: widget.data.color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Browse',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: Colors.white,
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
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    // Prefer local asset if available
    if (widget.data.assetPath != null) {
      return Image.asset(
        widget.data.assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackBackground(),
      );
    }

    // Use network image with caching
    if (widget.data.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.data.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) => _buildFallbackBackground(),
        fadeInDuration: const Duration(milliseconds: 300),
        memCacheWidth: 400, // Optimize memory usage
      );
    }

    // Fallback to gradient
    return _buildFallbackBackground();
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.data.color.withValues(alpha: 0.3),
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
              widget.data.color.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.data.color.withValues(alpha: 0.4),
            widget.data.color.withValues(alpha: 0.2),
            AppColors.surface,
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 0.7, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A premium styled card for displaying trophies, listings, and other content.
/// 
/// Photo-first design with compact stats strip below.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    this.imageUrl,
    this.placeholder,
    this.title,
    this.subtitle,
    this.metadata,
    this.trailing,
    this.onTap,
    this.aspectRatio = 4 / 3,
    this.showBorder = true,
  });

  /// URL of the image to display (hero photo)
  final String? imageUrl;
  
  /// Placeholder widget when no image
  final Widget? placeholder;
  
  /// Main title text
  final String? title;
  
  /// Subtitle/description text
  final String? subtitle;
  
  /// Metadata row (stats strip)
  final Widget? metadata;
  
  /// Trailing widget (e.g., action button)
  final Widget? trailing;
  
  /// Tap callback
  final VoidCallback? onTap;
  
  /// Aspect ratio for the image
  final double aspectRatio;
  
  /// Whether to show border
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.cardMargin,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: showBorder
            ? const BorderSide(color: AppColors.borderLight, width: 1)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero image
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _buildImage(),
            ),
            
            // Content section
            if (title != null || subtitle != null || metadata != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title!,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    if (subtitle != null) ...[
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoalLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (metadata != null) metadata!,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return placeholder ?? Container(
      color: AppColors.boneLight,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.charcoalLight,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppColors.boneLight,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.forest,
        ),
      ),
    );
  }
}

/// A compact stats strip for cards showing metadata.
class StatsStrip extends StatelessWidget {
  const StatsStrip({
    super.key,
    required this.items,
  });

  final List<StatsStripItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 14,
                color: AppColors.charcoalLight,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.charcoalLight,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class StatsStripItem {
  const StatsStripItem({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;
}

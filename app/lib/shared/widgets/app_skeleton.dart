import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// A shimmer loading skeleton.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AppSpacing.radiusSm),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.backgroundAlt,
                AppColors.background,
                AppColors.backgroundAlt,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A card skeleton for feed items.
class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({
    super.key,
    this.aspectRatio = 4 / 3,
    this.hasContent = true,
  });

  final double aspectRatio;
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          AspectRatio(
            aspectRatio: aspectRatio,
            child: AppSkeleton(
              borderRadius: BorderRadius.zero,
            ),
          ),

          if (hasContent) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const AppSkeleton(width: 180, height: 18),
                  const SizedBox(height: AppSpacing.sm),
                  // Subtitle
                  const AppSkeleton(width: 120, height: 14),
                  const SizedBox(height: AppSpacing.md),
                  // Actions row - use LayoutBuilder to prevent overflow
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // If width is too narrow, show compact version
                      if (constraints.maxWidth < 160) {
                        return Row(
                          children: [
                            Expanded(
                              child: AppSkeleton(height: 20),
                            ),
                            const SizedBox(width: 8),
                            const AppSkeleton(width: 20, height: 20),
                          ],
                        );
                      }
                      // Normal width: show full actions
                      return Row(
                        children: [
                          const AppSkeleton(width: 60, height: 24),
                          const SizedBox(width: AppSpacing.sm),
                          const AppSkeleton(width: 60, height: 24),
                          const Spacer(),
                          const AppSkeleton(width: 24, height: 24),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A list skeleton.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 72,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? AppSpacing.md : 0,
          ),
          child: Container(
            height: itemHeight,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                AppSkeleton(
                  width: itemHeight - 24,
                  height: itemHeight - 24,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      AppSkeleton(width: 140, height: 16),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeleton(width: 100, height: 12),
                    ],
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

import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// Shows a bottom sheet that sizes itself to its content.
///
/// This eliminates micro-scroll for detail popups by:
/// - Using `isScrollControlled: true` to allow flexible sizing
/// - Letting the content determine its own height (up to maxHeightFraction)
/// - Only enabling scroll if content exceeds available space
///
/// Usage:
/// ```dart
/// showSizedBottomSheet(
///   context: context,
///   child: Column(
///     mainAxisSize: MainAxisSize.min, // IMPORTANT!
///     children: [
///       // Your content here
///     ],
///   ),
/// );
/// ```
Future<T?> showSizedBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 560,
  double maxHeightFraction = 0.85,
  bool showDragHandle = true,
  bool isDismissible = true,
  Color? backgroundColor,
  BorderRadius? borderRadius,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (context) => _SizedBottomSheetContainer(
      maxHeightFraction: maxHeightFraction,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      child: child,
    ),
  );
}

class _SizedBottomSheetContainer extends StatelessWidget {
  const _SizedBottomSheetContainer({
    required this.child,
    required this.maxHeightFraction,
    required this.showDragHandle,
    this.backgroundColor,
    this.borderRadius,
  });

  final Widget child;
  final double maxHeightFraction;
  final bool showDragHandle;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ??
        const BorderRadius.vertical(top: Radius.circular(24));
    final effectiveBg = backgroundColor ?? AppColors.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight * maxHeightFraction;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              color: effectiveBg,
              borderRadius: effectiveRadius,
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    if (showDragHandle) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Content - use Flexible to allow shrinking but prefer min size
                    Flexible(
                      child: SingleChildScrollView(
                        // Only scrolls if content exceeds maxHeight
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A detail card optimized for sized bottom sheets.
///
/// Use this as the child of [showSizedBottomSheet] for consistent styling.
/// Content should use `mainAxisSize: MainAxisSize.min`.
class BottomSheetDetailCard extends StatelessWidget {
  const BottomSheetDetailCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child],
    );
  }
}

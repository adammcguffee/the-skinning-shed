import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';

/// Global modal presenter with full-screen barrier dismiss.
///
/// This ensures clicking ANYWHERE outside the modal content dismisses it,
/// including the logo/header area, side rails, and all darkened areas.
///
/// Uses [showGeneralDialog] with a full-screen GestureDetector overlay
/// to guarantee proper barrier behavior across all platforms.
Future<T?> showShedModal<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 480,
  double maxHeightFraction = 0.85,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x73000000), // ~45% black
  bool showDragHandle = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent, // We handle barrier ourselves
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ShedModalPage(
        maxWidth: maxWidth,
        maxHeightFraction: maxHeightFraction,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        showDragHandle: showDragHandle,
        child: child,
      );
    },
  );
}

class _ShedModalPage extends StatelessWidget {
  const _ShedModalPage({
    required this.child,
    required this.maxWidth,
    required this.maxHeightFraction,
    required this.barrierDismissible,
    required this.barrierColor,
    required this.showDragHandle,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFraction;
  final bool barrierDismissible;
  final Color barrierColor;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * maxHeightFraction;
    final bottomPadding = mediaQuery.viewInsets.bottom;

    return Stack(
      children: [
        // Full-screen barrier - clicking ANYWHERE here dismisses
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: barrierDismissible ? () => Navigator.of(context).pop() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: barrierColor,
            ),
          ),
        ),

        // Keyboard-aware dismiss on ESC
        KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                barrierDismissible) {
              Navigator.of(context).pop();
            }
          },
          child: const SizedBox.shrink(),
        ),

        // Modal content - centered and constrained
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: GestureDetector(
                  // Prevent taps on content from dismissing
                  onTap: () {},
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 16,
                    shadowColor: Colors.black.withOpacity(0.3),
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
                        // Content with scroll if needed
                        Flexible(
                          child: SingleChildScrollView(
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
            ),
          ),
        ),
      ],
    );
  }
}

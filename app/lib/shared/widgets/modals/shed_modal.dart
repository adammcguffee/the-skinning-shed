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
/// and [useRootNavigator: true] to guarantee proper barrier behavior
/// across all platforms and app shells.
Future<T?> showShedModal<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 480,
  double maxHeightFraction = 0.85,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x73000000), // ~45% black
  bool showDragHandle = true,
  bool centerVertically = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true, // CRITICAL: Ensures modal sits above entire app shell
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
        centerVertically: centerVertically,
        child: child,
      );
    },
  );
}

/// Show a center dialog modal (for lists, confirmations, etc.)
/// 
/// This is useful for content that should appear centered on screen
/// rather than anchored to the bottom like a sheet.
Future<T?> showShedCenterModal<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 480,
  double maxHeight = 600,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x73000000),
  bool showCloseButton = true,
  String? title,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ShedCenterModalPage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        showCloseButton: showCloseButton,
        title: title,
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
    required this.centerVertically,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFraction;
  final bool barrierDismissible;
  final Color barrierColor;
  final bool showDragHandle;
  final bool centerVertically;

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
            onTap: barrierDismissible ? () => Navigator.of(context, rootNavigator: true).pop() : null,
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
              Navigator.of(context, rootNavigator: true).pop();
            }
          },
          child: const SizedBox.shrink(),
        ),

        // Modal content - centered and constrained
        Positioned(
          left: 0,
          right: 0,
          bottom: centerVertically ? null : bottomPadding,
          top: centerVertically ? 0 : null,
          child: SafeArea(
            top: centerVertically,
            bottom: !centerVertically,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: GestureDetector(
                  // Prevent taps on content from dismissing
                  onTap: () {},
                  behavior: HitTestBehavior.deferToChild,
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: centerVertically
                        ? BorderRadius.circular(24)
                        : const BorderRadius.vertical(top: Radius.circular(24)),
                    clipBehavior: Clip.antiAlias,
                    elevation: 16,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
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

/// Center modal page for dialogs that should appear in the middle of the screen
class _ShedCenterModalPage extends StatelessWidget {
  const _ShedCenterModalPage({
    required this.child,
    required this.maxWidth,
    required this.maxHeight,
    required this.barrierDismissible,
    required this.barrierColor,
    required this.showCloseButton,
    this.title,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final bool barrierDismissible;
  final Color barrierColor;
  final bool showCloseButton;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen barrier
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: barrierDismissible ? () => Navigator.of(context, rootNavigator: true).pop() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: barrierColor,
            ),
          ),
        ),

        // ESC key dismiss
        KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                barrierDismissible) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          },
          child: const SizedBox.shrink(),
        ),

        // Center modal content
        Center(
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: GestureDetector(
                onTap: () {}, // Prevent dismiss
                behavior: HitTestBehavior.deferToChild,
                child: Material(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  elevation: 24,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with title and close button
                      if (title != null || showCloseButton)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.sm,
                            0,
                          ),
                          child: Row(
                            children: [
                              if (title != null)
                                Expanded(
                                  child: Text(
                                    title!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              if (showCloseButton)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  color: AppColors.textSecondary,
                                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                                  tooltip: 'Close',
                                ),
                            ],
                          ),
                        ),
                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            title != null || showCloseButton ? AppSpacing.sm : AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
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
      ],
    );
  }
}

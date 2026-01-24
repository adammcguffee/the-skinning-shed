import 'package:flutter/material.dart';

/// A layout utility that eliminates micro-scroll on full-screen pages.
///
/// This widget ensures:
/// - Content fills the viewport exactly when it fits
/// - Scrolling is enabled gracefully when content exceeds viewport (small screens, keyboard, accessibility)
/// - No "tiny bounce" or micro-scroll on normal desktop/tablet screens
///
/// Usage:
/// ```dart
/// NoMicroScrollPage(
///   child: Column(
///     mainAxisSize: MainAxisSize.max, // Important!
///     children: [
///       // Your content here
///       const Spacer(), // Optional: push content to top
///       // More content
///     ],
///   ),
/// )
/// ```
class NoMicroScrollPage extends StatelessWidget {
  const NoMicroScrollPage({
    super.key,
    required this.child,
    this.physics = const ClampingScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  /// The content to display. Should use `mainAxisSize: MainAxisSize.max` if a Column.
  final Widget child;
  
  /// Scroll physics. Defaults to ClampingScrollPhysics for no overscroll bounce.
  final ScrollPhysics physics;
  
  /// Optional padding around the content.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: physics,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A variant that includes SafeArea handling.
class NoMicroScrollSafePage extends StatelessWidget {
  const NoMicroScrollSafePage({
    super.key,
    required this.child,
    this.physics = const ClampingScrollPhysics(),
    this.padding = EdgeInsets.zero,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  final Widget child;
  final ScrollPhysics physics;
  final EdgeInsets padding;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: NoMicroScrollPage(
        physics: physics,
        padding: padding,
        child: child,
      ),
    );
  }
}

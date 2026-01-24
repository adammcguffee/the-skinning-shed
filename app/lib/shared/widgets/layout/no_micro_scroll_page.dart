import 'package:flutter/material.dart';

/// A layout utility for full-screen pages that need to fill the viewport
/// but also support scrolling when content overflows (keyboard, small screens).
///
/// IMPORTANT: Do NOT use Expanded, Flexible, or Spacer inside the child!
/// Those widgets require bounded constraints which scroll views don't provide.
///
/// Usage:
/// ```dart
/// NoMicroScrollPage(
///   child: Column(
///     mainAxisSize: MainAxisSize.min, // Use min, NOT max!
///     children: [
///       HeaderWidget(),
///       SizedBox(height: 24),
///       BodyContent(), // No Expanded here!
///     ],
///   ),
/// )
/// ```
///
/// For pages with sections that should expand to fill space, use the
/// [BoundedPage] pattern instead (see below).
class NoMicroScrollPage extends StatelessWidget {
  const NoMicroScrollPage({
    super.key,
    required this.child,
    this.physics = const ClampingScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  /// The content to display. 
  /// IMPORTANT: Use `mainAxisSize: MainAxisSize.min` for Columns.
  /// Do NOT use Expanded/Flexible/Spacer inside.
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
            // No IntrinsicHeight - it doesn't work well with unbounded scroll
            // Just let content size itself naturally
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// A bounded page layout that fills the viewport exactly.
/// Use this when you need Expanded/Flexible children.
///
/// The scrollable area is INSIDE the Expanded section, not wrapping the whole page.
///
/// Usage:
/// ```dart
/// BoundedPage(
///   header: BannerHeader(),
///   body: MyScrollableContent(), // This is wrapped in Expanded
///   footer: BottomBar(), // Optional
/// )
/// ```
class BoundedPage extends StatelessWidget {
  const BoundedPage({
    super.key,
    this.header,
    required this.body,
    this.footer,
  });

  /// Optional header widget (not scrollable).
  final Widget? header;
  
  /// Main body content. Will be wrapped in Expanded to fill remaining space.
  /// If this needs to scroll, wrap it in SingleChildScrollView internally.
  final Widget body;
  
  /// Optional footer widget (not scrollable).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: Column(
            children: [
              if (header != null) header!,
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
        );
      },
    );
  }
}

/// A variant of NoMicroScrollPage that includes SafeArea handling.
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

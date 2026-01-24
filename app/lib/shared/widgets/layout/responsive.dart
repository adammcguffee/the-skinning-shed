import 'package:flutter/material.dart';

/// 📱 RESPONSIVE LAYOUT HELPERS
/// 
/// Provides consistent breakpoint detection and layout constraints
/// across the entire app.

/// Standard breakpoints
class Breakpoints {
  Breakpoints._();
  
  /// Mobile: 0 - 599
  static const double mobileMax = 599;
  
  /// Tablet: 600 - 1023
  static const double tabletMin = 600;
  static const double tabletMax = 1023;
  
  /// Desktop: 1024+
  static const double desktopMin = 1024;
  
  /// Wide desktop: 1440+
  static const double wideDesktopMin = 1440;
}

/// Content width constraints
class ContentWidths {
  ContentWidths._();
  
  /// Max width for main content area
  static const double maxContent = 1100;
  
  /// Max width for forms and narrow content
  static const double maxForm = 560;
  
  /// Max width for cards in a list
  static const double maxCard = 720;
  
  /// Max width for dialogs/modals
  static const double maxDialog = 480;
  
  /// Max width for wide dialogs (like followers list)
  static const double maxWideDialog = 560;
}

/// Responsive helpers based on screen width
class Responsive {
  Responsive._();
  
  /// Check if current width is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= Breakpoints.mobileMax;
  }
  
  /// Check if current width is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= Breakpoints.tabletMin && width <= Breakpoints.tabletMax;
  }
  
  /// Check if current width is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= Breakpoints.desktopMin;
  }
  
  /// Check if current width is wide desktop
  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= Breakpoints.wideDesktopMin;
  }
  
  /// Check if we should show nav rail (tablet+)
  static bool showNavRail(BuildContext context) {
    return MediaQuery.of(context).size.width >= Breakpoints.tabletMin;
  }
  
  /// Get appropriate grid column count
  static int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktopMin) return desktop;
    if (width >= Breakpoints.tabletMin) return tablet;
    return mobile;
  }
}

/// Widget that constrains content to max width and centers it
class MaxContentWidth extends StatelessWidget {
  const MaxContentWidth({
    super.key,
    required this.child,
    this.maxWidth = ContentWidths.maxContent,
    this.padding = EdgeInsets.zero,
  });
  
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Widget that provides safe text with overflow handling
class SafeText extends StatelessWidget {
  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.showTooltip = true,
  });
  
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final bool showTooltip;
  
  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
    
    if (showTooltip) {
      return Tooltip(
        message: text,
        waitDuration: const Duration(milliseconds: 500),
        child: textWidget,
      );
    }
    
    return textWidget;
  }
}

/// Responsive row that wraps to column on mobile
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 12,
    this.alignment = WrapAlignment.start,
    this.crossAlignment = WrapCrossAlignment.center,
    this.breakpoint = Breakpoints.tabletMin,
  });
  
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAlignment;
  final double breakpoint;
  
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAlignment,
      children: children,
    );
  }
}

/// Spacing tokens for consistent layout throughout the app.
class AppSpacing {
  AppSpacing._();

  // ============ BASE UNITS ============
  
  /// 4dp - smallest spacing unit
  static const double xs = 4;
  
  /// 8dp - small spacing
  static const double sm = 8;
  
  /// 12dp - small-medium spacing
  static const double md = 12;
  
  /// 16dp - medium spacing (default)
  static const double lg = 16;
  
  /// 24dp - large spacing
  static const double xl = 24;
  
  /// 32dp - extra large spacing
  static const double xxl = 32;
  
  /// 48dp - section spacing
  static const double xxxl = 48;

  // ============ SEMANTIC SPACING ============
  
  /// Padding inside cards
  static const double cardPadding = 16;
  
  /// Margin around cards
  static const double cardMargin = 8;
  
  /// Screen edge padding
  static const double screenPadding = 16;
  
  /// Space between list items
  static const double listItemSpacing = 8;
  
  /// Space between sections
  static const double sectionSpacing = 24;
  
  /// Space between form fields
  static const double formFieldSpacing = 16;

  // ============ RADIUS ============
  
  /// Small radius (chips, small buttons)
  static const double radiusSm = 8;
  
  /// Medium radius (cards, buttons)
  static const double radiusMd = 12;
  
  /// Large radius (modals, sheets)
  static const double radiusLg = 16;
  
  /// Extra large radius (full cards)
  static const double radiusXl = 24;

  // ============ TOUCH TARGETS ============
  
  /// Minimum touch target size (accessibility)
  static const double minTouchTarget = 44;
  
  /// Standard button height
  static const double buttonHeight = 48;
  
  /// Compact button height
  static const double buttonHeightCompact = 40;
}

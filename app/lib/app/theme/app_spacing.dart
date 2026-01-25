/// 📐 2025 SPACING & RADIUS SYSTEM
/// 
/// Tight, modern spacing with consistent rhythm.
abstract final class AppSpacing {
  AppSpacing._();

  // ════════════════════════════════════════════════════════════════════════════
  // SPACING SCALE (4px base)
  // ════════════════════════════════════════════════════════════════════════════

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 48.0;

  // ════════════════════════════════════════════════════════════════════════════
  // LAYOUT
  // ════════════════════════════════════════════════════════════════════════════

  /// Screen edge padding
  static const double screenPadding = 20.0;

  /// Card internal padding
  static const double cardPadding = 16.0;

  /// Section spacing
  static const double sectionGap = 32.0;

  /// Grid gap
  static const double gridGap = 16.0;

  /// Max content width (web)
  static const double maxContentWidth = 1200.0;

  /// Nav rail width (88px provides room for Create button + icon without overflow)
  static const double navRailWidth = 88.0;

  // ════════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ════════════════════════════════════════════════════════════════════════════

  /// Small elements (chips, badges)
  static const double radiusSm = 8.0;

  /// Medium elements (buttons, inputs)
  static const double radiusMd = 12.0;

  /// Large elements (cards)
  static const double radiusLg = 18.0;

  /// Extra large (modals, sheets)
  static const double radiusXl = 24.0;

  /// Full round (pills, avatars)
  static const double radiusFull = 999.0;

  // ════════════════════════════════════════════════════════════════════════════
  // COMPONENT SIZES
  // ════════════════════════════════════════════════════════════════════════════

  /// Button heights
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 52.0;

  /// Input height
  static const double inputHeight = 48.0;

  /// Avatar sizes
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;

  /// Icon sizes
  static const double iconSm = 18.0;
  static const double iconMd = 22.0;
  static const double iconLg = 26.0;

  /// Chip height
  static const double chipHeight = 32.0;

  // ════════════════════════════════════════════════════════════════════════════
  // BREAKPOINTS
  // ════════════════════════════════════════════════════════════════════════════

  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1200.0;
}

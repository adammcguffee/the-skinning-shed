/// 🎨 BRANDING ASSETS - 2025 MODERN SYSTEM
///
/// RULES:
/// - Use markIcon for all in-app UI (nav, headers, splash)
/// - Use wordmark ONLY if text branding is needed
/// - NEVER use the illustrated badge in app UI (marketing only)
/// - All logos render with BoxFit.contain
/// - All logos have explicit size constraints
abstract final class BrandingAssets {
  BrandingAssets._();

  // ════════════════════════════════════════════════════════════════════════════
  // PRIMARY APP ASSETS (USE THESE)
  // ════════════════════════════════════════════════════════════════════════════

  /// The primary icon mark - use for nav rail, headers, splash, app icon
  static const String markIcon = 'assets/branding/mark_icon.png';

  /// Text wordmark - use sparingly for auth screens or web headers
  static const String wordmark = 'assets/branding/v3/wordmark.png';

  // ════════════════════════════════════════════════════════════════════════════
  // APP ICONS
  // ════════════════════════════════════════════════════════════════════════════

  static const String appIcon1024 = 'assets/branding/app_icon_1024.png';
  static const String appIcon512 = 'assets/branding/app_icon_512.png';

  // ════════════════════════════════════════════════════════════════════════════
  // MARKETING ONLY (DO NOT USE IN APP UI)
  // ════════════════════════════════════════════════════════════════════════════

  @Deprecated('Marketing only - use markIcon for app UI')
  static const String badgePrimary = 'assets/branding/v3/badge_primary.png';

  @Deprecated('Marketing only - use markIcon for app UI')
  static const String badgeDark = 'assets/branding/v3/badge_dark.png';

  @Deprecated('Marketing only - use markIcon for app UI')
  static const String stampMono = 'assets/branding/v3/stamp_mono.png';

  // ════════════════════════════════════════════════════════════════════════════
  // LEGACY (DEPRECATED)
  // ════════════════════════════════════════════════════════════════════════════

  @Deprecated('Use markIcon instead')
  static const String primary = 'assets/branding/logo_primary.png';

  @Deprecated('Use wordmark instead')
  static const String horizontal = 'assets/branding/logo_horizontal.png';

  @Deprecated('Use markIcon instead')
  static const String dark = 'assets/branding/logo_dark.png';

  @Deprecated('Use markIcon instead')
  static const String icon = 'assets/branding/logo_icon.png';

  @Deprecated('Use markIcon instead')
  static const String stampMonoV1 = 'assets/branding/logo_stamp_mono.png';
}

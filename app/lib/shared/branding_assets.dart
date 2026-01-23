/// 🎨 BRANDING ASSETS - THE SKINNING SHED
///
/// USAGE RULES:
/// - BannerHeader: Use badgeDark for hero banners (Feed, Explore, Auth, Trophy Wall)
/// - Navigation: Use markIcon for nav rail, mobile nav, small UI elements
/// - Marketing: Use badgePrimary for external marketing materials only
abstract final class BrandingAssets {
  BrandingAssets._();

  // ════════════════════════════════════════════════════════════════════════════
  // BANNER ASSETS (Hero Headers)
  // ════════════════════════════════════════════════════════════════════════════

  /// Full illustrated badge for dark backgrounds - use in BannerHeader
  /// Features antlers, "THE SKINNING SHED" lettering, premium engraved style
  static const String bannerBadge = 'assets/branding/v3/badge_dark.png';

  /// Text wordmark only - for smaller banner variants
  static const String wordmark = 'assets/branding/v3/wordmark.png';

  // ════════════════════════════════════════════════════════════════════════════
  // UI ICON ASSETS (Navigation, Small Elements)
  // ════════════════════════════════════════════════════════════════════════════

  /// The primary icon mark - use for nav rail, mobile nav, buttons, app icon
  static const String markIcon = 'assets/branding/mark_icon.png';

  // ════════════════════════════════════════════════════════════════════════════
  // APP ICONS
  // ════════════════════════════════════════════════════════════════════════════

  static const String appIcon1024 = 'assets/branding/app_icon_1024.png';
  static const String appIcon512 = 'assets/branding/app_icon_512.png';

  // ════════════════════════════════════════════════════════════════════════════
  // MARKETING ONLY
  // ════════════════════════════════════════════════════════════════════════════

  /// Full badge for light backgrounds (marketing materials only)
  static const String badgePrimary = 'assets/branding/v3/badge_primary.png';

  /// Monochrome stamp (watermarks, merch)
  static const String stampMono = 'assets/branding/v3/stamp_mono.png';

  // ════════════════════════════════════════════════════════════════════════════
  // LEGACY (Deprecated)
  // ════════════════════════════════════════════════════════════════════════════

  @Deprecated('Use bannerBadge for banners, markIcon for UI')
  static const String primary = 'assets/branding/logo_primary.png';

  @Deprecated('Use wordmark instead')
  static const String horizontal = 'assets/branding/logo_horizontal.png';

  @Deprecated('Use bannerBadge instead')
  static const String dark = 'assets/branding/logo_dark.png';

  @Deprecated('Use markIcon instead')
  static const String icon = 'assets/branding/logo_icon.png';
}

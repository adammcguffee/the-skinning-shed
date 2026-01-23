/// 🏆 OFFICIAL BRAND ASSETS - THE SKINNING SHED
///
/// SINGLE SOURCE OF TRUTH for all branding asset paths.
/// These are the ONLY approved assets for use in the app.
///
/// USAGE RULES:
/// - NEVER crop these images in code
/// - ALWAYS use BoxFit.contain
/// - ALWAYS use explicit height constraints
/// - NEVER show white rectangles behind logos
/// - Background must be the app's dark green theme
abstract final class BrandAssets {
  BrandAssets._();

  // ════════════════════════════════════════════════════════════════════════════
  // BANNER ASSETS (Hero Headers)
  // ════════════════════════════════════════════════════════════════════════════

  /// Large hero banner for Auth screen - full ornate design
  /// Use with BannerHeader.authHero
  static const String heroBanner = 'assets/branding/banner_v2/hero_banner.png';

  /// Optional smaller banner (not used for in-app headers)
  static const String pageBanner = 'assets/branding/banner_v2/page_banner.png';

  /// Text wordmark only - "THE SKINNING SHED"
  static const String wordmark = 'assets/branding/banner_v2/wordmark.png';

  /// Crest/icon mark for nav rail
  /// Size: 52px with padding
  static const String crest = 'assets/branding/banner_v2/crest.png';
}

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
  /// Use with BannerHeader.variantAuthHero
  static const String heroBanner = 'assets/branding/banner/hero_banner.png';

  /// Smaller banner for Feed, Explore, Trophy Wall pages
  /// Use with BannerHeader.variantPage
  static const String pageBanner = 'assets/branding/banner/small_banner.png';

  /// Text wordmark only - "THE SKINNING SHED"
  static const String wordmark = 'assets/branding/banner/wordmark.png';

  /// Crest/icon mark for nav rail
  /// Size: 52px with padding
  static const String crest = 'assets/branding/banner/crest.png';
}

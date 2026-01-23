/// 🏷️ THE SKINNING SHED — BRAND ASSETS v3 (FINAL)
///
/// Modern, clean, unclippable branding system.
///
/// ## USAGE RULES
///
/// 1. **Always use `BoxFit.contain`** — never stretch/clip logos
/// 2. **Never let logos determine layout size** — constrain with parent
/// 3. **Icon + wordmark > badge** for most UI contexts
/// 4. **Badges are for marketing** — use sparingly in app
///
/// ## WHERE TO USE WHAT
///
/// | Context          | Asset to Use        |
/// |------------------|---------------------|
/// | Auth screen      | `wordmark` or small `badgePrimary` |
/// | Nav rail header  | `markIcon`          |
/// | Web header       | `wordmark`          |
/// | Mobile header    | `markIcon` + text   |
/// | Feed cards       | **None** (content is hero) |
/// | Splash/loading   | `markIcon`          |
/// | Dark backgrounds | `badgeDark`         |
/// | Watermarks/merch | `stampMono`         |
///
/// ✅ LOCKED — v3 assets have generous transparent padding built-in
abstract final class BrandingAssets {
  BrandingAssets._();

  /// Base path for v3 branding assets
  static const String _basePath = 'assets/branding/v3';

  // ════════════════════════════════════════════════════════════════════════════
  // PRIMARY ASSETS
  // ════════════════════════════════════════════════════════════════════════════

  /// Mark icon — simple square icon, no text, generous padding.
  /// Best for: Nav rail, mobile headers, splash, small spaces, favicon.
  /// Size: 512x512 with ~15% padding
  static const String markIcon = '$_basePath/mark_icon.png';

  /// Wordmark — text-first, minimal, modern.
  /// Best for: Web headers, auth screen, horizontal layouts.
  /// Size: 800x200 with generous padding
  static const String wordmark = '$_basePath/wordmark.png';

  // ════════════════════════════════════════════════════════════════════════════
  // BADGE ASSETS (use sparingly)
  // ════════════════════════════════════════════════════════════════════════════

  /// Badge primary — full illustrated badge with animals + text.
  /// Best for: Marketing, splash (if needed), special occasions.
  /// Use sparingly — prefer markIcon + wordmark for UI.
  /// Size: 1024x1024 with ~12% padding
  static const String badgePrimary = '$_basePath/badge_primary.png';

  /// Badge dark — works on dark backgrounds.
  /// Best for: Dark mode splash, dark promotional banners.
  /// Size: 1024x800 with padding
  static const String badgeDark = '$_basePath/badge_dark.png';

  // ════════════════════════════════════════════════════════════════════════════
  // UTILITY ASSETS
  // ════════════════════════════════════════════════════════════════════════════

  /// Stamp mono — single color for watermarks/merch.
  /// Best for: Photo watermarks, merchandise, embossed effects.
  /// Size: 512x512 with ~15% padding
  static const String stampMono = '$_basePath/stamp_mono.png';

  // ════════════════════════════════════════════════════════════════════════════
  // LEGACY PATHS (deprecated, use v3 above)
  // ════════════════════════════════════════════════════════════════════════════

  @Deprecated('Use markIcon instead')
  static const String icon = 'assets/branding/logo_icon.png';

  @Deprecated('Use wordmark instead')
  static const String horizontal = 'assets/branding/logo_horizontal.png';

  @Deprecated('Use badgePrimary instead')
  static const String primary = 'assets/branding/logo_primary.png';

  @Deprecated('Use badgeDark instead')
  static const String dark = 'assets/branding/logo_dark.png';
}

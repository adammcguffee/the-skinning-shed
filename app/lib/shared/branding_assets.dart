/// Centralized branding asset paths for The Skinning Shed.
///
/// Usage:
/// ```dart
/// Image.asset(BrandingAssets.primary)
/// Image.asset(BrandingAssets.icon, width: 48)
/// ```
abstract final class BrandingAssets {
  BrandingAssets._();

  /// Base path for branding assets
  static const String _basePath = 'assets/branding';

  /// Primary logo - full illustrated mark with "THE SKINNING SHED" banner.
  /// Best for: Auth screen, splash, marketing materials.
  static const String primary = '$_basePath/logo_primary.png';

  /// Horizontal logo - icon + text to the right.
  /// Best for: Wide headers, web app bar, desktop nav.
  static const String horizontal = '$_basePath/logo_horizontal.png';

  /// Dark background variant - works on dark/textured backgrounds.
  /// Best for: Dark mode headers, promotional banners.
  static const String dark = '$_basePath/logo_dark.png';

  /// Icon only - square, no text.
  /// Best for: Nav rail header, narrow headers, favicon, small spaces.
  static const String icon = '$_basePath/logo_icon.png';

  /// Monochrome stamp - single color for watermarks/merch.
  /// Best for: Photo watermarks, merchandise, embossed effects.
  static const String stampMono = '$_basePath/logo_stamp_mono.png';

  /// App icon 1024x1024 - with safe margins for iOS/Android.
  /// Best for: App store submissions, high-res icon needs.
  static const String appIcon1024 = '$_basePath/app_icon_1024.png';

  /// App icon 512x512 - with safe margins.
  /// Best for: Android adaptive icon, medium-res needs.
  static const String appIcon512 = '$_basePath/app_icon_512.png';
}

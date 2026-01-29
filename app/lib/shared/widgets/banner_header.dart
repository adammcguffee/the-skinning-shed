import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding/brand_assets.dart';

/// 🏆 BANNER HEADER - THE SKINNING SHED
///
/// Premium banner widget using official brand assets.
/// Variants:
/// - authHero: Large hero banner for Auth screen (260/230/200px)
/// - appTop: In-app top header (170/150/130px)
///
/// RULES (NON-NEGOTIABLE):
/// - Uses ONLY official assets from BrandAssets
/// - NEVER crops images
/// - Uses BoxFit.contain
/// - Has explicit height constraints
class BannerHeader extends StatelessWidget {
  const BannerHeader._({
    required this.variant,
  });

  /// Hero banner for Auth screen - large and dominant
  const BannerHeader.authHero({Key? key})
      : this._(variant: _BannerVariant.authHero);

  /// In-app top header (uses hero banner asset)
  const BannerHeader.appTop({Key? key}) : this._(variant: _BannerVariant.appTop);

  final _BannerVariant variant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final config = _getConfig(screenWidth);

        return SizedBox(
          width: double.infinity,
          child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: config.verticalPadding,
                  horizontal: config.horizontalPadding,
                ),
            child: Center(
              child: SizedBox(
                height: config.bannerHeight,
                width: double.infinity,
                child: Image.asset(
                  config.assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _BannerConfig _getConfig(double screenWidth) {
    final isWide = screenWidth >= 1024;
    final isMedium = screenWidth >= 600 && screenWidth < 1024;
    final isSmallPhone = screenWidth < 380;

    switch (variant) {
      case _BannerVariant.authHero:
        return _BannerConfig(
          assetPath: BrandAssets.heroBanner,
          bannerHeight: isWide ? 340 : (isMedium ? 300 : (isSmallPhone ? 200 : 260)),
          verticalPadding: isWide ? 40 : (isMedium ? 32 : (isSmallPhone ? 16 : 24)),
          horizontalPadding: AppSpacing.screenPadding,
        );
      case _BannerVariant.appTop:
        // If a checkerboard appears here, the PNG has baked pixels.
        // Do not process the image; replace the asset with a transparent PNG.
        // Responsive: smaller on small phones to give more content space
        return _BannerConfig(
          assetPath: BrandAssets.heroBanner,
          bannerHeight: isWide ? 190 : (isMedium ? 170 : (isSmallPhone ? 100 : 130)),
          verticalPadding: 0,
          horizontalPadding: isSmallPhone ? 4.0 : AppSpacing.sm,
        );
    }
  }
}

enum _BannerVariant {
  authHero,
  appTop,
}

class _BannerConfig {
  const _BannerConfig({
    required this.assetPath,
    required this.bannerHeight,
    required this.verticalPadding,
    required this.horizontalPadding,
  });

  final String assetPath;
  final double bannerHeight;
  final double verticalPadding;
  final double horizontalPadding;
}

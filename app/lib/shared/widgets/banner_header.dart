import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding/brand_assets.dart';

/// 🏆 BANNER HEADER - THE SKINNING SHED
///
/// Premium banner widget using official brand assets.
/// Two variants:
/// - authHero: Large hero banner for Auth screen (260/230/200px)
/// - page: Page banner for Feed/Explore/Trophy (180/160/140px)
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

  /// Page banner for Feed, Explore, Trophy Wall - visually prominent
  const BannerHeader.page({Key? key}) : this._(variant: _BannerVariant.page);

  final _BannerVariant variant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final config = _getConfig(screenWidth);

        return SizedBox(
          width: double.infinity,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: config.maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: config.verticalPadding,
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Center(
                  child: SizedBox(
                    height: config.bannerHeight,
                    child: Image.asset(
                      config.assetPath,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
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

    switch (variant) {
      case _BannerVariant.authHero:
        return _BannerConfig(
          assetPath: BrandAssets.heroBanner,
          bannerHeight: isWide ? 260 : (isMedium ? 230 : 200),
          verticalPadding: isWide ? 40 : (isMedium ? 32 : 24),
          maxWidth: isWide ? 1280 : 1100,
        );
      case _BannerVariant.page:
        return _BannerConfig(
          assetPath: BrandAssets.pageBanner,
          bannerHeight: isWide ? 180 : (isMedium ? 160 : 140),
          verticalPadding: isWide ? 28 : (isMedium ? 24 : 20),
          maxWidth: isWide ? 1200 : 1100,
        );
    }
  }
}

enum _BannerVariant {
  authHero,
  page,
}

class _BannerConfig {
  const _BannerConfig({
    required this.assetPath,
    required this.bannerHeight,
    required this.verticalPadding,
    required this.maxWidth,
  });

  final String assetPath;
  final double bannerHeight;
  final double verticalPadding;
  final double maxWidth;
}

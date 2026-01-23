import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding/brand_assets.dart';

/// 🏆 BANNER HEADER - THE SKINNING SHED
///
/// Premium banner widget using official brand assets.
/// Two variants:
/// - variantAuthHero: Large hero banner for Auth screen (260/230/200px)
/// - variantPage: Page banner for Feed/Explore/Trophy (180/160/135px)
///
/// RULES (NON-NEGOTIABLE):
/// - Uses ONLY official assets from BrandAssets
/// - NEVER crops images
/// - Uses BoxFit.contain
/// - Has explicit height constraints
/// - Subtle glow behind banner
class BannerHeader extends StatelessWidget {
  const BannerHeader._({
    required this.variant,
    this.showSubtitle = false,
    this.subtitle,
  });

  /// Hero banner for Auth screen - large and dominant
  const BannerHeader.variantAuthHero({
    Key? key,
    bool showSubtitle = false,
    String? subtitle,
  }) : this._(
          variant: _BannerVariant.authHero,
          showSubtitle: showSubtitle,
          subtitle: subtitle,
        );

  /// Page banner for Feed, Explore, Trophy Wall - visually prominent
  const BannerHeader.variantPage({
    Key? key,
    bool showSubtitle = false,
    String? subtitle,
  }) : this._(
          variant: _BannerVariant.page,
          showSubtitle: showSubtitle,
          subtitle: subtitle,
        );

  final _BannerVariant variant;
  final bool showSubtitle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final config = _getConfig(screenWidth);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.3),
                AppColors.background,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle radial glow behind banner
              _buildGlow(config),

              // Banner content
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: config.verticalPadding,
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Banner image - explicit height, no clipping
                    Center(
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

                    // Subtitle (optional)
                    if (showSubtitle || subtitle != null) ...[
                      SizedBox(height: config.subtitleSpacing),
                      _buildSubtitle(config),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlow(_BannerConfig config) {
    return Positioned.fill(
      child: Center(
        child: Container(
          width: config.glowWidth,
          height: config.glowHeight,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AppColors.accent.withOpacity(0.12),
                AppColors.accent.withOpacity(0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(_BannerConfig config) {
    return Text(
      subtitle ?? 'Your Trophy Community',
      style: TextStyle(
        fontSize: config.subtitleFontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
      ),
    );
  }

  _BannerConfig _getConfig(double screenWidth) {
    final isWide = screenWidth >= AppSpacing.breakpointDesktop;
    final isMedium = screenWidth >= AppSpacing.breakpointTablet;

    switch (variant) {
      case _BannerVariant.authHero:
        return _BannerConfig(
          assetPath: BrandAssets.heroBanner,
          bannerHeight: isWide ? 260 : (isMedium ? 230 : 200),
          verticalPadding: isWide ? 48 : (isMedium ? 40 : 32),
          subtitleSpacing: 20,
          subtitleFontSize: isWide ? 15 : 13,
          glowWidth: isWide ? 600 : 400,
          glowHeight: isWide ? 400 : 300,
        );
      case _BannerVariant.page:
        return _BannerConfig(
          assetPath: BrandAssets.pageBanner,
          bannerHeight: isWide ? 180 : (isMedium ? 160 : 135),
          verticalPadding: isWide ? 32 : (isMedium ? 24 : 20),
          subtitleSpacing: 16,
          subtitleFontSize: isWide ? 14 : 12,
          glowWidth: isWide ? 500 : 350,
          glowHeight: isWide ? 300 : 220,
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
    required this.subtitleSpacing,
    required this.subtitleFontSize,
    required this.glowWidth,
    required this.glowHeight,
  });

  final String assetPath;
  final double bannerHeight;
  final double verticalPadding;
  final double subtitleSpacing;
  final double subtitleFontSize;
  final double glowWidth;
  final double glowHeight;
}

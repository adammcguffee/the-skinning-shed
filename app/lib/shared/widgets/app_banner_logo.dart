import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding_assets.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🏆 BANNER HEADER - THE SKINNING SHED
///
/// Large, premium, cinematic banner matching the reference design.
/// Features:
/// - Full illustrated badge with antlers + wordmark
/// - Textured dark forest background
/// - Proper scale and visual impact
/// - Used on Feed, Explore, Trophy Wall, Auth
class BannerHeader extends StatelessWidget {
  const BannerHeader({
    super.key,
    this.size = BannerSize.large,
    this.showSubtitle = false,
    this.subtitle,
  });

  final BannerSize size;
  final bool showSubtitle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.4),
            AppColors.background,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle texture overlay
          Positioned.fill(
            child: _buildTextureOverlay(),
          ),

          // Vignette effect
          Positioned.fill(
            child: _buildVignetteOverlay(),
          ),

          // Main content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: config.verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge with glow effect
                _buildBadge(config),

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
  }

  Widget _buildTextureOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Colors.transparent,
            AppColors.primary.withOpacity(0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildVignetteOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Colors.transparent,
            AppColors.background.withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(_BannerConfig config) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: config.badgeMaxWidth,
        maxHeight: config.badgeMaxHeight,
      ),
      decoration: BoxDecoration(
        boxShadow: [
          // Glow effect behind badge
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Image.asset(
        BrandingAssets.bannerBadge,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildSubtitle(_BannerConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.2),
        ),
      ),
      child: Text(
        subtitle ?? 'Your Trophy Community',
        style: GoogleFonts.inter(
          fontSize: config.subtitleFontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  _BannerConfig _getConfig() {
    switch (size) {
      case BannerSize.compact:
        return const _BannerConfig(
          badgeMaxWidth: 200,
          badgeMaxHeight: 100,
          verticalPadding: 16,
          subtitleSpacing: 8,
          subtitleFontSize: 11,
        );
      case BannerSize.medium:
        return const _BannerConfig(
          badgeMaxWidth: 300,
          badgeMaxHeight: 150,
          verticalPadding: 24,
          subtitleSpacing: 12,
          subtitleFontSize: 12,
        );
      case BannerSize.large:
        return const _BannerConfig(
          badgeMaxWidth: 400,
          badgeMaxHeight: 200,
          verticalPadding: 32,
          subtitleSpacing: 16,
          subtitleFontSize: 13,
        );
      case BannerSize.hero:
        return const _BannerConfig(
          badgeMaxWidth: 500,
          badgeMaxHeight: 250,
          verticalPadding: 48,
          subtitleSpacing: 20,
          subtitleFontSize: 14,
        );
    }
  }
}

/// Banner size variants
enum BannerSize {
  compact, // Weather, smaller pages
  medium,  // Trophy Wall
  large,   // Feed, Explore
  hero,    // Auth (full hero treatment)
}

class _BannerConfig {
  const _BannerConfig({
    required this.badgeMaxWidth,
    required this.badgeMaxHeight,
    required this.verticalPadding,
    required this.subtitleSpacing,
    required this.subtitleFontSize,
  });

  final double badgeMaxWidth;
  final double badgeMaxHeight;
  final double verticalPadding;
  final double subtitleSpacing;
  final double subtitleFontSize;
}

// ════════════════════════════════════════════════════════════════════════════
// LEGACY COMPATIBILITY (Redirects to new BannerHeader)
// ════════════════════════════════════════════════════════════════════════════

/// @deprecated Use BannerHeader instead
class AppBannerLogo extends StatelessWidget {
  const AppBannerLogo({
    super.key,
    this.size = AppBannerSize.large,
    this.showSubtitle = false,
    this.subtitle,
  });

  final AppBannerSize size;
  final bool showSubtitle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return BannerHeader(
      size: _convertSize(),
      showSubtitle: showSubtitle,
      subtitle: subtitle,
    );
  }

  BannerSize _convertSize() {
    switch (size) {
      case AppBannerSize.small:
        return BannerSize.compact;
      case AppBannerSize.medium:
        return BannerSize.medium;
      case AppBannerSize.large:
        return BannerSize.large;
      case AppBannerSize.hero:
        return BannerSize.hero;
    }
  }
}

/// @deprecated Use BannerSize instead
enum AppBannerSize {
  small,
  medium,
  large,
  hero,
}

/// Compact banner for inline usage (Trophy Wall profile header, etc.)
class AppBannerCompact extends StatelessWidget {
  const AppBannerCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon mark
        SizedBox(
          width: 36,
          height: 36,
          child: Image.asset(
            BrandingAssets.markIcon,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'THE SKINNING',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
            Text(
              'SHED',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.accent,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/branding_assets.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🏆 PREMIUM BANNER LOGO - THE SKINNING SHED
///
/// Large hero banner for key pages (Feed, Explore, Auth).
/// Features:
/// - "THE SKINNING SHED" lettering prominently
/// - Icon mark with decorative styling
/// - Rich textures and depth
/// - Engraved, premium outdoor feel
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
    final config = _getConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: config.horizontalPadding,
        vertical: config.verticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon mark with glow
          _buildIconMark(config),

          SizedBox(height: config.iconTextSpacing),

          // Main title with decorative lines
          _buildTitle(config),

          // Subtitle (optional)
          if (showSubtitle || subtitle != null) ...[
            SizedBox(height: config.subtitleSpacing),
            _buildSubtitle(config),
          ],
        ],
      ),
    );
  }

  Widget _buildIconMark(_BannerConfig config) {
    return Container(
      width: config.iconSize,
      height: config.iconSize,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.25),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Image.asset(
        BrandingAssets.markIcon,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildTitle(_BannerConfig config) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left decorative line
        _DecorativeLine(width: config.lineWidth, isLeft: true),

        SizedBox(width: config.lineSpacing),

        // Title text
        Column(
          children: [
            Text(
              'THE',
              style: GoogleFonts.inter(
                fontSize: config.theFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: config.theLetterSpacing,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'SKINNING SHED',
              style: GoogleFonts.inter(
                fontSize: config.titleFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: config.titleLetterSpacing,
                color: AppColors.textPrimary,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(width: config.lineSpacing),

        // Right decorative line
        _DecorativeLine(width: config.lineWidth, isLeft: false),
      ],
    );
  }

  Widget _buildSubtitle(_BannerConfig config) {
    return Text(
      subtitle ?? 'Your Trophy Community',
      style: GoogleFonts.inter(
        fontSize: config.subtitleFontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
        color: AppColors.textTertiary,
      ),
    );
  }

  _BannerConfig _getConfig() {
    switch (size) {
      case AppBannerSize.small:
        return _BannerConfig(
          iconSize: 48,
          titleFontSize: 18,
          theFontSize: 10,
          subtitleFontSize: 11,
          horizontalPadding: AppSpacing.lg,
          verticalPadding: AppSpacing.md,
          iconTextSpacing: AppSpacing.sm,
          subtitleSpacing: AppSpacing.xs,
          lineWidth: 24,
          lineSpacing: AppSpacing.sm,
          titleLetterSpacing: 2,
          theLetterSpacing: 4,
        );
      case AppBannerSize.medium:
        return _BannerConfig(
          iconSize: 64,
          titleFontSize: 24,
          theFontSize: 12,
          subtitleFontSize: 12,
          horizontalPadding: AppSpacing.xl,
          verticalPadding: AppSpacing.lg,
          iconTextSpacing: AppSpacing.md,
          subtitleSpacing: AppSpacing.sm,
          lineWidth: 32,
          lineSpacing: AppSpacing.md,
          titleLetterSpacing: 3,
          theLetterSpacing: 5,
        );
      case AppBannerSize.large:
        return _BannerConfig(
          iconSize: 80,
          titleFontSize: 32,
          theFontSize: 14,
          subtitleFontSize: 14,
          horizontalPadding: AppSpacing.xxl,
          verticalPadding: AppSpacing.xl,
          iconTextSpacing: AppSpacing.lg,
          subtitleSpacing: AppSpacing.md,
          lineWidth: 48,
          lineSpacing: AppSpacing.lg,
          titleLetterSpacing: 4,
          theLetterSpacing: 6,
        );
      case AppBannerSize.hero:
        return _BannerConfig(
          iconSize: 100,
          titleFontSize: 40,
          theFontSize: 16,
          subtitleFontSize: 15,
          horizontalPadding: AppSpacing.xxxl,
          verticalPadding: AppSpacing.xxl,
          iconTextSpacing: AppSpacing.xl,
          subtitleSpacing: AppSpacing.md,
          lineWidth: 64,
          lineSpacing: AppSpacing.xl,
          titleLetterSpacing: 5,
          theLetterSpacing: 8,
        );
    }
  }
}

/// Decorative line element for banner
class _DecorativeLine extends StatelessWidget {
  const _DecorativeLine({
    required this.width,
    required this.isLeft,
  });

  final double width;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 2,
      child: CustomPaint(
        painter: _LinePainter(isLeft: isLeft),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.isLeft});

  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: isLeft
            ? [Colors.transparent, AppColors.accent]
            : [AppColors.accent, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Accent dot at the end
    final dotPaint = Paint()..color = AppColors.accent;
    final dotX = isLeft ? size.width : 0.0;
    canvas.drawCircle(Offset(dotX, size.height / 2), 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact banner for inline usage (mobile headers, etc.)
class AppBannerCompact extends StatelessWidget {
  const AppBannerCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        SizedBox(
          width: 32,
          height: 32,
          child: Image.asset(
            BrandingAssets.markIcon,
            fit: BoxFit.contain,
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppColors.textSecondary,
                height: 1.1,
              ),
            ),
            Text(
              'SHED',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Banner size variants
enum AppBannerSize {
  small,
  medium,
  large,
  hero,
}

class _BannerConfig {
  const _BannerConfig({
    required this.iconSize,
    required this.titleFontSize,
    required this.theFontSize,
    required this.subtitleFontSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconTextSpacing,
    required this.subtitleSpacing,
    required this.lineWidth,
    required this.lineSpacing,
    required this.titleLetterSpacing,
    required this.theLetterSpacing,
  });

  final double iconSize;
  final double titleFontSize;
  final double theFontSize;
  final double subtitleFontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconTextSpacing;
  final double subtitleSpacing;
  final double lineWidth;
  final double lineSpacing;
  final double titleLetterSpacing;
  final double theLetterSpacing;
}

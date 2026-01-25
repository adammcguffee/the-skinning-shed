import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/background_theme.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/services/background_theme_provider.dart';
import 'camo_background.dart';

/// Variant for background rendering (main scaffold vs sidebar)
enum BackgroundVariant {
  main,
  sidebar,
  hero,
}

/// Unified app background widget that renders based on selected theme
class AppBackground extends ConsumerWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.variant = BackgroundVariant.main,
  });

  final Widget child;
  final BackgroundVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSpec = ref.watch(backgroundThemeSpecProvider);
    final opacity = variant == BackgroundVariant.sidebar
        ? themeSpec.patternOpacitySidebar
        : themeSpec.patternOpacityMain;

    return Stack(
      children: [
        // Layer 1: Base gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: themeSpec.baseGradient,
            ),
          ),
        ),

        // Layer 2: Camo pattern texture
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HuntingCamoPainter(
                  opacity: opacity,
                  pattern: variant == BackgroundVariant.sidebar
                      ? CamoPattern.subtle
                      : CamoPattern.hunting,
                ),
              ),
            ),
          ),
        ),

        // Layer 3: Leaf litter overlay (if specified)
        if (themeSpec.leafLitterGradient != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: themeSpec.leafLitterGradient!,
                ),
              ),
            ),
          ),

        // Layer 4: Branch shadows (realistic woods depth)
        if (themeSpec.branchShadowColors != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BranchShadowPainter(
                  colors: themeSpec.branchShadowColors!,
                  opacity: opacity * 0.6,
                ),
              ),
            ),
          ),

        // Layer 5: Overlay gradient (warm/cool tones)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: themeSpec.overlayGradient,
              ),
            ),
          ),
        ),

        // Layer 6: Radial vignette (darken edges, keep center readable)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.3,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(
                      alpha: themeSpec.vignetteStrength * 0.3,
                    ),
                    AppColors.background.withValues(
                      alpha: themeSpec.vignetteStrength * 0.6,
                    ),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Layer 7: Content (sits above all background layers)
        child,
      ],
    );
  }
}

/// Painter for branch shadow effects (creates depth in woods camo)
class _BranchShadowPainter extends CustomPainter {
  _BranchShadowPainter({
    required this.colors,
    required this.opacity,
  });

  final List<Color> colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final random = math.Random(123); // Fixed seed for consistency

    // Create 8-12 large soft shadow blobs (simulating branch shadows)
    final shadowCount = 10;
    for (int i = 0; i < shadowCount; i++) {
      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.3 + random.nextDouble() * 0.4))
        ..style = PaintingStyle.fill;

      // Random position
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 80 + random.nextDouble() * 120; // Large soft shadows

      // Create soft shadow using radial gradient-like effect
      // Draw multiple overlapping circles for softness
      for (int j = 0; j < 3; j++) {
        final offset = Offset(
          x + (random.nextDouble() - 0.5) * 20,
          y + (random.nextDouble() - 0.5) * 20,
        );
        final r = radius * (0.7 + j * 0.15);
        final alpha = opacity * (0.2 + j * 0.1);
        
        final shadowPaint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(offset, r, shadowPaint);
      }
    }

    // Add some elongated shadows (simulating fallen branches/logs)
    final logCount = 4;
    for (int i = 0; i < logCount; i++) {
      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.25)
        ..style = PaintingStyle.fill;

      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final length = 100 + random.nextDouble() * 150;
      final angle = random.nextDouble() * math.pi * 2;

      final endX = startX + length * math.cos(angle);
      final endY = startY + length * math.sin(angle);

      // Draw elongated shadow
      final path = Path()
        ..moveTo(startX, startY)
        ..lineTo(endX, endY)
        ..lineTo(endX + 20 * math.cos(angle + math.pi / 2), endY + 20 * math.sin(angle + math.pi / 2))
        ..lineTo(startX + 20 * math.cos(angle + math.pi / 2), startY + 20 * math.sin(angle + math.pi / 2))
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BranchShadowPainter oldDelegate) {
    return colors != oldDelegate.colors || opacity != oldDelegate.opacity;
  }
}

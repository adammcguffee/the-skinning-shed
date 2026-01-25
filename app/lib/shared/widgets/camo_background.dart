import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';

/// 🌿 PREMIUM HUNTING CAMO BACKGROUND
/// 
/// Creates a visible switchgrass/swamp-bottom hunting camo texture.
/// IMPORTANT: Camo is placed BEHIND content, not over it.
/// 
/// Usage areas:
/// - Outer scaffold margins (visible at edges, fades toward center content)
/// - Nav rail background (subtle behind icons)
/// - Hero background BEHIND the wordmark (wordmark sits on top, crisp)

/// 🎨 HUNTING CAMO PATTERN
enum CamoPattern {
  /// Vertical grass strokes + organic shapes (switchgrass/marsh)
  hunting,
  
  /// Simplified subtle pattern for nav rail
  subtle,
}

/// 🖼️ SCAFFOLD CAMO BACKGROUND
/// 
/// Wraps scaffold with VISIBLE camo in outer margins.
/// Center content area is cleaner but camo still visible.
/// Child content sits ABOVE the camo (not covered by it).
class ScaffoldCamoBackground extends StatelessWidget {
  const ScaffoldCamoBackground({
    super.key,
    required this.child,
    this.baseGradient,
    this.camoOpacity = AppColors.kBgPatternOpacity,
  });

  final Widget child;
  final Gradient? baseGradient;
  final double camoOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Base gradient background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: baseGradient ?? AppColors.backgroundGradient,
            ),
          ),
        ),
        
        // Layer 2: Camo texture (VISIBLE - higher opacity)
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HuntingCamoPainter(
                  opacity: camoOpacity,
                  pattern: CamoPattern.hunting,
                ),
              ),
            ),
          ),
        ),
        
        // Layer 3: Warm sage/tan gradient overlay (adds warm tones)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.warmBackgroundGradient,
              ),
            ),
          ),
        ),
        
        // Layer 4: Soft radial vignette - subtle darkening at edges
        // Allows camo and warm tones to show through, slightly darker at edges
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.3,
                  colors: [
                    Colors.transparent, // Full visibility in center
                    AppColors.background.withValues(alpha: 0.2), // Subtle fade
                    AppColors.background.withValues(alpha: 0.5), // More darkening at edges
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // Layer 5: Content (sits above camo - NOT affected)
        child,
      ],
    );
  }
}

/// 🎨 HERO CAMO BACKGROUND
/// 
/// For the banner/header area. Camo visible BEHIND the wordmark.
/// NO overlay between camo and wordmark - wordmark is crisp.
class HeroCamoBackground extends StatelessWidget {
  const HeroCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity = AppColors.kHeroPatternOpacity,
  });

  final Widget child;
  final double camoOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Camo texture (VISIBLE behind wordmark)
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HuntingCamoPainter(
                  opacity: camoOpacity,
                  pattern: CamoPattern.hunting,
                ),
              ),
            ),
          ),
        ),
        
        // Layer 2: Subtle warm gradient overlay (very light)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.warmSage.withValues(alpha: 0.3),
                    AppColors.warmBrown.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Layer 3: Content (wordmark sits ABOVE camo, NOT faded)
        child,
      ],
    );
  }
}

/// 📌 NAV RAIL CAMO BACKGROUND
/// 
/// Visible camo for the navigation rail with warm tones and border.
class NavRailCamoBackground extends StatelessWidget {
  const NavRailCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity = AppColors.kSidebarPatternOpacity,
  });

  final Widget child;
  final double camoOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: AppColors.borderSubtle.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Layer 1: Camo texture (stronger than main background)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _HuntingCamoPainter(
                    opacity: camoOpacity,
                    pattern: CamoPattern.subtle,
                  ),
                ),
              ),
            ),
          ),
          
          // Layer 2: Warm vertical gradient overlay (warmer tones near bottom)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.navRailWarmGradient,
                ),
              ),
            ),
          ),
          
          // Layer 3: Content (nav items sit above camo)
          child,
        ],
      ),
    );
  }
}

/// 🎨 HUNTING CAMO PAINTER
/// 
/// Procedurally generates a switchgrass/swamp-bottom hunting pattern.
/// - Vertical grass strokes
/// - Organic branch/leaf shapes
/// - Earth tones (browns, tans) mixed with forest greens
class _HuntingCamoPainter extends CustomPainter {
  _HuntingCamoPainter({
    required this.opacity,
    required this.pattern,
  });

  final double opacity;
  final CamoPattern pattern;
  
  // Hunting camo colors (switchgrass/swamp-bottom palette)
  // Enhanced with warm tones (sage, tan, cattail brown) for better visibility
  static const _colors = [
    Color(0xFF1A2E20), // Dark green
    Color(0xFF2A4030), // Forest green
    Color(0xFF354535), // Medium green
    Color(0xFF2A2A1E), // Dark brown/mud
    Color(0xFF3A3A28), // Olive brown
    Color(0xFF2E3B2A), // Dark olive
    Color(0xFF3D3A28), // Tan
    Color(0xFF253525), // Deep green
    Color(0xFF2E3A2A), // Sage green (warm)
    Color(0xFF3A2E1F), // Cattail brown (warm)
    Color(0xFF2F2A1D), // Light tan (warm)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final random = math.Random(42); // Fixed seed for consistency
    
    // Draw organic blob shapes first (base camouflage patches)
    _drawOrganicPatches(canvas, size, random);
    
    // Draw vertical grass strokes (switchgrass effect)
    _drawGrassStrokes(canvas, size, random);
    
    if (pattern == CamoPattern.hunting) {
      // Add more detail for full hunting pattern
      _drawReeds(canvas, size, random);
    }
  }
  
  /// Draw organic blob patches (camouflage base patches)
  void _drawOrganicPatches(Canvas canvas, Size size, math.Random random) {
    final patchCount = pattern == CamoPattern.subtle ? 35 : 70;
    
    for (int i = 0; i < patchCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.5 + random.nextDouble() * 0.5))
        ..style = PaintingStyle.fill;
      
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final blobSize = 40 + random.nextDouble() * 100;
      
      _drawOrganicBlob(canvas, paint, x, y, blobSize, random);
    }
  }
  
  /// Draw vertical grass-like strokes
  void _drawGrassStrokes(Canvas canvas, Size size, math.Random random) {
    final strokeCount = pattern == CamoPattern.subtle ? 50 : 100;
    
    for (int i = 0; i < strokeCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.4 + random.nextDouble() * 0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + random.nextDouble() * 4
        ..strokeCap = StrokeCap.round;
      
      // Random start position
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final length = 40 + random.nextDouble() * 100;
      
      // Draw slightly curved vertical stroke
      final path = Path();
      path.moveTo(x, startY);
      
      // Add slight curves to simulate grass bend
      final midX = x + (random.nextDouble() - 0.5) * 20;
      final endX = x + (random.nextDouble() - 0.5) * 10;
      
      path.quadraticBezierTo(
        midX,
        startY + length * 0.5,
        endX,
        startY + length,
      );
      
      canvas.drawPath(path, paint);
    }
  }
  
  /// Draw reed/branch-like elements
  void _drawReeds(Canvas canvas, Size size, math.Random random) {
    const reedCount = 40;
    
    for (int i = 0; i < reedCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + random.nextDouble() * 2
        ..strokeCap = StrokeCap.round;
      
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      
      final path = Path();
      path.moveTo(x, startY);
      
      // Create a multi-segment reed
      double currentY = startY;
      double currentX = x;
      
      for (int j = 0; j < 3 + random.nextInt(3); j++) {
        final segmentLength = 20 + random.nextDouble() * 30;
        final xOffset = (random.nextDouble() - 0.5) * 15;
        
        currentX += xOffset;
        currentY += segmentLength;
        
        path.lineTo(currentX, currentY);
        
        // Occasionally add a small leaf/branch
        if (random.nextDouble() > 0.5) {
          final leafAngle = random.nextBool() ? 0.8 : -0.8;
          final leafLen = 10 + random.nextDouble() * 15;
          
          final leafX = currentX + leafLen * math.cos(leafAngle);
          final leafY = currentY - leafLen * math.sin(leafAngle);
          
          canvas.drawLine(
            Offset(currentX, currentY),
            Offset(leafX, leafY),
            paint,
          );
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }

  void _drawOrganicBlob(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double size,
    math.Random random,
  ) {
    final path = Path();
    final points = 5 + random.nextInt(4); // 5-8 points
    final angleStep = (2 * math.pi) / points;
    
    // Generate irregular radii
    final radii = List.generate(points, (_) {
      return size * (0.3 + random.nextDouble() * 0.7);
    });
    
    // Start point
    final startAngle = random.nextDouble() * math.pi * 2;
    final startX = cx + radii[0] * math.cos(startAngle);
    final startY = cy + radii[0] * math.sin(startAngle);
    path.moveTo(startX, startY);
    
    // Create smooth blob
    for (int i = 0; i < points; i++) {
      final nextI = (i + 1) % points;
      final angle1 = startAngle + angleStep * i;
      final angle2 = startAngle + angleStep * nextI;
      
      final x2 = cx + radii[nextI] * math.cos(angle2);
      final y2 = cy + radii[nextI] * math.sin(angle2);
      
      final midAngle = (angle1 + angle2) / 2;
      final ctrlRadius = (radii[i] + radii[nextI]) / 2 * (0.7 + random.nextDouble() * 0.5);
      final ctrlX = cx + ctrlRadius * math.cos(midAngle);
      final ctrlY = cy + ctrlRadius * math.sin(midAngle);
      
      path.quadraticBezierTo(ctrlX, ctrlY, x2, y2);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HuntingCamoPainter oldDelegate) {
    return opacity != oldDelegate.opacity || pattern != oldDelegate.pattern;
  }
}

// Legacy aliases for compatibility
typedef CamoBackground = ScaffoldCamoBackground;

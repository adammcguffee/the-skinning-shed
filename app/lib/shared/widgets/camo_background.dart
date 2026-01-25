import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';

/// 🌿 PREMIUM HUNTING CAMO BACKGROUND
/// 
/// Creates a subtle switchgrass/swamp-bottom hunting camo texture.
/// IMPORTANT: Camo is placed BEHIND content, not over it.
/// 
/// Usage areas:
/// - Outer scaffold margins (strong at edges, fades to center)
/// - Nav rail background (very subtle)
/// - Hero background BEHIND the wordmark
/// 
/// DO NOT use:
/// - Over wordmark/logo
/// - Behind dense text content areas

/// 🎨 HUNTING CAMO PATTERN
/// 
/// Switchgrass/swamp-bottom style:
/// - Vertical grass-like strokes
/// - Organic branch/reed shapes
/// - Muted earth tones with forest greens
enum CamoPattern {
  /// Vertical grass strokes + organic shapes (switchgrass/marsh)
  hunting,
  
  /// Simplified subtle pattern for nav rail
  subtle,
}

/// 🖼️ SCAFFOLD CAMO BACKGROUND
/// 
/// Wraps scaffold with camo visible in outer margins.
/// Center content stays clean via radial gradient masking.
/// Child content sits ABOVE the camo (not covered by it).
class ScaffoldCamoBackground extends StatelessWidget {
  const ScaffoldCamoBackground({
    super.key,
    required this.child,
    this.baseGradient,
    this.camoOpacity = 0.08,
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
        
        // Layer 2: Camo texture (behind content)
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
        
        // Layer 3: Radial mask to fade camo toward center
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    AppColors.background.withValues(alpha: 0.95), // Hide center
                    AppColors.background.withValues(alpha: 0.7),  // Medium fade
                    Colors.transparent,  // Show full camo at edges
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // Layer 4: Content (sits above camo)
        child,
      ],
    );
  }
}

/// 🎨 HERO CAMO BACKGROUND
/// 
/// For the banner/header area. Camo visible BEHIND the wordmark.
/// Wordmark sits above and remains crisp.
class HeroCamoBackground extends StatelessWidget {
  const HeroCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity = 0.10,
  });

  final Widget child;
  final double camoOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Camo texture (behind everything)
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
        
        // Layer 2: Gradient mask (stronger at bottom to not distract from logo)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,  // Show camo at top
                    AppColors.background.withValues(alpha: 0.5),  // Fade
                    AppColors.background.withValues(alpha: 0.85), // Mostly hidden at bottom
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // Layer 3: Content (logo/wordmark sits ABOVE camo)
        child,
      ],
    );
  }
}

/// 📌 NAV RAIL CAMO BACKGROUND
/// 
/// Very subtle camo for the navigation rail.
class NavRailCamoBackground extends StatelessWidget {
  const NavRailCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity = 0.06,
  });

  final Widget child;
  final double camoOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Camo texture (behind nav items)
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
        
        // Layer 2: Content (nav items sit above camo)
        child,
      ],
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
  static const _colors = [
    Color(0xFF0D1A14), // Very dark green (shadow)
    Color(0xFF1A2820), // Dark forest green
    Color(0xFF25362A), // Medium dark green
    Color(0xFF1C1C14), // Dark brown/mud
    Color(0xFF2A2A1E), // Olive brown
    Color(0xFF1E2B22), // Dark olive
    Color(0xFF32301E), // Tan shadow
    Color(0xFF14201A), // Deep swamp green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final random = math.Random(42); // Fixed seed for consistency
    
    // Draw vertical grass strokes first (switchgrass effect)
    _drawGrassStrokes(canvas, size, random);
    
    // Draw organic blob shapes (branch/leaf patterns)
    _drawOrganicPatches(canvas, size, random);
    
    if (pattern == CamoPattern.hunting) {
      // Add more detail for full hunting pattern
      _drawReeds(canvas, size, random);
    }
  }
  
  /// Draw vertical grass-like strokes
  void _drawGrassStrokes(Canvas canvas, Size size, math.Random random) {
    final strokeCount = pattern == CamoPattern.subtle ? 40 : 80;
    
    for (int i = 0; i < strokeCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.3 + random.nextDouble() * 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + random.nextDouble() * 3
        ..strokeCap = StrokeCap.round;
      
      // Random start position
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final length = 30 + random.nextDouble() * 80;
      
      // Draw slightly curved vertical stroke
      final path = Path();
      path.moveTo(x, startY);
      
      // Add slight curves to simulate grass bend
      final midX = x + (random.nextDouble() - 0.5) * 15;
      final endX = x + (random.nextDouble() - 0.5) * 8;
      
      path.quadraticBezierTo(
        midX,
        startY + length * 0.5,
        endX,
        startY + length,
      );
      
      canvas.drawPath(path, paint);
    }
  }
  
  /// Draw organic blob patches (camouflage patches)
  void _drawOrganicPatches(Canvas canvas, Size size, math.Random random) {
    final patchCount = pattern == CamoPattern.subtle ? 25 : 50;
    
    for (int i = 0; i < patchCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.4 + random.nextDouble() * 0.4))
        ..style = PaintingStyle.fill;
      
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final blobSize = 30 + random.nextDouble() * 70;
      
      _drawOrganicBlob(canvas, paint, x, y, blobSize, random);
    }
  }
  
  /// Draw reed/branch-like elements
  void _drawReeds(Canvas canvas, Size size, math.Random random) {
    final reedCount = 30;
    
    for (int i = 0; i < reedCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 + random.nextDouble() * 1.5
        ..strokeCap = StrokeCap.round;
      
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      
      final path = Path();
      path.moveTo(x, startY);
      
      // Create a multi-segment reed
      double currentY = startY;
      double currentX = x;
      
      for (int j = 0; j < 3 + random.nextInt(3); j++) {
        final segmentLength = 15 + random.nextDouble() * 25;
        final xOffset = (random.nextDouble() - 0.5) * 12;
        
        currentX += xOffset;
        currentY += segmentLength;
        
        path.lineTo(currentX, currentY);
        
        // Occasionally add a small leaf/branch
        if (random.nextDouble() > 0.6) {
          final leafAngle = random.nextBool() ? 0.7 : -0.7;
          final leafLen = 8 + random.nextDouble() * 12;
          
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

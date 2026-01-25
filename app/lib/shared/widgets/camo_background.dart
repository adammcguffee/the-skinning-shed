import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';

/// 🌲 PREMIUM CAMO BACKGROUND OVERLAY
/// 
/// Adds a subtle, almost-transparent camo texture to break up flat dark areas.
/// Uses procedural generation for performance (no image loading).
/// 
/// Usage:
/// - Wrap outer scaffold areas, nav rail, hero zone
/// - Do NOT put behind dense text content
class CamoBackground extends StatelessWidget {
  const CamoBackground({
    super.key,
    required this.child,
    this.opacity = 0.05,
    this.fadeCenter = true,
    this.pattern = CamoPattern.organic,
  });

  final Widget child;
  
  /// Base opacity for the camo texture (0.03-0.10 recommended).
  final double opacity;
  
  /// If true, fades the camo toward the center using a radial gradient mask.
  /// Keeps the center content area clean.
  final bool fadeCenter;
  
  /// The camo pattern style to use.
  final CamoPattern pattern;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Child first (base content)
        child,
        
        // Camo overlay
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CamoPainter(
                  opacity: opacity,
                  pattern: pattern,
                ),
                child: fadeCenter
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.95), // Fade center
                              Colors.black.withValues(alpha: 0.0),  // Keep edges
                            ],
                            radius: 1.2,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 🎨 HERO CAMO - Slightly stronger for the banner area
class HeroCamoBackground extends StatelessWidget {
  const HeroCamoBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CamoPainter(
                  opacity: 0.07,
                  pattern: CamoPattern.organic,
                ),
                // Fade toward bottom to not distract from logo
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 📌 NAV RAIL CAMO - Very subtle for the navigation area
class NavRailCamoBackground extends StatelessWidget {
  const NavRailCamoBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CamoPainter(
                  opacity: 0.04,
                  pattern: CamoPattern.subtle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Camo pattern types
enum CamoPattern {
  /// Organic, natural-looking blobs (classic woodland)
  organic,
  
  /// Very subtle, smaller patterns for tight spaces
  subtle,
}

/// 🎨 PROCEDURAL CAMO PAINTER
/// 
/// Generates a camo-like pattern using overlapping irregular shapes.
/// Performant: uses cached random seeds for consistency.
class _CamoPainter extends CustomPainter {
  _CamoPainter({
    required this.opacity,
    required this.pattern,
  });

  final double opacity;
  final CamoPattern pattern;
  
  // Camo colors (dark forest greens + browns)
  static const _colors = [
    Color(0xFF0D1A14), // Very dark green
    Color(0xFF142820), // Dark forest green
    Color(0xFF1A322A), // Medium dark green
    Color(0xFF0F1512), // Near black
    Color(0xFF1E2B22), // Dark olive
    Color(0xFF15231C), // Deep green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    final blobCount = pattern == CamoPattern.subtle ? 60 : 80;
    final minSize = pattern == CamoPattern.subtle ? 20.0 : 40.0;
    final maxSize = pattern == CamoPattern.subtle ? 80.0 : 180.0;
    
    for (int i = 0; i < blobCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.5 + random.nextDouble() * 0.5))
        ..style = PaintingStyle.fill;
      
      // Random position
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      // Random size
      final blobSize = minSize + random.nextDouble() * (maxSize - minSize);
      
      // Draw organic blob using bezier curves
      _drawOrganicBlob(canvas, paint, x, y, blobSize, random);
    }
    
    // Add some smaller detail blobs
    final detailCount = pattern == CamoPattern.subtle ? 30 : 50;
    for (int i = 0; i < detailCount; i++) {
      final color = _colors[random.nextInt(_colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.7)
        ..style = PaintingStyle.fill;
      
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final blobSize = 15.0 + random.nextDouble() * 40.0;
      
      _drawOrganicBlob(canvas, paint, x, y, blobSize, random);
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
    final points = 6 + random.nextInt(4); // 6-9 points
    final angleStep = (2 * math.pi) / points;
    
    // Generate irregular control points
    final radii = List.generate(points, (_) {
      return size * (0.4 + random.nextDouble() * 0.6);
    });
    
    // Start point
    final startAngle = random.nextDouble() * math.pi * 2;
    final startX = cx + radii[0] * math.cos(startAngle);
    final startY = cy + radii[0] * math.sin(startAngle);
    path.moveTo(startX, startY);
    
    // Create smooth blob using quadratic bezier curves
    for (int i = 0; i < points; i++) {
      final nextI = (i + 1) % points;
      final angle1 = startAngle + angleStep * i;
      final angle2 = startAngle + angleStep * nextI;
      
      // Destination point
      final x2 = cx + radii[nextI] * math.cos(angle2);
      final y2 = cy + radii[nextI] * math.sin(angle2);
      
      // Control point (pulls the curve out or in)
      final midAngle = (angle1 + angle2) / 2;
      final ctrlRadius = (radii[i] + radii[nextI]) / 2 * (0.8 + random.nextDouble() * 0.4);
      final ctrlX = cx + ctrlRadius * math.cos(midAngle);
      final ctrlY = cy + ctrlRadius * math.sin(midAngle);
      
      path.quadraticBezierTo(ctrlX, ctrlY, x2, y2);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CamoPainter oldDelegate) {
    return opacity != oldDelegate.opacity || pattern != oldDelegate.pattern;
  }
}

/// 🖼️ OUTER SCAFFOLD CAMO WRAPPER
/// 
/// Wraps the entire scaffold body with camo on the outer areas only.
/// The center content area stays clean via gradient masking.
class ScaffoldCamoBackground extends StatelessWidget {
  const ScaffoldCamoBackground({
    super.key,
    required this.child,
    this.baseGradient,
  });

  final Widget child;
  final Gradient? baseGradient;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: baseGradient ?? AppColors.backgroundGradient,
            ),
          ),
        ),
        
        // Camo texture overlay
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CamoPainter(
                  opacity: 0.045,
                  pattern: CamoPattern.organic,
                ),
                // Fade toward center to keep content area clean
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        Colors.black.withValues(alpha: 0.92), // Hide in center
                        Colors.black.withValues(alpha: 0.5),  // Medium fade
                        Colors.black.withValues(alpha: 0.0),  // Full camo at edges
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Content
        child,
      ],
    );
  }
}

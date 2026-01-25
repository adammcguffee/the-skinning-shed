import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/shared/widgets/app_background.dart';

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
/// Wraps scaffold with theme-aware background.
/// Uses AppBackground for unified rendering.
class ScaffoldCamoBackground extends StatelessWidget {
  const ScaffoldCamoBackground({
    super.key,
    required this.child,
    this.baseGradient,
    this.camoOpacity,
  });

  final Widget child;
  final Gradient? baseGradient; // Deprecated - kept for compatibility
  final double? camoOpacity; // Deprecated - kept for compatibility

  @override
  Widget build(BuildContext context) {
    // Use unified AppBackground widget
    return AppBackground(
      variant: BackgroundVariant.main,
      child: child,
    );
  }
}

/// 🎨 HERO CAMO BACKGROUND
/// 
/// For the banner/header area. Camo visible BEHIND the wordmark.
/// Uses AppBackground for unified rendering.
class HeroCamoBackground extends StatelessWidget {
  const HeroCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity, // Deprecated - kept for compatibility
  });

  final Widget child;
  final double? camoOpacity;

  @override
  Widget build(BuildContext context) {
    // Use unified AppBackground widget
    return AppBackground(
      variant: BackgroundVariant.hero,
      child: child,
    );
  }
}

/// 📌 NAV RAIL CAMO BACKGROUND
/// 
/// Visible camo for the navigation rail with warm tones and border.
/// Uses AppBackground for unified rendering.
class NavRailCamoBackground extends StatelessWidget {
  const NavRailCamoBackground({
    super.key,
    required this.child,
    this.camoOpacity, // Deprecated - kept for compatibility
  });

  final Widget child;
  final double? camoOpacity;

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
      child: AppBackground(
        variant: BackgroundVariant.sidebar,
        child: child,
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
class HuntingCamoPainter extends CustomPainter {
  HuntingCamoPainter({
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
  bool shouldRepaint(HuntingCamoPainter oldDelegate) {
    return opacity != oldDelegate.opacity || pattern != oldDelegate.pattern;
  }
}

// Legacy aliases for compatibility
typedef CamoBackground = ScaffoldCamoBackground;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shed/app/theme/background_theme.dart';

/// Painter for antler pattern overlay
class AntlerPatternPainter extends CustomPainter {
  AntlerPatternPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final random = math.Random(789); // Fixed seed for consistency
    final spacing = 120.0; // Spacing between antlers
    final rows = (size.height / spacing).ceil() + 1;
    final cols = (size.width / spacing).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final baseX = col * spacing + (row % 2 == 0 ? 0 : spacing / 2);
        final baseY = row * spacing;
        
        // Offset slightly for randomness
        final x = baseX + (random.nextDouble() - 0.5) * 20;
        final y = baseY + (random.nextDouble() - 0.5) * 20;

        _drawAntler(canvas, Offset(x, y), paint, random);
      }
    }
  }

  void _drawAntler(Canvas canvas, Offset center, Paint paint, math.Random random) {
    final path = Path();
    
    // Main beam (vertical)
    final beamLength = 25 + random.nextDouble() * 15;
    final beamStart = center;
    final beamEnd = Offset(center.dx, center.dy - beamLength);
    
    path.moveTo(beamStart.dx, beamStart.dy);
    path.lineTo(beamEnd.dx, beamEnd.dy);

    // Left tine
    final leftTineAngle = -0.6 + random.nextDouble() * 0.3;
    final leftTineLength = 12 + random.nextDouble() * 8;
    final leftTineEnd = Offset(
      beamEnd.dx + leftTineLength * math.cos(leftTineAngle),
      beamEnd.dy + leftTineLength * math.sin(leftTineAngle),
    );
    path.moveTo(beamEnd.dx, beamEnd.dy);
    path.lineTo(leftTineEnd.dx, leftTineEnd.dy);

    // Right tine
    final rightTineAngle = 0.6 - random.nextDouble() * 0.3;
    final rightTineLength = 12 + random.nextDouble() * 8;
    final rightTineEnd = Offset(
      beamEnd.dx + rightTineLength * math.cos(rightTineAngle),
      beamEnd.dy + rightTineLength * math.sin(rightTineAngle),
    );
    path.moveTo(beamEnd.dx, beamEnd.dy);
    path.lineTo(rightTineEnd.dx, rightTineEnd.dy);

    // Optional second tine on left
    if (random.nextDouble() > 0.5) {
      final secondLeftTineEnd = Offset(
        leftTineEnd.dx + 8 * math.cos(leftTineAngle - 0.3),
        leftTineEnd.dy + 8 * math.sin(leftTineAngle - 0.3),
      );
      path.moveTo(leftTineEnd.dx, leftTineEnd.dy);
      path.lineTo(secondLeftTineEnd.dx, secondLeftTineEnd.dy);
    }

    // Optional second tine on right
    if (random.nextDouble() > 0.5) {
      final secondRightTineEnd = Offset(
        rightTineEnd.dx + 8 * math.cos(rightTineAngle + 0.3),
        rightTineEnd.dy + 8 * math.sin(rightTineAngle + 0.3),
      );
      path.moveTo(rightTineEnd.dx, rightTineEnd.dy);
      path.lineTo(secondRightTineEnd.dx, secondRightTineEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AntlerPatternPainter oldDelegate) => opacity != oldDelegate.opacity;
}

/// Painter for topo lines overlay
class TopoLinesPainter extends CustomPainter {
  TopoLinesPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final spacing = 30.0;
    final random = math.Random(456); // Fixed seed

    // Draw horizontal contour lines
    for (double y = spacing; y < size.height; y += spacing) {
      final path = Path();
      final baseY = y + (random.nextDouble() - 0.5) * 5;
      
      path.moveTo(0, baseY);
      
      // Create wavy contour line
      for (double x = 0; x < size.width; x += 10) {
        final wave = math.sin(x / 40) * 3;
        path.lineTo(x, baseY + wave);
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw some vertical contour lines (fewer)
    for (double x = spacing * 2; x < size.width; x += spacing * 2) {
      final path = Path();
      final baseX = x + (random.nextDouble() - 0.5) * 5;
      
      path.moveTo(baseX, 0);
      
      // Create wavy vertical contour
      for (double y = 0; y < size.height; y += 10) {
        final wave = math.cos(y / 40) * 3;
        path.lineTo(baseX + wave, y);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(TopoLinesPainter oldDelegate) => opacity != oldDelegate.opacity;
}

/// Painter for leather texture overlay
class LeatherTexturePainter extends CustomPainter {
  LeatherTexturePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final random = math.Random(321);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw subtle leather grain lines
    for (int i = 0; i < 50; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final length = 20 + random.nextDouble() * 30;
      final angle = random.nextDouble() * math.pi * 2;

      final endX = startX + length * math.cos(angle);
      final endY = startY + length * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LeatherTexturePainter oldDelegate) => opacity != oldDelegate.opacity;
}

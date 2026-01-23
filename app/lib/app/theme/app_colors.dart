import 'package:flutter/material.dart';

/// 🎨 2025 PREMIUM COLOR SYSTEM
/// 
/// Modern, tech-forward palette with intentional color usage.
/// NO beige slabs. NO rustic/antique feel.
abstract final class AppColors {
  AppColors._();

  // ════════════════════════════════════════════════════════════════════════════
  // CORE BRAND COLORS
  // ════════════════════════════════════════════════════════════════════════════

  /// Primary: Deep forest green - sophisticated, premium
  static const Color primary = Color(0xFF1B3D36);
  static const Color primaryHover = Color(0xFF245249);
  static const Color primaryMuted = Color(0xFF2D5C52);

  /// Accent: Burnt copper - warm, energetic, ONE accent only
  static const Color accent = Color(0xFFCD8232);
  static const Color accentHover = Color(0xFFE09540);
  static const Color accentMuted = Color(0xFFB87428);

  // ════════════════════════════════════════════════════════════════════════════
  // SURFACE & BACKGROUND
  // ════════════════════════════════════════════════════════════════════════════

  /// Background: Subtle warm off-white with depth
  static const Color background = Color(0xFFF8F6F3);
  static const Color backgroundAlt = Color(0xFFF3F0EC);

  /// Surface: Clean white for cards
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHover = Color(0xFFFCFBFA);
  static const Color surfacePressed = Color(0xFFF5F3F0);

  /// Elevated surface (modals, dropdowns)
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // ════════════════════════════════════════════════════════════════════════════
  // TEXT HIERARCHY
  // ════════════════════════════════════════════════════════════════════════════

  /// Primary text: Near-black for maximum readability
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Secondary text: For subtitles, descriptions
  static const Color textSecondary = Color(0xFF5C5C5C);

  /// Tertiary text: For metadata, timestamps, hints
  static const Color textTertiary = Color(0xFF8A8A8A);

  /// Disabled text
  static const Color textDisabled = Color(0xFFB8B8B8);

  /// Inverse text (on dark backgrounds)
  static const Color textInverse = Color(0xFFFFFFFF);

  // ════════════════════════════════════════════════════════════════════════════
  // BORDERS & DIVIDERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Default border
  static const Color border = Color(0xFFE5E2DE);

  /// Subtle border (cards)
  static const Color borderSubtle = Color(0xFFEBE8E4);

  /// Strong border (inputs, focused)
  static const Color borderStrong = Color(0xFFD1CCC5);

  /// Divider
  static const Color divider = Color(0xFFF0EDE9);

  // ════════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ════════════════════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF2E7D5A);
  static const Color successLight = Color(0xFFE8F5EE);

  static const Color warning = Color(0xFFD4930D);
  static const Color warningLight = Color(0xFFFFF8E6);

  static const Color error = Color(0xFFD93B3B);
  static const Color errorLight = Color(0xFFFEECEC);

  static const Color info = Color(0xFF3B82D9);
  static const Color infoLight = Color(0xFFECF4FE);

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORY COLORS (for species chips)
  // ════════════════════════════════════════════════════════════════════════════

  static const Color categoryDeer = Color(0xFF8B6914);
  static const Color categoryTurkey = Color(0xFF9C4221);
  static const Color categoryBass = Color(0xFF1E6091);
  static const Color categoryOtherGame = Color(0xFF5D4E37);
  static const Color categoryOtherFishing = Color(0xFF2D6A6A);

  // ════════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ════════════════════════════════════════════════════════════════════════════

  /// Card shadow
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: const Color(0xFF1A1A1A).withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF1A1A1A).withOpacity(0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Elevated shadow (modals, dropdowns)
  static List<BoxShadow> get shadowElevated => [
    BoxShadow(
      color: const Color(0xFF1A1A1A).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1A1A1A).withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Button shadow
  static List<BoxShadow> get shadowButton => [
    BoxShadow(
      color: primary.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ════════════════════════════════════════════════════════════════════════════

  /// Subtle background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundAlt],
  );

  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryHover, primary],
  );

  /// Accent highlight gradient
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHover, accent],
  );
}

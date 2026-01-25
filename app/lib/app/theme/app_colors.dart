import 'package:flutter/material.dart';

/// 🎨 2025 PREMIUM DARK THEME - THE SKINNING SHED
///
/// Cinematic, outdoor-premium aesthetic with deep forest greens.
/// Based on visual target: Dark, rich, dramatic.
abstract final class AppColors {
  AppColors._();

  // ════════════════════════════════════════════════════════════════════════════
  // CORE PALETTE (DARK FOREST THEME)
  // ════════════════════════════════════════════════════════════════════════════

  /// Primary: Deep forest green - premium, sophisticated
  static const Color primary = Color(0xFF1E4D40);
  static const Color primaryHover = Color(0xFF256354);
  static const Color primaryMuted = Color(0xFF2A5A4D);
  static const Color primaryDark = Color(0xFF0F2A24);

  /// Accent: Warm copper/brass - hunter aesthetic, ONE accent only
  static const Color accent = Color(0xFFCD8232);
  static const Color accentHover = Color(0xFFE09540);
  static const Color accentMuted = Color(0xFFB87428);
  static const Color accentGlow = Color(0x40CD8232);

  // ════════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS (DARK, RICH)
  // ════════════════════════════════════════════════════════════════════════════

  /// Background: Near-black forest green
  static const Color background = Color(0xFF0C1614);
  static const Color backgroundAlt = Color(0xFF101D1A);

  /// Surface: Dark charcoal-green for cards
  static const Color surface = Color(0xFF162420);
  static const Color surfaceHover = Color(0xFF1C2E28);
  static const Color surfacePressed = Color(0xFF223832);
  static const Color surfaceElevated = Color(0xFF1A2A25);

  // ════════════════════════════════════════════════════════════════════════════
  // TEXT HIERARCHY (IVORY/CREAM ON DARK)
  // ════════════════════════════════════════════════════════════════════════════

  /// Primary text: Warm ivory - maximum readability on dark
  static const Color textPrimary = Color(0xFFF5F2EC);

  /// Secondary text: Muted gray-green
  static const Color textSecondary = Color(0xFFA3B5AC);

  /// Tertiary text: Subtle desaturated tone
  static const Color textTertiary = Color(0xFF728579);

  /// Disabled text
  static const Color textDisabled = Color(0xFF4A5A54);

  /// Inverse text (on light backgrounds like accent buttons)
  static const Color textInverse = Color(0xFF0C1614);

  // ════════════════════════════════════════════════════════════════════════════
  // BORDERS & DIVIDERS (SUBTLE GLOW)
  // ════════════════════════════════════════════════════════════════════════════

  /// Default border
  static const Color border = Color(0xFF2A3E38);

  /// Subtle border (cards)
  static const Color borderSubtle = Color(0xFF223230);

  /// Strong border (inputs, focused, hover)
  static const Color borderStrong = Color(0xFF3A524A);

  /// Accent border (highlighted elements)
  static const Color borderAccent = Color(0x60CD8232);

  /// Divider
  static const Color divider = Color(0xFF1E2E2A);

  // ════════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS (MUTED FOR DARK THEME)
  // ════════════════════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF3A9D6E);
  static const Color successLight = Color(0x203A9D6E);

  static const Color warning = Color(0xFFD4930D);
  static const Color warningLight = Color(0x20D4930D);

  static const Color error = Color(0xFFE05555);
  static const Color errorLight = Color(0x20E05555);

  static const Color info = Color(0xFF4A9ED9);
  static const Color infoLight = Color(0x204A9ED9);

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORY COLORS (VIBRANT ON DARK)
  // ════════════════════════════════════════════════════════════════════════════

  static const Color categoryDeer = Color(0xFFB8923C);
  static const Color categoryTurkey = Color(0xFFD4764A);
  static const Color categoryBass = Color(0xFF4A8FAA);
  static const Color categoryOtherGame = Color(0xFF8B7355);
  static const Color categoryOtherFishing = Color(0xFF4A8A8A);

  // ════════════════════════════════════════════════════════════════════════════
  // SHADOWS (DRAMATIC ON DARK)
  // ════════════════════════════════════════════════════════════════════════════

  /// Card shadow - subtle depth
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Elevated shadow - modals, dropdowns
  static List<BoxShadow> get shadowElevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Button shadow with accent glow
  static List<BoxShadow> get shadowButton => [
    BoxShadow(
      color: primary.withOpacity(0.4),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Accent glow shadow
  static List<BoxShadow> get shadowAccent => [
    BoxShadow(
      color: accent.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // GRADIENTS (RICH, DRAMATIC)
  // ════════════════════════════════════════════════════════════════════════════

  /// Background gradient - subtle depth
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundAlt],
  );

  /// Surface gradient - card sheen
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2C26), Color(0xFF14221E)],
  );

  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryHover, primary],
  );

  /// Accent button gradient
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHover, accent],
  );

  /// Banner overlay gradient (for image overlays)
  static LinearGradient get bannerOverlay => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      background.withOpacity(0.6),
      background.withOpacity(0.95),
    ],
    stops: const [0.0, 0.6, 1.0],
  );

  /// Card image overlay gradient
  static LinearGradient get cardOverlay => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.7),
    ],
  );

  // ════════════════════════════════════════════════════════════════════════════
  // GLASS / FROSTED EFFECTS
  // ════════════════════════════════════════════════════════════════════════════

  /// Glass overlay color
  static Color get glassOverlay => background.withOpacity(0.7);

  /// Glass border color
  static Color get glassBorder => textPrimary.withOpacity(0.1);

  // ════════════════════════════════════════════════════════════════════════════
  // BACKGROUND PATTERN CONFIGURATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Main scaffold background pattern opacity (0.14-0.22 range)
  static const double kBgPatternOpacity = 0.18;

  /// Navigation rail background pattern opacity (stronger than main)
  static const double kSidebarPatternOpacity = 0.22;

  /// Hero/banner background pattern opacity
  static const double kHeroPatternOpacity = 0.16;

  /// Warm sage/tan colors for background gradient overlay
  static const Color warmSage = Color(0xFF1A2E1F); // Sage green
  static const Color warmBrown = Color(0xFF2A2418); // Light brown/tan
  static const Color warmOlive = Color(0xFF1F2A1E); // Olive green
  static const Color cattailTan = Color(0xFF2E251A); // Cattail brown

  /// Warm background gradient overlay (greens + tan/brown)
  static const LinearGradient warmBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      warmSage,
      warmOlive,
      warmBrown,
      cattailTan,
      backgroundAlt,
    ],
    stops: [0.0, 0.3, 0.6, 0.8, 1.0],
  );

  /// Navigation rail warm gradient (vertical, warmer tones near bottom)
  static const LinearGradient navRailWarmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      warmSage,
      warmOlive,
      warmBrown,
      cattailTan,
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );
}

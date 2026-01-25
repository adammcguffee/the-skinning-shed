import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';

/// Background theme identifier
enum BackgroundThemeId {
  woodsRealistic,
  woodsCattails,
  pineTimber,
  classicSubtle,
}

/// Background theme specification
class BackgroundThemeSpec {
  const BackgroundThemeSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.baseGradient,
    required this.overlayGradient,
    required this.patternOpacityMain,
    required this.patternOpacitySidebar,
    required this.vignetteStrength,
    this.branchShadowColors,
    this.leafLitterGradient,
  });

  final BackgroundThemeId id;
  final String title;
  final String description;
  final LinearGradient baseGradient;
  final LinearGradient overlayGradient;
  final double patternOpacityMain;
  final double patternOpacitySidebar;
  final double vignetteStrength;
  final List<Color>? branchShadowColors;
  final LinearGradient? leafLitterGradient;
}

/// All available background themes
class BackgroundThemes {
  BackgroundThemes._();

  /// Woods Camo (Realistic) - Main target theme
  /// Layered branches, leaf litter, shadows for authentic woods camo
  static const woodsRealistic = BackgroundThemeSpec(
    id: BackgroundThemeId.woodsRealistic,
    title: 'Woods Camo (Realistic)',
    description: 'Authentic layered branches, leaf litter, and shadows',
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A120F), // Deep forest near-black
        Color(0xFF0F1A16), // Dark green-black
        Color(0xFF0C1614), // Current background
        Color(0xFF0A0F0D), // Near-black
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x661A2E1F), // Sage green overlay (0.4 opacity)
        Color(0x4D2A2418), // Tan/brown overlay (0.3 opacity)
        Color(0x591F2A1E), // Olive overlay (0.35 opacity)
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.22,
    patternOpacitySidebar: 0.26,
    vignetteStrength: 0.6,
    branchShadowColors: [
      Color(0xFF0A0F0D), // Deep shadow
      Color(0xFF0F1A16), // Medium shadow
      Color(0xFF1A2E1F), // Light shadow
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x402E251A), // Cattail brown (0.25 opacity)
        Color(0x333A2E1F), // Light tan (0.2 opacity)
        Color(0x262A2418), // Muted brown (0.15 opacity)
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Woods Camo (Late Season / Cattails) - More tan/sage tones
  static const woodsCattails = BackgroundThemeSpec(
    id: BackgroundThemeId.woodsCattails,
    title: 'Woods Camo (Late Season / Cattails)',
    description: 'Warmer tan and sage tones for late season',
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F), // Sage green
        Color(0xFF2A2418), // Tan
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x592E251A), // Cattail brown (0.35 opacity)
        Color(0x4D3A2E1F), // Light tan (0.3 opacity)
        Color(0x402A2418), // Muted brown (0.25 opacity)
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.20,
    patternOpacitySidebar: 0.24,
    vignetteStrength: 0.55,
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D3A2E1F), // Light tan (0.3 opacity)
        Color(0x402E251A), // Cattail brown (0.25 opacity)
        Color(0x332A2418), // Muted brown (0.2 opacity)
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Pine / Dark Timber - Cooler green, higher contrast
  static const pineTimber = BackgroundThemeSpec(
    id: BackgroundThemeId.pineTimber,
    title: 'Pine / Dark Timber',
    description: 'Cooler green tones with higher contrast',
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D), // Near-black
        Color(0xFF0F1A16), // Dark green-black
        Color(0xFF1A2E20), // Dark green
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D1A2E20), // Cool green (0.3 opacity)
        Color(0x402A4030), // Forest green (0.25 opacity)
        Color(0x331F2A1E), // Dark olive (0.2 opacity)
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.18,
    patternOpacitySidebar: 0.22,
    vignetteStrength: 0.65,
    branchShadowColors: [
      Color(0xFF0A0F0D), // Deep shadow
      Color(0xFF0F1A16), // Medium shadow
      Color(0xFF1A2E20), // Light shadow
    ],
  );

  /// Classic Subtle - Current style but improved
  static const classicSubtle = BackgroundThemeSpec(
    id: BackgroundThemeId.classicSubtle,
    title: 'Classic Subtle',
    description: 'Refined version of the original style',
    baseGradient: AppColors.backgroundGradient,
    overlayGradient: AppColors.warmBackgroundGradient,
    patternOpacityMain: 0.16,
    patternOpacitySidebar: 0.20,
    vignetteStrength: 0.5,
  );

  /// Get theme spec by ID
  static BackgroundThemeSpec getById(BackgroundThemeId id) {
    switch (id) {
      case BackgroundThemeId.woodsRealistic:
        return woodsRealistic;
      case BackgroundThemeId.woodsCattails:
        return woodsCattails;
      case BackgroundThemeId.pineTimber:
        return pineTimber;
      case BackgroundThemeId.classicSubtle:
        return classicSubtle;
    }
  }

  /// Get all available themes
  static List<BackgroundThemeSpec> get all => [
        woodsRealistic,
        woodsCattails,
        pineTimber,
        classicSubtle,
      ];

  /// Default theme
  static const BackgroundThemeId defaultId = BackgroundThemeId.woodsRealistic;
}

import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';

/// Background theme category
enum BackgroundThemeCategory {
  woodsHardwoods,
  pineTimber,
  swampRiverbottom,
  marshDuck,
  premiumPatterns,
  classicMinimal,
}

/// Pattern overlay type for premium patterns
enum PatternOverlayType {
  none,
  antler,
  topo,
  leatherBrass,
}

/// Background theme identifier
enum BackgroundThemeId {
  // Woods (Hardwoods)
  woodsRealistic,
  hardwoodLeafLitter,
  oakRidge,
  hickoryShadow,
  backForty,
  
  // Pine & Timber
  pineTimber,
  pineNeedles,
  timberBark,
  cedarBreaks,
  
  // Swamp / Riverbottom
  riverbottomMuddy,
  bayouShadow,
  bottomland,
  
  // Marsh / Duck
  woodsCattails,
  cattailMarsh,
  duckBlindMarsh,
  tidalMarsh,
  
  // Premium Patterns
  antlerPattern,
  topoLines,
  leatherBrass,
  
  // Classic / Minimal
  classicSubtle,
  premiumGraphite,
  deepOliveMinimal,
}

/// Background theme specification
class BackgroundThemeSpec {
  const BackgroundThemeSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.baseGradient,
    required this.overlayGradient,
    required this.patternOpacityMain,
    required this.patternOpacitySidebar,
    required this.vignetteStrength,
    this.branchShadowColors,
    this.leafLitterGradient,
    this.patternOverlay = PatternOverlayType.none,
  });

  final BackgroundThemeId id;
  final String title;
  final String description;
  final BackgroundThemeCategory category;
  final Gradient baseGradient;
  final Gradient overlayGradient;
  final double patternOpacityMain;
  final double patternOpacitySidebar;
  final double vignetteStrength;
  final List<Color>? branchShadowColors;
  final Gradient? leafLitterGradient;
  final PatternOverlayType patternOverlay;
}

/// All available background themes
class BackgroundThemes {
  BackgroundThemes._();

  // ════════════════════════════════════════════════════════════════════════════
  // WOODS (HARDWOODS)
  // ════════════════════════════════════════════════════════════════════════════

  /// Woods Camo (Realistic) - Main target theme
  static const woodsRealistic = BackgroundThemeSpec(
    id: BackgroundThemeId.woodsRealistic,
    title: 'Woods Camo (Realistic)',
    description: 'Authentic layered branches, leaf litter, and shadows',
    category: BackgroundThemeCategory.woodsHardwoods,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A120F),
        Color(0xFF0F1A16),
        Color(0xFF0C1614),
        Color(0xFF0A0F0D),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x661A2E1F),
        Color(0x4D2A2418),
        Color(0x591F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.22,
    patternOpacitySidebar: 0.26,
    vignetteStrength: 0.6,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x402E251A),
        Color(0x333A2E1F),
        Color(0x262A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Hardwood Leaf Litter - Warmer brown/olive, leaf-litter vibe
  static const hardwoodLeafLitter = BackgroundThemeSpec(
    id: BackgroundThemeId.hardwoodLeafLitter,
    title: 'Hardwood Leaf Litter',
    description: 'Warmer brown and olive tones with leaf-litter depth',
    category: BackgroundThemeCategory.woodsHardwoods,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D2E251A),
        Color(0x403A2E1F),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.20,
    patternOpacitySidebar: 0.24,
    vignetteStrength: 0.55,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF1A2E1F),
      Color(0xFF2A2418),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D3A2E1F),
        Color(0x402E251A),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Oak Ridge (Early Season) - Deep green + muted tan highlights
  static const oakRidge = BackgroundThemeSpec(
    id: BackgroundThemeId.oakRidge,
    title: 'Oak Ridge (Early Season)',
    description: 'Deep green with muted tan highlights',
    category: BackgroundThemeCategory.woodsHardwoods,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A120F),
        Color(0xFF0F1A16),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D1A2E20),
        Color(0x402A2418),
        Color(0x331F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.21,
    patternOpacitySidebar: 0.25,
    vignetteStrength: 0.58,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E20),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x332A2418),
        Color(0x2E3A2E1F),
        Color(0x262A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Hickory Shadow - Darker, higher contrast, branch-shadow feel
  static const hickoryShadow = BackgroundThemeSpec(
    id: BackgroundThemeId.hickoryShadow,
    title: 'Hickory Shadow',
    description: 'Darker with higher contrast and branch-shadow depth',
    category: BackgroundThemeCategory.woodsHardwoods,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF0C1614),
        Color(0xFF0A0F0D),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x331A2E20),
        Color(0x2E2A4030),
        Color(0x261F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.24,
    patternOpacitySidebar: 0.28,
    vignetteStrength: 0.65,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E20),
      Color(0xFF0C1614),
    ],
  );

  /// Back Forty - Midwest woods vibe, balanced greens and browns
  static const backForty = BackgroundThemeSpec(
    id: BackgroundThemeId.backForty,
    title: 'Back Forty',
    description: 'Midwest woods vibe with balanced greens and browns',
    category: BackgroundThemeCategory.woodsHardwoods,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D1A2E1F),
        Color(0x402A2418),
        Color(0x331F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.19,
    patternOpacitySidebar: 0.23,
    vignetteStrength: 0.52,
    branchShadowColors: [
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
      Color(0xFF2A2418),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x3D3A2E1F),
        Color(0x332E251A),
        Color(0x2E2A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  // ════════════════════════════════════════════════════════════════════════════
  // PINE & TIMBER
  // ════════════════════════════════════════════════════════════════════════════

  /// Pine / Dark Timber - Cooler green, higher contrast
  static const pineTimber = BackgroundThemeSpec(
    id: BackgroundThemeId.pineTimber,
    title: 'Pine / Dark Timber',
    description: 'Cooler green tones with higher contrast',
    category: BackgroundThemeCategory.pineTimber,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D1A2E20),
        Color(0x402A4030),
        Color(0x331F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.18,
    patternOpacitySidebar: 0.22,
    vignetteStrength: 0.65,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E20),
    ],
  );

  /// Pine Needles - Cooler pine greens, needle-floor vibe
  static const pineNeedles = BackgroundThemeSpec(
    id: BackgroundThemeId.pineNeedles,
    title: 'Pine Needles',
    description: 'Cooler pine greens with needle-floor texture',
    category: BackgroundThemeCategory.pineTimber,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x401A2E20),
        Color(0x332A4030),
        Color(0x2E1F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.20,
    patternOpacitySidebar: 0.24,
    vignetteStrength: 0.68,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E20),
    ],
  );

  /// Timber Bark - Bark-like contrast (charcoal + dark olive)
  static const timberBark = BackgroundThemeSpec(
    id: BackgroundThemeId.timberBark,
    title: 'Timber Bark',
    description: 'Bark-like contrast with charcoal and dark olive',
    category: BackgroundThemeCategory.pineTimber,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x331A2E20),
        Color(0x2E2A4030),
        Color(0x261F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.22,
    patternOpacitySidebar: 0.26,
    vignetteStrength: 0.70,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E20),
      Color(0xFF0C1614),
    ],
  );

  /// Cedar Breaks - Muted sage + deep green, slightly drier feel
  static const cedarBreaks = BackgroundThemeSpec(
    id: BackgroundThemeId.cedarBreaks,
    title: 'Cedar Breaks',
    description: 'Muted sage and deep green with drier texture',
    category: BackgroundThemeCategory.pineTimber,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x3D1A2E1F),
        Color(0x331A2E20),
        Color(0x2E1F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.19,
    patternOpacitySidebar: 0.23,
    vignetteStrength: 0.60,
    branchShadowColors: [
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
      Color(0xFF1A2E20),
    ],
  );

  // ════════════════════════════════════════════════════════════════════════════
  // SWAMP / RIVERBOTTOM
  // ════════════════════════════════════════════════════════════════════════════

  /// Riverbottom (Muddy) - Deep brown + olive + soft mud gradients
  static const riverbottomMuddy = BackgroundThemeSpec(
    id: BackgroundThemeId.riverbottomMuddy,
    title: 'Riverbottom (Muddy)',
    description: 'Deep brown and olive with soft mud gradients',
    category: BackgroundThemeCategory.swampRiverbottom,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF1A1E16),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D2A2418),
        Color(0x401A2E1F),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.21,
    patternOpacitySidebar: 0.25,
    vignetteStrength: 0.58,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF1A1E16),
      Color(0xFF2A2418),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x402A2418),
        Color(0x333A2E1F),
        Color(0x2E2A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Bayou Shadow - Darker swamp greens, subtle warm haze
  static const bayouShadow = BackgroundThemeSpec(
    id: BackgroundThemeId.bayouShadow,
    title: 'Bayou Shadow',
    description: 'Darker swamp greens with subtle warm haze',
    category: BackgroundThemeCategory.swampRiverbottom,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x3D1A2E1F),
        Color(0x332A2418),
        Color(0x2E1F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.23,
    patternOpacitySidebar: 0.27,
    vignetteStrength: 0.62,
    branchShadowColors: [
      Color(0xFF0A0F0D),
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
    ],
  );

  /// Bottomland - Classic southern riverbottom vibe
  static const bottomland = BackgroundThemeSpec(
    id: BackgroundThemeId.bottomland,
    title: 'Bottomland',
    description: 'Classic southern riverbottom with layered shadows',
    category: BackgroundThemeCategory.swampRiverbottom,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D2A2418),
        Color(0x401A2E1F),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.20,
    patternOpacitySidebar: 0.24,
    vignetteStrength: 0.55,
    branchShadowColors: [
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
      Color(0xFF2A2418),
    ],
    leafLitterGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x3D3A2E1F),
        Color(0x332E251A),
        Color(0x2E2A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  // ════════════════════════════════════════════════════════════════════════════
  // MARSH / DUCK
  // ════════════════════════════════════════════════════════════════════════════

  /// Woods Camo (Late Season / Cattails) - More tan/sage tones
  static const woodsCattails = BackgroundThemeSpec(
    id: BackgroundThemeId.woodsCattails,
    title: 'Woods Camo (Late Season / Cattails)',
    description: 'Warmer tan and sage tones for late season',
    category: BackgroundThemeCategory.marshDuck,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x592E251A),
        Color(0x4D3A2E1F),
        Color(0x402A2418),
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
        Color(0x4D3A2E1F),
        Color(0x402E251A),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Cattail Marsh - Tan/sage reeds vibe
  static const cattailMarsh = BackgroundThemeSpec(
    id: BackgroundThemeId.cattailMarsh,
    title: 'Cattail Marsh',
    description: 'Tan and sage reeds with marsh texture',
    category: BackgroundThemeCategory.marshDuck,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x4D3A2E1F),
        Color(0x402E251A),
        Color(0x332A2418),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.19,
    patternOpacitySidebar: 0.23,
    vignetteStrength: 0.52,
    leafLitterGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x3D3A2E1F),
        Color(0x332E251A),
        Color(0x2E2A2418),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Duck Blind (Marsh Grass) - Straw/tan + olive with vertical gradient
  static const duckBlindMarsh = BackgroundThemeSpec(
    id: BackgroundThemeId.duckBlindMarsh,
    title: 'Duck Blind (Marsh Grass)',
    description: 'Straw and tan with olive, vertical reed gradient',
    category: BackgroundThemeCategory.marshDuck,
    baseGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x4D3A2E1F),
        Color(0x402E251A),
        Color(0x331A2E1F),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.20,
    patternOpacitySidebar: 0.24,
    vignetteStrength: 0.54,
    leafLitterGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x3D3A2E1F),
        Color(0x332E251A),
        Color(0x2E1A2E1F),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// Tidal Marsh - Greener marsh with warmer edges
  static const tidalMarsh = BackgroundThemeSpec(
    id: BackgroundThemeId.tidalMarsh,
    title: 'Tidal Marsh',
    description: 'Greener marsh with warmer edges and soft contrast',
    category: BackgroundThemeCategory.marshDuck,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF1A2E20),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x401A2E1F),
        Color(0x331A2E20),
        Color(0x2E2A2418),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.18,
    patternOpacitySidebar: 0.22,
    vignetteStrength: 0.50,
    branchShadowColors: [
      Color(0xFF0F1A16),
      Color(0xFF1A2E1F),
      Color(0xFF1A2E20),
    ],
  );

  // ════════════════════════════════════════════════════════════════════════════
  // PREMIUM PATTERNS
  // ════════════════════════════════════════════════════════════════════════════

  /// Antler Pattern (Subtle) - Repeating antler silhouettes at low opacity
  static const antlerPattern = BackgroundThemeSpec(
    id: BackgroundThemeId.antlerPattern,
    title: 'Antler Pattern (Subtle)',
    description: 'Subtle repeating antler silhouettes',
    category: BackgroundThemeCategory.premiumPatterns,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF0C1614),
        Color(0xFF0A0F0D),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x331A2E20),
        Color(0x2E2A4030),
        Color(0x261F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.16,
    patternOpacitySidebar: 0.20,
    vignetteStrength: 0.55,
    patternOverlay: PatternOverlayType.antler,
  );

  /// Topo Lines (Outdoors) - Faint topo contour lines overlay
  static const topoLines = BackgroundThemeSpec(
    id: BackgroundThemeId.topoLines,
    title: 'Topo Lines (Outdoors)',
    description: 'Faint topographical contour lines overlay',
    category: BackgroundThemeCategory.premiumPatterns,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0F1A16),
        Color(0xFF0C1614),
        Color(0xFF0A0F0D),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x331A2E20),
        Color(0x2E2A4030),
        Color(0x261F2A1E),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.15,
    patternOpacitySidebar: 0.19,
    vignetteStrength: 0.50,
    patternOverlay: PatternOverlayType.topo,
  );

  /// Leather & Brass - Dark leather vibe with warm brass glow
  static const leatherBrass = BackgroundThemeSpec(
    id: BackgroundThemeId.leatherBrass,
    title: 'Leather & Brass',
    description: 'Dark leather with warm brass glow near corners',
    category: BackgroundThemeCategory.premiumPatterns,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF1A1E16),
        Color(0xFF2A2418),
        Color(0xFF1F1A14),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x33CD8232), // Brass glow (0.2 opacity) at top-left
        Color(0x262A2418),
        Color(0x1A2A2418),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
    patternOpacityMain: 0.14,
    patternOpacitySidebar: 0.18,
    vignetteStrength: 0.45,
    patternOverlay: PatternOverlayType.leatherBrass,
  );

  // ════════════════════════════════════════════════════════════════════════════
  // CLASSIC / MINIMAL
  // ════════════════════════════════════════════════════════════════════════════

  /// Classic Subtle - Current style but improved
  static const classicSubtle = BackgroundThemeSpec(
    id: BackgroundThemeId.classicSubtle,
    title: 'Classic Subtle',
    description: 'Refined version of the original style',
    category: BackgroundThemeCategory.classicMinimal,
    baseGradient: AppColors.backgroundGradient,
    overlayGradient: AppColors.warmBackgroundGradient,
    patternOpacityMain: 0.16,
    patternOpacitySidebar: 0.20,
    vignetteStrength: 0.5,
  );

  /// Premium Graphite - Deep charcoal gradient
  static const premiumGraphite = BackgroundThemeSpec(
    id: BackgroundThemeId.premiumGraphite,
    title: 'Premium Graphite',
    description: 'Deep charcoal gradient with faint vignette',
    category: BackgroundThemeCategory.classicMinimal,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0A0F0D),
        Color(0xFF0C1614),
        Color(0xFF0A0F0D),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x261A1E16),
        Color(0x1F1F1F1A),
        Color(0x1A0A0F0D),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.12,
    patternOpacitySidebar: 0.16,
    vignetteStrength: 0.40,
  );

  /// Deep Olive Minimal - Simple rich olive gradient
  static const deepOliveMinimal = BackgroundThemeSpec(
    id: BackgroundThemeId.deepOliveMinimal,
    title: 'Deep Olive Minimal',
    description: 'Simple rich olive gradient',
    category: BackgroundThemeCategory.classicMinimal,
    baseGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F1A16),
        Color(0xFF1A2E1F),
        Color(0xFF0C1614),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    overlayGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x2E1A2E1F),
        Color(0x261F2A1E),
        Color(0x1F0C1614),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    patternOpacityMain: 0.14,
    patternOpacitySidebar: 0.18,
    vignetteStrength: 0.45,
  );

  // ════════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ════════════════════════════════════════════════════════════════════════════

  /// Get theme spec by ID
  static BackgroundThemeSpec getById(BackgroundThemeId id) {
    switch (id) {
      // Woods (Hardwoods)
      case BackgroundThemeId.woodsRealistic:
        return woodsRealistic;
      case BackgroundThemeId.hardwoodLeafLitter:
        return hardwoodLeafLitter;
      case BackgroundThemeId.oakRidge:
        return oakRidge;
      case BackgroundThemeId.hickoryShadow:
        return hickoryShadow;
      case BackgroundThemeId.backForty:
        return backForty;
      
      // Pine & Timber
      case BackgroundThemeId.pineTimber:
        return pineTimber;
      case BackgroundThemeId.pineNeedles:
        return pineNeedles;
      case BackgroundThemeId.timberBark:
        return timberBark;
      case BackgroundThemeId.cedarBreaks:
        return cedarBreaks;
      
      // Swamp / Riverbottom
      case BackgroundThemeId.riverbottomMuddy:
        return riverbottomMuddy;
      case BackgroundThemeId.bayouShadow:
        return bayouShadow;
      case BackgroundThemeId.bottomland:
        return bottomland;
      
      // Marsh / Duck
      case BackgroundThemeId.woodsCattails:
        return woodsCattails;
      case BackgroundThemeId.cattailMarsh:
        return cattailMarsh;
      case BackgroundThemeId.duckBlindMarsh:
        return duckBlindMarsh;
      case BackgroundThemeId.tidalMarsh:
        return tidalMarsh;
      
      // Premium Patterns
      case BackgroundThemeId.antlerPattern:
        return antlerPattern;
      case BackgroundThemeId.topoLines:
        return topoLines;
      case BackgroundThemeId.leatherBrass:
        return leatherBrass;
      
      // Classic / Minimal
      case BackgroundThemeId.classicSubtle:
        return classicSubtle;
      case BackgroundThemeId.premiumGraphite:
        return premiumGraphite;
      case BackgroundThemeId.deepOliveMinimal:
        return deepOliveMinimal;
    }
  }

  /// Get all available themes
  static List<BackgroundThemeSpec> get all => [
        // Woods (Hardwoods)
        woodsRealistic,
        hardwoodLeafLitter,
        oakRidge,
        hickoryShadow,
        backForty,
        
        // Pine & Timber
        pineTimber,
        pineNeedles,
        timberBark,
        cedarBreaks,
        
        // Swamp / Riverbottom
        riverbottomMuddy,
        bayouShadow,
        bottomland,
        
        // Marsh / Duck
        woodsCattails,
        cattailMarsh,
        duckBlindMarsh,
        tidalMarsh,
        
        // Premium Patterns
        antlerPattern,
        topoLines,
        leatherBrass,
        
        // Classic / Minimal
        classicSubtle,
        premiumGraphite,
        deepOliveMinimal,
      ];

  /// Get themes by category
  static List<BackgroundThemeSpec> getByCategory(BackgroundThemeCategory category) {
    return all.where((theme) => theme.category == category).toList();
  }

  /// Get category display name
  static String getCategoryName(BackgroundThemeCategory category) {
    switch (category) {
      case BackgroundThemeCategory.woodsHardwoods:
        return 'Woods (Hardwoods)';
      case BackgroundThemeCategory.pineTimber:
        return 'Pine & Timber';
      case BackgroundThemeCategory.swampRiverbottom:
        return 'Swamp / Riverbottom';
      case BackgroundThemeCategory.marshDuck:
        return 'Marsh / Duck';
      case BackgroundThemeCategory.premiumPatterns:
        return 'Premium Patterns';
      case BackgroundThemeCategory.classicMinimal:
        return 'Classic / Minimal';
    }
  }

  /// Default theme
  static const BackgroundThemeId defaultId = BackgroundThemeId.woodsRealistic;
}

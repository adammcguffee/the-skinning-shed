import 'package:flutter/material.dart';

/// 🎨 THE SKINNING SHED — FINAL COLOR SYSTEM (2025)
/// 
/// Design philosophy: Outdoors-inspired, tech-forward, premium.
/// No neon, no camo, no rustic kitsch.
/// 
/// ✅ LOCKED — Do not modify without design review.
/// 
/// Usage: Always use tokens, never hardcode colors in widgets.
/// Example: `AppColors.primary` not `Color(0xFF1F3D2E)`
abstract final class AppColors {
  AppColors._();

  // ════════════════════════════════════════════════════════════════════════════
  // CORE BRAND COLORS
  // ════════════════════════════════════════════════════════════════════════════

  /// Primary brand color — deep forest green
  /// Use for: Primary buttons, active states, brand elements
  static const Color primary = Color(0xFF1F3D2E);

  /// Primary hover/pressed state
  static const Color primaryHover = Color(0xFF2A5240);

  /// Primary container — lighter for backgrounds
  static const Color primaryContainer = Color(0xFFD8E8DF);

  /// On primary — text/icons on primary color
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// On primary container — text/icons on primary container
  static const Color onPrimaryContainer = Color(0xFF0D1E14);

  // ════════════════════════════════════════════════════════════════════════════
  // SECONDARY — Cool Sage/Moss
  // ════════════════════════════════════════════════════════════════════════════

  /// Secondary — muted sage for supporting elements
  static const Color secondary = Color(0xFF526B5A);

  /// Secondary container
  static const Color secondaryContainer = Color(0xFFDCE8DE);

  /// On secondary
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// On secondary container
  static const Color onSecondaryContainer = Color(0xFF1A2B1F);

  // ════════════════════════════════════════════════════════════════════════════
  // ACCENT — Burnt Copper (SINGLE ACCENT COLOR)
  // ════════════════════════════════════════════════════════════════════════════

  /// Accent — burnt copper for highlights, badges, CTAs
  /// This is the ONLY accent color. Use sparingly for emphasis.
  static const Color accent = Color(0xFFB87333);

  /// Accent hover
  static const Color accentHover = Color(0xFFC98544);

  /// Accent container
  static const Color accentContainer = Color(0xFFFAE6D5);

  /// On accent
  static const Color onAccent = Color(0xFFFFFFFF);

  /// On accent container
  static const Color onAccentContainer = Color(0xFF3D2510);

  // ════════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS & SURFACES
  // ════════════════════════════════════════════════════════════════════════════

  /// Background — warm off-white (NOT beige slabs)
  /// Main app background
  static const Color background = Color(0xFFFAF9F7);

  /// Surface — clean near-white for cards, sheets
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface alt — subtle warm tint for section separation
  static const Color surfaceAlt = Color(0xFFF5F4F1);

  /// Surface elevated — for elevated components (modals, dropdowns)
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// On surface — primary content color
  static const Color onSurface = Color(0xFF1C2620);

  /// On surface variant — secondary content
  static const Color onSurfaceVariant = Color(0xFF4A5650);

  // ════════════════════════════════════════════════════════════════════════════
  // TEXT COLORS — Semantic text hierarchy
  // ════════════════════════════════════════════════════════════════════════════

  /// Text primary — near-black with green undertone
  /// Use for: Headlines, important body text
  static const Color textPrimary = Color(0xFF1C2620);

  /// Text secondary — muted for supporting text
  /// Use for: Descriptions, secondary labels
  static const Color textSecondary = Color(0xFF4A5650);

  /// Text tertiary — subtle for metadata
  /// Use for: Timestamps, hints, captions
  static const Color textTertiary = Color(0xFF7A857E);

  /// Text disabled
  static const Color textDisabled = Color(0xFFA8B0AB);

  /// Text inverse — for dark backgrounds
  static const Color textInverse = Color(0xFFFAF9F7);

  // ════════════════════════════════════════════════════════════════════════════
  // BORDERS & DIVIDERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Border default — subtle neutral
  static const Color border = Color(0xFFE4E6E5);

  /// Border strong — more visible borders
  static const Color borderStrong = Color(0xFFCDD1CE);

  /// Border focus — for focused inputs
  static const Color borderFocus = primary;

  /// Divider
  static const Color divider = Color(0xFFECEDEC);

  // ════════════════════════════════════════════════════════════════════════════
  // SEMANTIC / SYSTEM COLORS
  // ════════════════════════════════════════════════════════════════════════════

  /// Success — muted green (not neon)
  static const Color success = Color(0xFF2E7D5A);
  static const Color successContainer = Color(0xFFD4EDDF);
  static const Color onSuccess = Color(0xFFFFFFFF);

  /// Warning — warm amber (not harsh yellow)
  static const Color warning = Color(0xFFC27A1A);
  static const Color warningContainer = Color(0xFFFFF0D9);
  static const Color onWarning = Color(0xFFFFFFFF);

  /// Error — muted red (not harsh)
  static const Color error = Color(0xFFB34545);
  static const Color errorContainer = Color(0xFFFDE8E8);
  static const Color onError = Color(0xFFFFFFFF);

  /// Info — neutral blue-gray
  static const Color info = Color(0xFF4A7080);
  static const Color infoContainer = Color(0xFFE0EEF3);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ════════════════════════════════════════════════════════════════════════════
  // SPECIES CATEGORY COLORS — Subtle differentiation
  // ════════════════════════════════════════════════════════════════════════════

  /// Deer — warm brown
  static const Color categoryDeer = Color(0xFF7A6350);

  /// Turkey — slate gray
  static const Color categoryTurkey = Color(0xFF5A6870);

  /// Bass — water blue-green
  static const Color categoryBass = Color(0xFF4A7080);

  /// Other game — earthy brown
  static const Color categoryOtherGame = Color(0xFF6B5B4E);

  /// Other fishing — cool water
  static const Color categoryOtherFishing = Color(0xFF5A7A8A);

  // ════════════════════════════════════════════════════════════════════════════
  // DARK MODE — Future-ready tokens
  // ════════════════════════════════════════════════════════════════════════════

  /// Dark background
  static const Color darkBackground = Color(0xFF121816);

  /// Dark surface
  static const Color darkSurface = Color(0xFF1C2420);

  /// Dark surface alt
  static const Color darkSurfaceAlt = Color(0xFF252E2A);

  /// Dark surface elevated
  static const Color darkSurfaceElevated = Color(0xFF2A3430);

  /// Dark border
  static const Color darkBorder = Color(0xFF3A4440);

  /// Dark divider
  static const Color darkDivider = Color(0xFF2A3430);

  // ════════════════════════════════════════════════════════════════════════════
  // SHADOWS — Modern soft shadows (use with BoxShadow)
  // ════════════════════════════════════════════════════════════════════════════

  /// Shadow color — warm neutral
  static const Color shadowColor = Color(0xFF1C2620);

  /// Elevation presets (use shadowOpacity for varying levels)
  static const double shadowOpacityLow = 0.04;
  static const double shadowOpacityMedium = 0.08;
  static const double shadowOpacityHigh = 0.12;
}

/// Pre-built shadow styles for consistent elevation
class AppShadows {
  AppShadows._();

  /// Subtle shadow for cards
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Medium shadow for elevated elements
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Strong shadow for modals/overlays
  static List<BoxShadow> get modal => [
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.shadowColor.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Soft glow for primary buttons on hover
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Soft glow for accent elements
  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: AppColors.accent.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

import 'package:flutter/material.dart';

/// 📐 THE SKINNING SHED — SPACING & RADIUS SYSTEM (2025)
/// 
/// Consistent spacing scale based on 4dp grid.
/// 
/// ✅ LOCKED — Do not modify without design review.
abstract final class AppSpacing {
  AppSpacing._();

  // ════════════════════════════════════════════════════════════════════════════
  // SPACING SCALE (4dp base unit)
  // ════════════════════════════════════════════════════════════════════════════

  /// 2dp — micro spacing
  static const double xxs = 2;

  /// 4dp — extra small
  static const double xs = 4;

  /// 8dp — small
  static const double sm = 8;

  /// 12dp — small-medium
  static const double md = 12;

  /// 16dp — medium (default)
  static const double lg = 16;

  /// 20dp — medium-large
  static const double mlg = 20;

  /// 24dp — large
  static const double xl = 24;

  /// 32dp — extra large
  static const double xxl = 32;

  /// 40dp — section spacing
  static const double xxxl = 40;

  /// 48dp — large section spacing
  static const double xxxxl = 48;

  /// 64dp — page section spacing
  static const double section = 64;

  // ════════════════════════════════════════════════════════════════════════════
  // SEMANTIC SPACING
  // ════════════════════════════════════════════════════════════════════════════

  /// Padding inside cards
  static const double cardPadding = 20;

  /// Margin around cards
  static const double cardMargin = 12;

  /// Screen edge padding
  static const double screenPadding = 20;

  /// Space between list items
  static const double listItemSpacing = 12;

  /// Space between sections
  static const double sectionSpacing = 32;

  /// Space between form fields
  static const double formFieldSpacing = 20;

  /// Icon to text spacing
  static const double iconTextSpacing = 8;

  /// Button content padding horizontal
  static const double buttonPaddingH = 24;

  /// Button content padding vertical
  static const double buttonPaddingV = 14;

  // ════════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS — LOCKED VALUES
  // ════════════════════════════════════════════════════════════════════════════

  /// Cards, containers — 20dp
  static const double radiusCard = 20;

  /// Buttons, inputs — 14dp
  static const double radiusButton = 14;

  /// Chips, tags — full round
  static const double radiusChip = 999;

  /// Small elements (icons, avatars) — 12dp
  static const double radiusSmall = 12;

  /// Modals, bottom sheets — 24dp
  static const double radiusModal = 24;

  /// Images, thumbnails — 16dp
  static const double radiusImage = 16;

  // ════════════════════════════════════════════════════════════════════════════
  // TOUCH TARGETS (Accessibility)
  // ════════════════════════════════════════════════════════════════════════════

  /// Minimum touch target (44dp for AA accessibility)
  static const double minTouchTarget = 44;

  /// Standard button height
  static const double buttonHeight = 52;

  /// Compact button height
  static const double buttonHeightCompact = 44;

  /// Icon button size
  static const double iconButtonSize = 44;

  /// Navigation item height
  static const double navItemHeight = 56;

  // ════════════════════════════════════════════════════════════════════════════
  // BREAKPOINTS
  // ════════════════════════════════════════════════════════════════════════════

  /// Mobile breakpoint
  static const double breakpointMobile = 600;

  /// Tablet breakpoint
  static const double breakpointTablet = 900;

  /// Desktop breakpoint
  static const double breakpointDesktop = 1200;

  /// Wide desktop breakpoint
  static const double breakpointWide = 1440;
}

/// Pre-built EdgeInsets for consistent padding
class AppInsets {
  AppInsets._();

  /// Screen padding
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.screenPadding);

  /// Screen padding horizontal only
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding);

  /// Card padding
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.cardPadding);

  /// Card padding compact
  static const EdgeInsets cardCompact = EdgeInsets.all(AppSpacing.lg);

  /// List item padding
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Button padding
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: AppSpacing.buttonPaddingH,
    vertical: AppSpacing.buttonPaddingV,
  );

  /// Input padding
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Section padding
  static const EdgeInsets section = EdgeInsets.symmetric(vertical: AppSpacing.sectionSpacing);
}

/// Pre-built BorderRadius for consistent corners
class AppRadius {
  AppRadius._();

  /// Card radius
  static BorderRadius get card => BorderRadius.circular(AppSpacing.radiusCard);

  /// Button radius
  static BorderRadius get button => BorderRadius.circular(AppSpacing.radiusButton);

  /// Chip radius (full round)
  static BorderRadius get chip => BorderRadius.circular(AppSpacing.radiusChip);

  /// Small radius
  static BorderRadius get small => BorderRadius.circular(AppSpacing.radiusSmall);

  /// Modal radius
  static BorderRadius get modal => BorderRadius.circular(AppSpacing.radiusModal);

  /// Image radius
  static BorderRadius get image => BorderRadius.circular(AppSpacing.radiusImage);

  /// Top only for bottom sheets
  static BorderRadius get modalTop => const BorderRadius.vertical(
    top: Radius.circular(AppSpacing.radiusModal),
  );
}

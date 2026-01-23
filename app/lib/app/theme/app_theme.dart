import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 🎨 THE SKINNING SHED — THEME SYSTEM (2025)
/// 
/// Design philosophy: Outdoors-inspired, tech-forward, premium.
/// Photos are the hero; UI is the clean, modern frame.
/// 
/// Typography: Inter throughout for clean, modern UI.
/// (Logo/brand marks can use organic fonts, but UI stays clean)
/// 
/// ✅ LOCKED — Do not modify without design review.
abstract final class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════════════════

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      textTheme: _textTheme,
      appBarTheme: _lightAppBarTheme,
      cardTheme: _lightCardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      inputDecorationTheme: _lightInputTheme,
      bottomNavigationBarTheme: _lightBottomNavTheme,
      navigationRailTheme: _lightNavRailTheme,
      chipTheme: _lightChipTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      snackBarTheme: _snackBarTheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
      floatingActionButtonTheme: _fabTheme,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DARK THEME (Future-ready)
  // ════════════════════════════════════════════════════════════════════════════

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      textTheme: _textThemeDark,
      appBarTheme: _darkAppBarTheme,
      cardTheme: _darkCardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonThemeDark,
      textButtonTheme: _textButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      inputDecorationTheme: _darkInputTheme,
      bottomNavigationBarTheme: _darkBottomNavTheme,
      navigationRailTheme: _darkNavRailTheme,
      chipTheme: _darkChipTheme,
      dialogTheme: _dialogThemeDark,
      bottomSheetTheme: _bottomSheetThemeDark,
      snackBarTheme: _snackBarThemeDark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textInverse,
        size: 24,
      ),
      floatingActionButtonTheme: _fabTheme,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // COLOR SCHEMES
  // ════════════════════════════════════════════════════════════════════════════

  static const _lightColorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.accent,
    onTertiary: AppColors.onAccent,
    tertiaryContainer: AppColors.accentContainer,
    onTertiaryContainer: AppColors.onAccentContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.surfaceAlt,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    outline: AppColors.border,
    outlineVariant: AppColors.borderStrong,
  );

  static const _darkColorScheme = ColorScheme.dark(
    primary: AppColors.primaryHover,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primary,
    onPrimaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.darkSurfaceAlt,
    onSecondaryContainer: AppColors.secondaryContainer,
    tertiary: AppColors.accentHover,
    onTertiary: AppColors.onAccent,
    tertiaryContainer: AppColors.darkSurfaceAlt,
    onTertiaryContainer: AppColors.accentContainer,
    surface: AppColors.darkSurface,
    onSurface: AppColors.textInverse,
    surfaceContainerHighest: AppColors.darkSurfaceAlt,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.darkSurfaceAlt,
    outline: AppColors.darkBorder,
    outlineVariant: AppColors.darkDivider,
  );

  // ════════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY — Inter for clean, modern UI
  // ════════════════════════════════════════════════════════════════════════════

  static TextTheme get _textTheme {
    return TextTheme(
      // Display — Large promotional/hero text
      displayLarge: GoogleFonts.inter(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.2,
        color: AppColors.textPrimary,
      ),

      // Headlines — Section headers
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.35,
        color: AppColors.textPrimary,
      ),

      // Titles — Component headers, card titles
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      ),

      // Body — Main content text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        color: AppColors.textSecondary,
      ),

      // Labels — Buttons, chips, captions
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.25,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.4,
        color: AppColors.textTertiary,
      ),
    );
  }

  static TextTheme get _textThemeDark {
    return _textTheme.apply(
      bodyColor: AppColors.textInverse,
      displayColor: AppColors.textInverse,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ════════════════════════════════════════════════════════════════════════════

  static AppBarTheme get _lightAppBarTheme {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
    );
  }

  static AppBarTheme get _darkAppBarTheme {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.textInverse,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textInverse,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textInverse,
        size: 24,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CARDS
  // ════════════════════════════════════════════════════════════════════════════

  static CardThemeData get _lightCardTheme {
    return CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static CardThemeData get _darkCardTheme {
    return CardThemeData(
      elevation: 0,
      color: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUTTONS
  // ════════════════════════════════════════════════════════════════════════════

  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textDisabled,
        padding: AppInsets.button,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static FilledButtonThemeData get _filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textDisabled,
        padding: AppInsets.button,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textDisabled,
        padding: AppInsets.button,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonThemeDark {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryHover,
        disabledForegroundColor: AppColors.textDisabled,
        padding: AppInsets.button,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
        side: const BorderSide(color: AppColors.primaryHover, width: 1.5),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static TextButtonThemeData get _textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData get _fabTheme {
    return FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // INPUTS
  // ════════════════════════════════════════════════════════════════════════════

  static InputDecorationTheme get _lightInputTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      contentPadding: AppInsets.input,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textTertiary,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.error,
      ),
    );
  }

  static InputDecorationTheme get _darkInputTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceAlt,
      border: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.primaryHover, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.5)),
      ),
      contentPadding: AppInsets.input,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textTertiary,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textInverse,
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.error,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHIPS
  // ════════════════════════════════════════════════════════════════════════════

  static ChipThemeData get _lightChipTheme {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.primaryContainer,
      disabledColor: AppColors.border,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.chip,
      ),
      side: BorderSide.none,
    );
  }

  static ChipThemeData get _darkChipTheme {
    return ChipThemeData(
      backgroundColor: AppColors.darkSurfaceAlt,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.darkBorder,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textInverse,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryHover,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.chip,
      ),
      side: BorderSide.none,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ════════════════════════════════════════════════════════════════════════════

  static BottomNavigationBarThemeData get _lightBottomNavTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static BottomNavigationBarThemeData get _darkBottomNavTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primaryHover,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static NavigationRailThemeData get _lightNavRailTheme {
    return NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 24),
      unselectedIconTheme: const IconThemeData(color: AppColors.textTertiary, size: 24),
      indicatorColor: AppColors.primaryContainer,
      selectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
    );
  }

  static NavigationRailThemeData get _darkNavRailTheme {
    return NavigationRailThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedIconTheme: const IconThemeData(color: AppColors.primaryHover, size: 24),
      unselectedIconTheme: const IconThemeData(color: AppColors.textTertiary, size: 24),
      indicatorColor: AppColors.primary,
      selectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryHover,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIALOGS & SHEETS
  // ════════════════════════════════════════════════════════════════════════════

  static DialogThemeData get _dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modal,
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    );
  }

  static DialogThemeData get _dialogThemeDark {
    return DialogThemeData(
      backgroundColor: AppColors.darkSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modal,
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textInverse,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textInverse,
      ),
    );
  }

  static BottomSheetThemeData get _bottomSheetTheme {
    return BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      modalElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalTop,
      ),
      dragHandleColor: AppColors.border,
      dragHandleSize: const Size(36, 4),
    );
  }

  static BottomSheetThemeData get _bottomSheetThemeDark {
    return BottomSheetThemeData(
      backgroundColor: AppColors.darkSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      modalElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalTop,
      ),
      dragHandleColor: AppColors.darkBorder,
      dragHandleSize: const Size(36, 4),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SNACKBAR
  // ════════════════════════════════════════════════════════════════════════════

  static SnackBarThemeData get _snackBarTheme {
    return SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textInverse,
      ),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.button,
      ),
    );
  }

  static SnackBarThemeData get _snackBarThemeDark {
    return SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceElevated,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textInverse,
      ),
      actionTextColor: AppColors.accentHover,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.button,
      ),
    );
  }
}

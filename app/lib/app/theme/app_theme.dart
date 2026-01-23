import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 🎨 2025 PREMIUM THEME
/// 
/// Modern, tech-forward design system using Inter font family.
/// Clean, tight typography with clear hierarchy.
class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════════════════

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: _appBarTheme,
    cardTheme: _cardThemeData,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    filledButtonTheme: _filledButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
    chipTheme: _chipTheme,
    dividerTheme: _dividerTheme,
    bottomNavigationBarTheme: _bottomNavTheme,
    navigationRailTheme: _navRailTheme,
    floatingActionButtonTheme: _fabTheme,
    dialogTheme: _dialogThemeData,
    bottomSheetTheme: _bottomSheetTheme,
    snackBarTheme: _snackBarTheme,
  );

  // ════════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME
  // ════════════════════════════════════════════════════════════════════════════

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.textInverse,
    primaryContainer: AppColors.primaryMuted,
    secondary: AppColors.accent,
    onSecondary: AppColors.textInverse,
    secondaryContainer: AppColors.accentMuted,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceHover,
    error: AppColors.error,
    onError: AppColors.textInverse,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSubtle,
  );

  // ════════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY (Inter - Modern, Clean)
  // ════════════════════════════════════════════════════════════════════════════

  static TextTheme get _textTheme {
    final base = GoogleFonts.interTextTheme();
    
    return base.copyWith(
      // Display - Hero text
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
        color: AppColors.textPrimary,
      ),

      // Headlines - Page titles
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
        color: AppColors.textPrimary,
      ),

      // Titles - Section headers
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: AppColors.textPrimary,
      ),

      // Body - Content text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
        color: AppColors.textTertiary,
      ),

      // Labels - UI elements
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
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

  // ════════════════════════════════════════════════════════════════════════════
  // COMPONENT THEMES
  // ════════════════════════════════════════════════════════════════════════════

  static AppBarTheme get _appBarTheme => AppBarTheme(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textPrimary,
      size: 22,
    ),
  );

  static CardThemeData get _cardThemeData => CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      side: const BorderSide(color: AppColors.borderSubtle),
    ),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textInverse,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      minimumSize: const Size(0, AppSpacing.buttonHeightMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );

  static OutlinedButtonThemeData get _outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      minimumSize: const Size(0, AppSpacing.buttonHeightMd),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textInverse,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      minimumSize: const Size(0, AppSpacing.buttonHeightMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textTertiary,
    ),
    labelStyle: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
  );

  static ChipThemeData get _chipTheme => ChipThemeData(
    backgroundColor: AppColors.surfaceHover,
    selectedColor: AppColors.primary.withOpacity(0.12),
    labelStyle: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    side: BorderSide.none,
  );

  static DividerThemeData get _dividerTheme => const DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: 1,
  );

  static BottomNavigationBarThemeData get _bottomNavTheme => BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textTertiary,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
    selectedLabelStyle: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  static NavigationRailThemeData get _navRailTheme => NavigationRailThemeData(
    backgroundColor: AppColors.surface,
    selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 22),
    unselectedIconTheme: const IconThemeData(color: AppColors.textTertiary, size: 22),
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
    indicatorColor: AppColors.primary.withOpacity(0.12),
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );

  static FloatingActionButtonThemeData get _fabTheme => FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textInverse,
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 0,
    highlightElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );

  static DialogThemeData get _dialogThemeData => DialogThemeData(
    backgroundColor: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
    ),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );

  static BottomSheetThemeData get _bottomSheetTheme => BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
  );

  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textInverse,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    behavior: SnackBarBehavior.floating,
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Premium outdoors-themed design system for The Skinning Shed.
/// 
/// Design philosophy: "Modern lodge" - calm, premium, timeless.
/// No neon/futuristic accents. Photos are the hero; UI is the frame.
class AppTheme {
  AppTheme._();

  /// Light theme - Primary theme for the app
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      textTheme: _textTheme,
      appBarTheme: _lightAppBarTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      bottomNavigationBarTheme: _lightBottomNavTheme,
      navigationRailTheme: _lightNavigationRailTheme,
      scaffoldBackgroundColor: AppColors.bone,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
    );
  }

  /// Dark theme - Alternative for low-light conditions
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      textTheme: _textTheme.apply(
        bodyColor: AppColors.bone,
        displayColor: AppColors.bone,
      ),
      appBarTheme: _darkAppBarTheme,
      cardTheme: _cardThemeDark,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      inputDecorationTheme: _inputDecorationThemeDark,
      bottomNavigationBarTheme: _darkBottomNavTheme,
      navigationRailTheme: _darkNavigationRailTheme,
      scaffoldBackgroundColor: AppColors.charcoalDark,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
    );
  }

  // ============ COLOR SCHEMES ============

  static const _lightColorScheme = ColorScheme.light(
    primary: AppColors.forest,
    onPrimary: AppColors.bone,
    primaryContainer: AppColors.forestLight,
    onPrimaryContainer: AppColors.charcoal,
    secondary: AppColors.olive,
    onSecondary: AppColors.bone,
    secondaryContainer: AppColors.oliveLight,
    onSecondaryContainer: AppColors.charcoal,
    tertiary: AppColors.rust,
    onTertiary: AppColors.bone,
    surface: AppColors.bone,
    onSurface: AppColors.charcoal,
    surfaceContainerHighest: AppColors.boneLight,
    error: AppColors.error,
    onError: AppColors.bone,
    outline: AppColors.borderLight,
  );

  static const _darkColorScheme = ColorScheme.dark(
    primary: AppColors.forestLight,
    onPrimary: AppColors.charcoalDark,
    primaryContainer: AppColors.forest,
    onPrimaryContainer: AppColors.bone,
    secondary: AppColors.olive,
    onSecondary: AppColors.charcoalDark,
    secondaryContainer: AppColors.oliveDark,
    onSecondaryContainer: AppColors.bone,
    tertiary: AppColors.rustLight,
    onTertiary: AppColors.charcoalDark,
    surface: AppColors.charcoal,
    onSurface: AppColors.bone,
    surfaceContainerHighest: AppColors.charcoalLight,
    error: AppColors.errorLight,
    onError: AppColors.charcoalDark,
    outline: AppColors.borderDark,
  );

  // ============ TEXT THEME ============

  static TextTheme get _textTheme {
    return GoogleFonts.sourceSerif4TextTheme().copyWith(
      // Display styles
      displayLarge: GoogleFonts.sourceSerif4(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: AppColors.charcoal,
      ),
      displayMedium: GoogleFonts.sourceSerif4(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.charcoal,
      ),
      displaySmall: GoogleFonts.sourceSerif4(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.charcoal,
      ),
      
      // Headlines
      headlineLarge: GoogleFonts.sourceSerif4(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      headlineMedium: GoogleFonts.sourceSerif4(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      headlineSmall: GoogleFonts.sourceSerif4(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.charcoal,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.charcoal,
      ),
      
      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.charcoal,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.charcoal,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.charcoalLight,
      ),
      
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.charcoal,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.charcoal,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.charcoalLight,
      ),
    );
  }

  // ============ COMPONENT THEMES ============

  static AppBarTheme get _lightAppBarTheme {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: AppColors.bone,
      foregroundColor: AppColors.charcoal,
      titleTextStyle: GoogleFonts.sourceSerif4(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
      iconTheme: const IconThemeData(color: AppColors.charcoal),
    );
  }

  static AppBarTheme get _darkAppBarTheme {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: AppColors.charcoalDark,
      foregroundColor: AppColors.bone,
      titleTextStyle: GoogleFonts.sourceSerif4(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.bone,
      ),
      iconTheme: const IconThemeData(color: AppColors.bone),
    );
  }

  static CardThemeData get _cardTheme {
    return CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  static CardThemeData get _cardThemeDark {
    return CardThemeData(
      elevation: 0,
      color: AppColors.charcoal,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.bone,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: AppColors.forest, width: 1.5),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.forest, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static InputDecorationTheme get _inputDecorationThemeDark {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.charcoal,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.forestLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorLight),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static BottomNavigationBarThemeData get _lightBottomNavTheme {
    return const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.forest,
      unselectedItemColor: AppColors.charcoalLight,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showUnselectedLabels: true,
    );
  }

  static BottomNavigationBarThemeData get _darkBottomNavTheme {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.charcoalDark,
      selectedItemColor: AppColors.forestLight,
      unselectedItemColor: AppColors.boneLight,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showUnselectedLabels: true,
    );
  }

  static NavigationRailThemeData get _lightNavigationRailTheme {
    return const NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: IconThemeData(color: AppColors.forest),
      unselectedIconTheme: IconThemeData(color: AppColors.charcoalLight),
      indicatorColor: AppColors.forestLight,
    );
  }

  static NavigationRailThemeData get _darkNavigationRailTheme {
    return const NavigationRailThemeData(
      backgroundColor: AppColors.charcoalDark,
      selectedIconTheme: IconThemeData(color: AppColors.forestLight),
      unselectedIconTheme: IconThemeData(color: AppColors.boneLight),
      indicatorColor: AppColors.forest,
    );
  }
}

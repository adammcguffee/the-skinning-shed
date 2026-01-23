import 'package:flutter/material.dart';

/// Color palette for The Skinning Shed.
/// 
/// "Modern Lodge" theme - forest/charcoal/bone with muted earth accents.
/// Calm, premium, timeless. No neon/futuristic colors.
class AppColors {
  AppColors._();

  // ============ PRIMARY PALETTE ============
  
  /// Deep forest green - primary brand color
  static const Color forest = Color(0xFF2D4A3E);
  
  /// Lighter forest for containers/accents
  static const Color forestLight = Color(0xFF4A7A68);
  
  /// Dark forest for emphasis
  static const Color forestDark = Color(0xFF1A2D26);

  // ============ NEUTRAL PALETTE ============
  
  /// Rich charcoal - primary text color
  static const Color charcoal = Color(0xFF2C3E38);
  
  /// Lighter charcoal for secondary text
  static const Color charcoalLight = Color(0xFF5D6E68);
  
  /// Dark charcoal for dark mode backgrounds
  static const Color charcoalDark = Color(0xFF1A2420);

  /// Warm bone/cream - primary background
  static const Color bone = Color(0xFFF8F6F3);
  
  /// Lighter bone for elevated surfaces
  static const Color boneLight = Color(0xFFEDE9E4);

  // ============ ACCENT PALETTE ============
  
  /// Muted olive - secondary accent
  static const Color olive = Color(0xFF6B7B4E);
  
  /// Light olive for containers
  static const Color oliveLight = Color(0xFF8FA66A);
  
  /// Dark olive for emphasis
  static const Color oliveDark = Color(0xFF4A5536);

  /// Muted rust/terracotta - tertiary accent
  static const Color rust = Color(0xFFA67B5B);
  
  /// Light rust for highlights
  static const Color rustLight = Color(0xFFC9A68A);
  
  /// Dark rust for emphasis
  static const Color rustDark = Color(0xFF7A5A42);

  /// Warm tan for subtle accents
  static const Color tan = Color(0xFFD4C4A8);
  
  /// Light tan
  static const Color tanLight = Color(0xFFE8DCC8);

  // ============ SEMANTIC COLORS ============
  
  /// Success - harvested/completed
  static const Color success = Color(0xFF4A7A68);
  
  /// Warning - attention needed
  static const Color warning = Color(0xFFB8860B);
  
  /// Error - problems
  static const Color error = Color(0xFFB44040);
  
  /// Error light for dark mode
  static const Color errorLight = Color(0xFFD46A6A);

  // ============ BORDERS & DIVIDERS ============
  
  /// Light border color
  static const Color borderLight = Color(0xFFE0DCD6);
  
  /// Dark border color
  static const Color borderDark = Color(0xFF3D4D46);

  // ============ SPECIES ACCENT COLORS ============
  // Subtle colors to differentiate species categories
  
  /// Deer - warm brown tone
  static const Color speciesDeer = Color(0xFF8B7355);
  
  /// Turkey - slate/gray tone  
  static const Color speciesTurkey = Color(0xFF5D6B70);
  
  /// Bass - blue-green water tone
  static const Color speciesBass = Color(0xFF4A7080);
  
  /// Other game - earthy tone
  static const Color speciesOtherGame = Color(0xFF6B5B4E);
  
  /// Other fishing - cool water tone
  static const Color speciesOtherFishing = Color(0xFF5A7A8A);

  // ============ STATUS COLORS ============
  
  /// Active listing
  static const Color statusActive = Color(0xFF4A7A68);
  
  /// Pending/processing
  static const Color statusPending = Color(0xFFB8860B);
  
  /// Expired listing
  static const Color statusExpired = Color(0xFF8B7355);
  
  /// Removed/banned
  static const Color statusRemoved = Color(0xFFB44040);
}

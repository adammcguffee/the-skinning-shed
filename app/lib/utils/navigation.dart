import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 🧭 GLOBAL NAVIGATION UTILITIES
/// 
/// Centralized navigation helpers for consistent behavior across the app.

/// Navigate to the home/feed screen from anywhere.
/// 
/// This is the canonical way to go "home" in the app.
/// Always use this instead of hardcoding routes like context.go('/feed').
void goHome(BuildContext context) {
  // '/' is the main feed/home route as defined in router.dart
  context.go('/');
}

/// Navigate home and close any modals first.
/// 
/// Use this when navigating home from a modal/bottom sheet context.
void goHomeClosingModals(BuildContext context) {
  // Pop all routes until we reach the root navigator, then go home
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  context.go('/');
}

/// Extension for convenient navigation from BuildContext.
extension NavigationExtension on BuildContext {
  /// Navigate to home/feed screen.
  void goHome() => go('/');
  
  /// Navigate to home, closing any modals first.
  void goHomeClosingModals() {
    Navigator.of(this, rootNavigator: true).popUntil((route) => route.isFirst);
    go('/');
  }
}

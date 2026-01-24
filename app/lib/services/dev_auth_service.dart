import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/dev_flags.dart';

/// Dev-only auth bypass service.
///
/// This allows developers to enter the app without a real Supabase session
/// when running with `--dart-define=DEV_BYPASS_AUTH=true` in debug mode.
///
/// The bypass state is stored in SharedPreferences so it persists across
/// hot reloads but can be cleared by "Sign Out (Dev Mode)" in settings.
class DevAuthService {
  DevAuthService._();
  
  static const String _key = 'dev_bypass_logged_in';
  
  /// Check if dev auth bypass is currently active.
  /// Returns false if the feature is disabled or not in dev bypass state.
  static Future<bool> isDevBypassActive() async {
    if (!DevFlags.isDevBypassAuthEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
  
  /// Activate dev auth bypass.
  /// Only works if [DevFlags.isDevBypassAuthEnabled] is true.
  static Future<bool> activateDevBypass() async {
    if (!DevFlags.isDevBypassAuthEnabled) {
      debugPrint('[DevAuth] Cannot activate: dev bypass not enabled');
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    debugPrint('[DevAuth] Dev bypass activated');
    return true;
  }
  
  /// Deactivate dev auth bypass (sign out in dev mode).
  static Future<void> deactivateDevBypass() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('[DevAuth] Dev bypass deactivated');
  }
  
  /// Clear dev bypass state. Called on real sign out too.
  static Future<void> clearDevBypassState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Provider for checking if dev bypass is active.
/// This is a FutureProvider that checks SharedPreferences.
final devBypassActiveProvider = FutureProvider<bool>((ref) async {
  return DevAuthService.isDevBypassActive();
});

/// Notifier for dev auth bypass state changes.
class DevAuthNotifier extends ChangeNotifier {
  bool _isActive = false;
  bool _isChecked = false;
  
  bool get isActive => _isActive;
  bool get isChecked => _isChecked;
  
  /// Check and update the dev bypass state.
  Future<void> checkState() async {
    _isActive = await DevAuthService.isDevBypassActive();
    _isChecked = true;
    notifyListeners();
  }
  
  /// Activate dev bypass and update state.
  Future<bool> activate() async {
    final success = await DevAuthService.activateDevBypass();
    if (success) {
      _isActive = true;
      notifyListeners();
    }
    return success;
  }
  
  /// Deactivate dev bypass and update state.
  Future<void> deactivate() async {
    await DevAuthService.deactivateDevBypass();
    _isActive = false;
    notifyListeners();
  }
}

/// Provider for dev auth notifier.
final devAuthNotifierProvider = ChangeNotifierProvider<DevAuthNotifier>((ref) {
  final notifier = DevAuthNotifier();
  // Check state on creation
  notifier.checkState();
  return notifier;
});

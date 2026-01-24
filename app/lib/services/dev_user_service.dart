import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/dev_flags.dart';
import 'supabase_service.dart';

/// Service for managing a "dev user" context when using DEV_BYPASS_AUTH.
///
/// In dev mode without a real Supabase session, some screens (like Trophy Wall)
/// need a user ID to display. This service allows selecting a profile to preview.
class DevUserService {
  DevUserService._();
  
  static const String _selectedUserIdKey = 'dev_selected_user_id';
  static const String _selectedUsernameKey = 'dev_selected_username';
  
  /// Get the currently selected dev user ID.
  static Future<String?> getSelectedUserId() async {
    if (!DevFlags.isDevBypassAuthEnabled) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedUserIdKey);
  }
  
  /// Get the currently selected dev username (for display).
  static Future<String?> getSelectedUsername() async {
    if (!DevFlags.isDevBypassAuthEnabled) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedUsernameKey);
  }
  
  /// Set the selected dev user.
  static Future<void> setSelectedUser(String userId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedUserIdKey, userId);
    await prefs.setString(_selectedUsernameKey, username);
    debugPrint('[DevUser] Selected user: $username ($userId)');
  }
  
  /// Clear the selected dev user.
  static Future<void> clearSelectedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedUserIdKey);
    await prefs.remove(_selectedUsernameKey);
    debugPrint('[DevUser] Cleared selected user');
  }
  
  /// Fetch available public profiles for selection.
  static Future<List<DevUserProfile>> fetchAvailableProfiles() async {
    final client = SupabaseService.instance.client;
    if (client == null) return [];
    
    try {
      // Fetch profiles that have public trophies (active users)
      final response = await client
          .from('profiles')
          .select('id, username, display_name')
          .order('username')
          .limit(50);
      
      return (response as List).map((row) => DevUserProfile(
        id: row['id'] as String,
        username: row['username'] as String? ?? 'Unknown',
        displayName: row['display_name'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('[DevUser] Error fetching profiles: $e');
      return [];
    }
  }
}

/// Simple profile model for dev user selection.
class DevUserProfile {
  const DevUserProfile({
    required this.id,
    required this.username,
    this.displayName,
  });
  
  final String id;
  final String username;
  final String? displayName;
  
  String get displayLabel => displayName ?? username;
}

/// Notifier for dev user selection state.
class DevUserNotifier extends ChangeNotifier {
  String? _selectedUserId;
  String? _selectedUsername;
  bool _isLoaded = false;
  List<DevUserProfile> _availableProfiles = [];
  bool _isLoadingProfiles = false;
  
  String? get selectedUserId => _selectedUserId;
  String? get selectedUsername => _selectedUsername;
  bool get isLoaded => _isLoaded;
  bool get hasSelectedUser => _selectedUserId != null;
  List<DevUserProfile> get availableProfiles => _availableProfiles;
  bool get isLoadingProfiles => _isLoadingProfiles;
  
  /// Load the saved dev user selection.
  Future<void> load() async {
    _selectedUserId = await DevUserService.getSelectedUserId();
    _selectedUsername = await DevUserService.getSelectedUsername();
    _isLoaded = true;
    notifyListeners();
  }
  
  /// Select a dev user.
  Future<void> selectUser(String userId, String username) async {
    await DevUserService.setSelectedUser(userId, username);
    _selectedUserId = userId;
    _selectedUsername = username;
    notifyListeners();
  }
  
  /// Clear the selection.
  Future<void> clearSelection() async {
    await DevUserService.clearSelectedUser();
    _selectedUserId = null;
    _selectedUsername = null;
    notifyListeners();
  }
  
  /// Fetch available profiles for selection.
  Future<void> loadAvailableProfiles() async {
    if (_isLoadingProfiles) return;
    _isLoadingProfiles = true;
    notifyListeners();
    
    _availableProfiles = await DevUserService.fetchAvailableProfiles();
    _isLoadingProfiles = false;
    notifyListeners();
  }
}

/// Provider for dev user notifier.
final devUserNotifierProvider = ChangeNotifierProvider<DevUserNotifier>((ref) {
  final notifier = DevUserNotifier();
  // Load on creation if dev bypass is enabled
  if (DevFlags.isDevBypassAuthEnabled) {
    notifier.load();
  }
  return notifier;
});

/// Provider for the effective user ID to use.
/// Returns:
/// - Real user ID if logged in with Supabase
/// - Dev selected user ID if in dev bypass mode
/// - null if neither
final effectiveUserIdProvider = Provider<String?>((ref) {
  // First check for real Supabase user
  final supabaseUser = ref.watch(currentUserProvider);
  if (supabaseUser != null) {
    return supabaseUser.id;
  }
  
  // Then check for dev user selection
  if (DevFlags.isDevBypassAuthEnabled) {
    final devUser = ref.watch(devUserNotifierProvider);
    return devUser.selectedUserId;
  }
  
  return null;
});

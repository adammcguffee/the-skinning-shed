import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

/// Service for prefetching and caching the user's local county at app startup.
/// 
/// This runs in the background after auth to ensure Weather page opens instantly.
/// 
/// Features:
/// - Throttles: only runs if last update > 12 hours old
/// - Handles denied permissions with 7-day cooldown (no nagging)
/// - Stores only county identity (state_code, county_name, fips), never raw coords
/// - Non-blocking: runs in background, doesn't delay navigation
class LocationPrefetchService {
  LocationPrefetchService._();
  
  static LocationPrefetchService? _instance;
  static LocationPrefetchService get instance => _instance ??= LocationPrefetchService._();
  
  // SharedPreferences keys
  static const _keyLocalStateCode = 'local_county_state_code';
  static const _keyLocalStateName = 'local_county_state_name';
  static const _keyLocalCountyName = 'local_county_name';
  static const _keyLocalCountyFips = 'local_county_fips';
  static const _keyLocalUpdatedAt = 'local_county_updated_at';
  static const _keyLocationDeniedAt = 'location_permission_denied_at';
  
  // Throttle durations
  static const Duration _updateThrottle = Duration(hours: 12);
  static const Duration _deniedCooldown = Duration(days: 7);
  
  bool _isPrefetching = false;
  
  /// Get the cached local county selection.
  /// Returns null if not cached or expired.
  Future<CountySelection?> getLocalCountySelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateCode = prefs.getString(_keyLocalStateCode);
      final stateName = prefs.getString(_keyLocalStateName);
      final countyName = prefs.getString(_keyLocalCountyName);
      final countyFips = prefs.getString(_keyLocalCountyFips);
      
      if (stateCode == null || stateName == null || countyName == null) {
        return null;
      }
      
      return CountySelection(
        stateCode: stateCode,
        stateName: stateName,
        countyName: countyName,
        countyFips: countyFips,
      );
    } catch (e) {
      debugPrint('[LocationPrefetch] Error getting cached local county: $e');
      return null;
    }
  }
  
  /// Check if the cached local county is still fresh (within throttle window).
  Future<bool> _isCacheFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedAtMs = prefs.getInt(_keyLocalUpdatedAt);
      if (updatedAtMs == null) return false;
      
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
      final age = DateTime.now().difference(updatedAt);
      return age < _updateThrottle;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if we're in the denied cooldown period.
  Future<bool> _isInDeniedCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deniedAtMs = prefs.getInt(_keyLocationDeniedAt);
      if (deniedAtMs == null) return false;
      
      final deniedAt = DateTime.fromMillisecondsSinceEpoch(deniedAtMs);
      final age = DateTime.now().difference(deniedAt);
      return age < _deniedCooldown;
    } catch (e) {
      return false;
    }
  }
  
  /// Record that permission was denied.
  Future<void> _recordPermissionDenied() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLocationDeniedAt, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[LocationPrefetch] Recorded permission denied, cooldown started');
    } catch (e) {
      debugPrint('[LocationPrefetch] Error recording denied: $e');
    }
  }
  
  /// Clear the denied cooldown (call after user manually grants permission).
  Future<void> clearDeniedCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLocationDeniedAt);
    } catch (e) {
      debugPrint('[LocationPrefetch] Error clearing denied cooldown: $e');
    }
  }
  
  /// Store the local county selection.
  Future<void> _storeLocalCounty(CountySelection selection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocalStateCode, selection.stateCode);
      await prefs.setString(_keyLocalStateName, selection.stateName);
      await prefs.setString(_keyLocalCountyName, selection.countyName);
      if (selection.countyFips != null) {
        await prefs.setString(_keyLocalCountyFips, selection.countyFips!);
      } else {
        await prefs.remove(_keyLocalCountyFips);
      }
      await prefs.setInt(_keyLocalUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[LocationPrefetch] Stored local county: ${selection.label}');
    } catch (e) {
      debugPrint('[LocationPrefetch] Error storing local county: $e');
    }
  }
  
  /// Prefetch local county if needed.
  /// 
  /// This should be called once after auth succeeds. It runs in background
  /// and doesn't block navigation.
  /// 
  /// Returns the detected selection, or null if:
  /// - Cache is fresh (no need to update)
  /// - Permission denied (in cooldown)
  /// - Location services unavailable
  /// - Detection failed
  Future<CountySelection?> prefetchLocalCountyIfNeeded({bool force = false}) async {
    // Prevent concurrent prefetches
    if (_isPrefetching) {
      debugPrint('[LocationPrefetch] Already prefetching, skipping');
      return null;
    }
    
    _isPrefetching = true;
    
    try {
      // Check throttle (unless forced)
      if (!force && await _isCacheFresh()) {
        debugPrint('[LocationPrefetch] Cache is fresh, skipping prefetch');
        return await getLocalCountySelection();
      }
      
      // Check denied cooldown (unless forced)
      if (!force && await _isInDeniedCooldown()) {
        debugPrint('[LocationPrefetch] In denied cooldown, skipping');
        return await getLocalCountySelection();
      }
      
      // Check if location services are available
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationPrefetch] Location services disabled');
        return await getLocalCountySelection();
      }
      
      // Check permission status
      var permission = await Geolocator.checkPermission();
      
      // Only request if currently denied (not deniedForever)
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      // Handle denied
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _recordPermissionDenied();
        return await getLocalCountySelection();
      }
      
      // Got permission - get location
      debugPrint('[LocationPrefetch] Detecting location...');
      final selection = await LocationService.instance.tryGetLocalCountySelection();
      
      if (selection != null) {
        await _storeLocalCounty(selection);
        // Also update last viewed so Weather page uses it
        await LocationService.instance.setLastViewedSelection(selection);
        return selection;
      }
      
      debugPrint('[LocationPrefetch] Detection returned null');
      return await getLocalCountySelection();
      
    } catch (e) {
      debugPrint('[LocationPrefetch] Error during prefetch: $e');
      return await getLocalCountySelection();
    } finally {
      _isPrefetching = false;
    }
  }
  
  /// Get timestamp of last successful prefetch.
  Future<DateTime?> getLastPrefetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedAtMs = prefs.getInt(_keyLocalUpdatedAt);
      if (updatedAtMs == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    } catch (e) {
      return null;
    }
  }
  
  /// Clear all cached local county data.
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLocalStateCode);
      await prefs.remove(_keyLocalStateName);
      await prefs.remove(_keyLocalCountyName);
      await prefs.remove(_keyLocalCountyFips);
      await prefs.remove(_keyLocalUpdatedAt);
      debugPrint('[LocationPrefetch] Cleared cache');
    } catch (e) {
      debugPrint('[LocationPrefetch] Error clearing cache: $e');
    }
  }
}

/// Provider for LocationPrefetchService
final locationPrefetchServiceProvider = Provider<LocationPrefetchService>((ref) {
  return LocationPrefetchService.instance;
});

/// Provider for prefetch state
class LocationPrefetchState {
  const LocationPrefetchState({
    this.isRunning = false,
    this.lastPrefetchTime,
    this.cachedSelection,
  });
  
  final bool isRunning;
  final DateTime? lastPrefetchTime;
  final CountySelection? cachedSelection;
  
  LocationPrefetchState copyWith({
    bool? isRunning,
    DateTime? lastPrefetchTime,
    CountySelection? cachedSelection,
  }) {
    return LocationPrefetchState(
      isRunning: isRunning ?? this.isRunning,
      lastPrefetchTime: lastPrefetchTime ?? this.lastPrefetchTime,
      cachedSelection: cachedSelection ?? this.cachedSelection,
    );
  }
}

class LocationPrefetchNotifier extends StateNotifier<LocationPrefetchState> {
  LocationPrefetchNotifier() : super(const LocationPrefetchState());
  
  final _service = LocationPrefetchService.instance;
  
  /// Initialize and load cached data.
  Future<void> initialize() async {
    final cached = await _service.getLocalCountySelection();
    final lastTime = await _service.getLastPrefetchTime();
    state = state.copyWith(
      cachedSelection: cached,
      lastPrefetchTime: lastTime,
    );
  }
  
  /// Run prefetch in background.
  Future<void> prefetch({bool force = false}) async {
    if (state.isRunning) return;
    
    state = state.copyWith(isRunning: true);
    
    try {
      final selection = await _service.prefetchLocalCountyIfNeeded(force: force);
      final lastTime = await _service.getLastPrefetchTime();
      state = state.copyWith(
        cachedSelection: selection,
        lastPrefetchTime: lastTime,
        isRunning: false,
      );
    } catch (e) {
      state = state.copyWith(isRunning: false);
    }
  }
}

final locationPrefetchNotifierProvider = 
    StateNotifierProvider<LocationPrefetchNotifier, LocationPrefetchState>((ref) {
  return LocationPrefetchNotifier();
});

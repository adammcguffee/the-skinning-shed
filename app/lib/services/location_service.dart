import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/county_centroids.dart';
import '../data/us_states.dart';
import '../utils/county_locator.dart';

/// Selected county with all necessary identifiers.
class CountySelection {
  const CountySelection({
    required this.stateCode,
    required this.stateName,
    required this.countyName,
    this.countyFips,
  });
  
  final String stateCode;
  final String stateName;
  final String countyName;
  final String? countyFips;
  
  /// Build display label (e.g., "Jefferson Co, AL").
  String get label {
    // Shorten "County" to "Co" for compact display
    String shortName = countyName;
    if (shortName.endsWith(' County')) {
      shortName = '${shortName.substring(0, shortName.length - 6)}Co';
    } else if (shortName.endsWith(' Parish')) {
      shortName = '${shortName.substring(0, shortName.length - 6)}Par';
    }
    return '$shortName, $stateCode';
  }
  
  /// Full display name.
  String get fullName => '$countyName, $stateName';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountySelection &&
          stateCode == other.stateCode &&
          countyName == other.countyName;
  
  @override
  int get hashCode => Object.hash(stateCode, countyName);
  
  @override
  String toString() => 'CountySelection($stateCode, $countyName)';
  
  Map<String, dynamic> toJson() => {
    'stateCode': stateCode,
    'stateName': stateName,
    'countyName': countyName,
    'countyFips': countyFips,
  };
  
  factory CountySelection.fromJson(Map<String, dynamic> json) {
    return CountySelection(
      stateCode: json['stateCode'] as String,
      stateName: json['stateName'] as String,
      countyName: json['countyName'] as String,
      countyFips: json['countyFips'] as String?,
    );
  }
}

/// Tracks how a location was selected.
enum SelectionSource {
  /// Auto-detected from device geolocation.
  local,
  /// Loaded from SharedPreferences on startup.
  lastViewed,
  /// User manually selected from dropdowns.
  manual,
  /// User tapped a favorite chip.
  favorite,
}

/// Location service for weather screen.
/// 
/// Handles:
/// - Last viewed county persistence (SharedPreferences)
/// - Device geolocation with permission handling
/// - Finding nearest county from coordinates
/// 
/// Privacy-safe: Never stores precise coordinates, only county identifiers.
class LocationService {
  LocationService._();
  
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  
  // SharedPreferences keys
  static const _keyStateCode = 'weather_last_state_code';
  static const _keyStateName = 'weather_last_state_name';
  static const _keyCountyName = 'weather_last_county_name';
  static const _keyCountyFips = 'weather_last_county_fips';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LAST VIEWED PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get last viewed county selection from SharedPreferences.
  /// Returns null if not previously stored.
  Future<CountySelection?> getLastViewedSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateCode = prefs.getString(_keyStateCode);
      final stateName = prefs.getString(_keyStateName);
      final countyName = prefs.getString(_keyCountyName);
      final countyFips = prefs.getString(_keyCountyFips);
      
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
      debugPrint('Error loading last viewed selection: $e');
      return null;
    }
  }
  
  /// Save county selection to SharedPreferences for fast startup.
  Future<void> setLastViewedSelection(CountySelection selection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStateCode, selection.stateCode);
      await prefs.setString(_keyStateName, selection.stateName);
      await prefs.setString(_keyCountyName, selection.countyName);
      if (selection.countyFips != null) {
        await prefs.setString(_keyCountyFips, selection.countyFips!);
      } else {
        await prefs.remove(_keyCountyFips);
      }
    } catch (e) {
      debugPrint('Error saving last viewed selection: $e');
    }
  }
  
  /// Clear last viewed selection.
  Future<void> clearLastViewedSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStateCode);
      await prefs.remove(_keyStateName);
      await prefs.remove(_keyCountyName);
      await prefs.remove(_keyCountyFips);
    } catch (e) {
      debugPrint('Error clearing last viewed selection: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GEOLOCATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Check if location services are available and enabled.
  Future<bool> isLocationServiceAvailable() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }
  
  /// Check current permission status without requesting.
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return LocationPermission.denied;
    }
  }
  
  /// Request location permission if needed.
  /// Returns the resulting permission status.
  Future<LocationPermission> requestPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return await Geolocator.requestPermission();
      }
      return permission;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }
  
  /// Try to get local county selection from device location.
  /// 
  /// Flow:
  /// 1. Request permission if needed
  /// 2. Get current position
  /// 3. Find nearest county centroid
  /// 4. Return selection (or null if any step fails)
  /// 
  /// Privacy-safe: coordinates are only used transiently to find county,
  /// never stored anywhere.
  Future<CountySelection?> tryGetLocalCountySelection() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return null;
      }
      
      // Check/request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied: $permission');
        return null;
      }
      
      // Get current position with reasonable timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Low accuracy is fine for county
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      // Find nearest county
      final county = await CountyLocator.findNearestCountyFromAll(
        position.latitude,
        position.longitude,
      );
      
      if (county == null) {
        debugPrint('No county found for coordinates');
        return null;
      }
      
      // Convert to CountySelection
      final stateName = USStates.byCode(county.stateCode)?.name ?? county.stateCode;
      
      return CountySelection(
        stateCode: county.stateCode,
        stateName: stateName,
        countyName: county.name,
        countyFips: county.fips,
      );
    } catch (e) {
      debugPrint('Error getting local county: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create CountySelection from CountyData.
  CountySelection? selectionFromCountyData(CountyData? county) {
    if (county == null) return null;
    final stateName = USStates.byCode(county.stateCode)?.name ?? county.stateCode;
    return CountySelection(
      stateCode: county.stateCode,
      stateName: stateName,
      countyName: county.name,
      countyFips: county.fips,
    );
  }
  
  /// Create CountySelection from state code and county name.
  Future<CountySelection?> selectionFromStateAndCounty(
    String stateCode,
    String countyName,
  ) async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    final county = centroids.lookupByStateCounty(stateCode, countyName);
    if (county == null) {
      // Fall back to creating selection without FIPS
      final stateName = USStates.byCode(stateCode)?.name;
      if (stateName == null) return null;
      return CountySelection(
        stateCode: stateCode,
        stateName: stateName,
        countyName: countyName,
      );
    }
    
    return selectionFromCountyData(county);
  }
}

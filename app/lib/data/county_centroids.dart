import 'dart:convert';
import 'package:flutter/services.dart';

/// County centroid data loaded from Census Gazetteer JSON.
/// 
/// Provides lat/lon for any US county (3200+ counties) for weather lookup.
/// Uses FIPS code (5-digit GEOID) as canonical identifier.
/// 
/// Privacy-safe: uses county centroid, not GPS coordinates.
class CountyCentroids {
  CountyCentroids._();
  
  static CountyCentroids? _instance;
  static CountyCentroids get instance => _instance ??= CountyCentroids._();
  
  bool _loaded = false;
  Map<String, CountyData> _counties = {};
  Map<String, String> _lookup = {}; // "STATE:normalized_name" -> fips
  
  /// Initialize and load county data from asset.
  /// Call this once at app startup or lazily on first use.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    
    try {
      final jsonStr = await rootBundle.loadString('assets/data/county_centroids.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      
      final counties = data['counties'] as Map<String, dynamic>? ?? {};
      final lookup = data['lookup'] as Map<String, dynamic>? ?? {};
      
      _counties = counties.map((fips, value) {
        final v = value as Map<String, dynamic>;
        return MapEntry(fips, CountyData(
          fips: fips,
          stateCode: v['state'] as String? ?? '',
          name: v['name'] as String? ?? '',
          normalizedName: v['normalized'] as String? ?? '',
          lat: (v['lat'] as num?)?.toDouble() ?? 0,
          lon: (v['lon'] as num?)?.toDouble() ?? 0,
        ));
      });
      
      _lookup = lookup.map((k, v) => MapEntry(k, v as String));
      
      _loaded = true;
    } catch (e) {
      print('Error loading county centroids: $e');
      // Continue with empty data - graceful degradation
    }
  }
  
  /// Check if data is loaded.
  bool get isLoaded => _loaded;
  
  /// Total number of counties loaded.
  int get countyCount => _counties.length;
  
  /// Look up county by FIPS code (5-digit GEOID).
  /// This is the preferred lookup method.
  CountyData? lookupByFips(String fips) {
    if (!_loaded) return null;
    // Ensure 5-digit padding
    final normalizedFips = fips.padLeft(5, '0');
    return _counties[normalizedFips];
  }
  
  /// Look up county by state code and name.
  /// Handles "County/Parish/Borough" suffix normalization.
  /// Falls back to partial matching if exact match not found.
  CountyData? lookupByStateCounty(String stateCode, String countyName) {
    if (!_loaded) return null;
    
    final normalizedName = _normalizeCountyName(countyName).toLowerCase();
    final key = '${stateCode.toUpperCase()}:$normalizedName';
    
    // Try exact lookup first
    final fips = _lookup[key];
    if (fips != null) {
      return _counties[fips];
    }
    
    // Try with common suffixes added/removed
    final variants = _generateNameVariants(normalizedName);
    for (final variant in variants) {
      final variantKey = '${stateCode.toUpperCase()}:$variant';
      final variantFips = _lookup[variantKey];
      if (variantFips != null) {
        return _counties[variantFips];
      }
    }
    
    // Fallback: search through all counties in state
    final upperState = stateCode.toUpperCase();
    for (final county in _counties.values) {
      if (county.stateCode == upperState) {
        if (county.normalizedName == normalizedName ||
            county.name.toLowerCase() == countyName.toLowerCase()) {
          return county;
        }
      }
    }
    
    return null;
  }
  
  /// Get coordinates for a county by FIPS.
  ({double lat, double lon})? getCoordinatesByFips(String fips) {
    final county = lookupByFips(fips);
    if (county == null) return null;
    return (lat: county.lat, lon: county.lon);
  }
  
  /// Get coordinates for a county by state/name.
  /// Legacy method - prefer FIPS lookup.
  ({double lat, double lon})? getCoordinates(String stateCode, String countyName) {
    final county = lookupByStateCounty(stateCode, countyName);
    if (county == null) return null;
    return (lat: county.lat, lon: county.lon);
  }
  
  /// Get all counties for a state.
  List<CountyData> getCountiesForState(String stateCode) {
    if (!_loaded) return [];
    final upperState = stateCode.toUpperCase();
    return _counties.values
        .where((c) => c.stateCode == upperState)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
  
  /// Get FIPS code for a state/county name combination.
  String? getFipsForStateCounty(String stateCode, String countyName) {
    final county = lookupByStateCounty(stateCode, countyName);
    return county?.fips;
  }
  
  /// Normalize county name by removing common suffixes.
  String _normalizeCountyName(String name) {
    var normalized = name.trim();
    
    const suffixes = [
      ' County',
      ' Parish',
      ' Borough',
      ' Census Area',
      ' Municipality',
      ' city',
      ' City and Borough',
      ' City',
    ];
    
    for (final suffix in suffixes) {
      if (normalized.toLowerCase().endsWith(suffix.toLowerCase())) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    
    return normalized.trim();
  }
  
  /// Generate name variants for fuzzy matching.
  List<String> _generateNameVariants(String normalizedName) {
    final variants = <String>[];
    
    // Try with common suffixes
    const suffixes = ['county', 'parish', 'borough'];
    for (final suffix in suffixes) {
      if (!normalizedName.endsWith(suffix)) {
        variants.add('$normalizedName $suffix');
      }
    }
    
    // Try without "Saint" abbreviation
    if (normalizedName.startsWith('st.') || normalizedName.startsWith('st ')) {
      variants.add('saint${normalizedName.substring(2)}');
    }
    if (normalizedName.startsWith('saint ')) {
      variants.add('st.${normalizedName.substring(5)}');
      variants.add('st${normalizedName.substring(5)}');
    }
    
    return variants;
  }
}

/// Data for a single county.
class CountyData {
  const CountyData({
    required this.fips,
    required this.stateCode,
    required this.name,
    required this.normalizedName,
    required this.lat,
    required this.lon,
  });
  
  /// 5-digit FIPS code (GEOID).
  final String fips;
  
  /// 2-letter state code (e.g., "TX").
  final String stateCode;
  
  /// Full county name (e.g., "Travis County").
  final String name;
  
  /// Normalized name without suffix (e.g., "travis").
  final String normalizedName;
  
  /// Latitude of county centroid.
  final double lat;
  
  /// Longitude of county centroid.
  final double lon;
  
  @override
  String toString() => '$name, $stateCode ($fips)';
}

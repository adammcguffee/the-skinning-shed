import 'dart:math' as math;

import '../data/county_centroids.dart';

/// Utility for finding the nearest county to a given coordinate.
/// 
/// Uses haversine formula for accurate distance calculation.
/// Privacy-safe: only uses county centroids, never stores user coordinates.
class CountyLocator {
  CountyLocator._();
  
  /// Find the nearest county to the given coordinates.
  /// 
  /// Returns null if county data isn't loaded or no counties found.
  static CountyData? findNearestCounty(
    double lat,
    double lon,
    List<CountyData> counties,
  ) {
    if (counties.isEmpty) return null;
    
    CountyData? nearest;
    double minDistance = double.infinity;
    
    for (final county in counties) {
      final distance = _haversineDistance(lat, lon, county.lat, county.lon);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = county;
      }
    }
    
    return nearest;
  }
  
  /// Find the nearest county from all US counties.
  /// 
  /// Requires CountyCentroids to be loaded first.
  static Future<CountyData?> findNearestCountyFromAll(
    double lat,
    double lon,
  ) async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    if (!centroids.isLoaded) return null;
    
    // Get all counties from all states
    final allCounties = <CountyData>[];
    const stateCodes = [
      'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL',
      'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME',
      'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH',
      'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI',
      'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    ];
    
    for (final stateCode in stateCodes) {
      allCounties.addAll(centroids.getCountiesForState(stateCode));
    }
    
    return findNearestCounty(lat, lon, allCounties);
  }
  
  /// Calculate haversine distance between two points in kilometers.
  /// 
  /// More accurate than equirectangular for larger distances.
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadiusKm * c;
  }
  
  static double _toRadians(double degrees) => degrees * math.pi / 180;
  
  /// Get approximate distance in miles between two coordinates.
  static double distanceInMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return _haversineDistance(lat1, lon1, lat2, lon2) * 0.621371;
  }
}

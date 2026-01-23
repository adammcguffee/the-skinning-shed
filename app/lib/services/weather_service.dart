import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/county_centroids.dart';

/// Weather condition snapshot for a specific time.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.tempF,
    required this.tempC,
    required this.feelsLikeF,
    required this.humidity,
    required this.pressure,
    required this.pressureInHg,
    required this.windSpeedMph,
    required this.windDirDeg,
    required this.windDirText,
    required this.gustsMph,
    required this.precipMm,
    required this.cloudPct,
    required this.conditionText,
    required this.conditionCode,
    required this.isHourly,
    required this.snapshotTime,
    this.source = 'open_meteo',
  });

  final double tempF;
  final double tempC;
  final double feelsLikeF;
  final int humidity;
  final double pressure; // hPa
  final double pressureInHg; // inches mercury
  final double windSpeedMph;
  final int windDirDeg;
  final String windDirText;
  final double gustsMph;
  final double precipMm;
  final int cloudPct;
  final String conditionText;
  final int conditionCode;
  final bool isHourly;
  final DateTime snapshotTime;
  final String source;

  Map<String, dynamic> toJson() => {
    'temp_f': tempF,
    'temp_c': tempC,
    'feels_like_f': feelsLikeF,
    'humidity_pct': humidity,
    'pressure_hpa': pressure,
    'pressure_inhg': pressureInHg,
    'wind_speed': windSpeedMph,
    'wind_dir_deg': windDirDeg,
    'wind_dir_text': windDirText,
    'wind_gust': gustsMph,
    'precip_mm': precipMm,
    'cloud_pct': cloudPct,
    'condition_text': conditionText,
    'condition_code': conditionCode,
    'is_hourly': isHourly,
    'snapshot_time': snapshotTime.toIso8601String(),
    'source': source,
  };

  /// Create empty/null snapshot for when data unavailable.
  static WeatherSnapshot empty(DateTime time) => WeatherSnapshot(
    tempF: 0,
    tempC: 0,
    feelsLikeF: 0,
    humidity: 0,
    pressure: 0,
    pressureInHg: 0,
    windSpeedMph: 0,
    windDirDeg: 0,
    windDirText: 'N/A',
    gustsMph: 0,
    precipMm: 0,
    cloudPct: 0,
    conditionText: 'Unknown',
    conditionCode: 0,
    isHourly: true,
    snapshotTime: time,
    source: 'none',
  );
}

/// Moon phase snapshot.
class MoonSnapshot {
  const MoonSnapshot({
    required this.phaseName,
    required this.illuminationPct,
    required this.phaseNumber,
    required this.isWaxing,
  });

  final String phaseName;
  final double illuminationPct;
  final int phaseNumber; // 0-7 for 8 moon phases
  final bool isWaxing;

  Map<String, dynamic> toJson() => {
    'phase_name': phaseName,
    'illumination_pct': illuminationPct,
    'phase_number': phaseNumber,
    'is_waxing': isWaxing,
  };
}

/// Service for fetching historical weather data.
/// Uses Open-Meteo Archive API (free, no API key required).
class WeatherService {
  WeatherService() : _dio = Dio();

  final Dio _dio;
  static const _baseUrl = 'https://archive-api.open-meteo.com/v1/archive';

  /// Fetch historical weather conditions for a specific location and time.
  /// Returns nearest-hour data.
  Future<WeatherSnapshot?> getHistoricalConditions({
    required double lat,
    required double lon,
    required DateTime dateTime,
  }) async {
    try {
      // Open-Meteo Archive requires date range
      final dateStr = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      
      final response = await _dio.get(_baseUrl, queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'start_date': dateStr,
        'end_date': dateStr,
        'hourly': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m',
        'temperature_unit': 'fahrenheit',
        'wind_speed_unit': 'mph',
        'timezone': 'auto',
      });
      
      if (response.statusCode != 200) {
        print('Weather API error: ${response.statusCode}');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>?;
      
      if (hourly == null) return null;

      // Find the index for the nearest hour
      final times = (hourly['time'] as List).cast<String>();
      final targetHour = dateTime.hour;
      int nearestIndex = 0;
      
      for (int i = 0; i < times.length; i++) {
        final hourTime = DateTime.parse(times[i]);
        if (hourTime.hour == targetHour) {
          nearestIndex = i;
          break;
        }
        if (hourTime.hour > targetHour) {
          nearestIndex = i > 0 ? i - 1 : i;
          break;
        }
        nearestIndex = i;
      }

      // Extract values at nearest hour
      final tempF = _getDouble(hourly['temperature_2m'], nearestIndex);
      final tempC = (tempF - 32) * 5 / 9;
      final feelsLikeF = _getDouble(hourly['apparent_temperature'], nearestIndex);
      final humidity = _getInt(hourly['relative_humidity_2m'], nearestIndex);
      final precipMm = _getDouble(hourly['precipitation'], nearestIndex);
      final weatherCode = _getInt(hourly['weather_code'], nearestIndex);
      final pressureHpa = _getDouble(hourly['surface_pressure'], nearestIndex);
      final pressureInHg = pressureHpa * 0.02953; // Convert hPa to inHg
      final cloudPct = _getInt(hourly['cloud_cover'], nearestIndex);
      final windSpeedMph = _getDouble(hourly['wind_speed_10m'], nearestIndex);
      final windDirDeg = _getInt(hourly['wind_direction_10m'], nearestIndex);
      final gustsMph = _getDouble(hourly['wind_gusts_10m'], nearestIndex);

      return WeatherSnapshot(
        tempF: tempF,
        tempC: tempC,
        feelsLikeF: feelsLikeF,
        humidity: humidity,
        pressure: pressureHpa,
        pressureInHg: pressureInHg,
        windSpeedMph: windSpeedMph,
        windDirDeg: windDirDeg,
        windDirText: _degToDirection(windDirDeg),
        gustsMph: gustsMph,
        precipMm: precipMm,
        cloudPct: cloudPct,
        conditionText: _weatherCodeToText(weatherCode),
        conditionCode: weatherCode,
        isHourly: true,
        snapshotTime: DateTime.parse(times[nearestIndex]),
        source: 'open_meteo',
      );
    } catch (e) {
      print('Weather fetch error: $e');
      return null;
    }
  }

  /// Get weather for a US county at a specific time.
  Future<WeatherSnapshot?> getHistoricalForCounty({
    required String stateCode,
    required String county,
    required DateTime dateTime,
  }) async {
    final coords = CountyCentroids.getCoordinates(stateCode, county);
    if (coords == null) {
      print('No centroid for $county, $stateCode');
      return null;
    }
    
    return getHistoricalConditions(
      lat: coords.lat,
      lon: coords.lon,
      dateTime: dateTime,
    );
  }

  /// Calculate moon phase for a given date.
  /// Uses a simple astronomical calculation.
  MoonSnapshot getMoonPhase(DateTime date) {
    // Known new moon reference: January 6, 2000 at 18:14 UTC
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final lunarCycle = 29.530588853; // days
    
    final daysSinceKnown = date.difference(knownNewMoon).inHours / 24.0;
    final currentCycle = (daysSinceKnown % lunarCycle) / lunarCycle;
    
    // Calculate illumination (0 at new moon, 1 at full moon)
    final illumination = (1 - math.cos(currentCycle * 2 * math.pi)) / 2;
    final illuminationPct = (illumination * 100).roundToDouble();
    
    // Determine phase (8 phases)
    final phaseNumber = (currentCycle * 8).floor() % 8;
    final isWaxing = currentCycle < 0.5;
    
    final phases = [
      'New Moon',
      'Waxing Crescent',
      'First Quarter',
      'Waxing Gibbous',
      'Full Moon',
      'Waning Gibbous',
      'Last Quarter',
      'Waning Crescent',
    ];
    
    return MoonSnapshot(
      phaseName: phases[phaseNumber],
      illuminationPct: illuminationPct,
      phaseNumber: phaseNumber,
      isWaxing: isWaxing,
    );
  }

  // Helper to safely get double from list
  double _getDouble(dynamic list, int index) {
    if (list == null || list is! List || index >= list.length) return 0.0;
    final val = list[index];
    if (val == null) return 0.0;
    return (val as num).toDouble();
  }

  // Helper to safely get int from list
  int _getInt(dynamic list, int index) {
    if (list == null || list is! List || index >= list.length) return 0;
    final val = list[index];
    if (val == null) return 0;
    return (val as num).toInt();
  }

  // Convert degrees to cardinal direction
  String _degToDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  // Convert WMO weather code to human-readable text
  String _weatherCodeToText(int code) {
    switch (code) {
      case 0: return 'Clear sky';
      case 1: return 'Mainly clear';
      case 2: return 'Partly cloudy';
      case 3: return 'Overcast';
      case 45: return 'Fog';
      case 48: return 'Depositing rime fog';
      case 51: return 'Light drizzle';
      case 53: return 'Moderate drizzle';
      case 55: return 'Dense drizzle';
      case 56: return 'Light freezing drizzle';
      case 57: return 'Dense freezing drizzle';
      case 61: return 'Slight rain';
      case 63: return 'Moderate rain';
      case 65: return 'Heavy rain';
      case 66: return 'Light freezing rain';
      case 67: return 'Heavy freezing rain';
      case 71: return 'Slight snow fall';
      case 73: return 'Moderate snow fall';
      case 75: return 'Heavy snow fall';
      case 77: return 'Snow grains';
      case 80: return 'Slight rain showers';
      case 81: return 'Moderate rain showers';
      case 82: return 'Violent rain showers';
      case 85: return 'Slight snow showers';
      case 86: return 'Heavy snow showers';
      case 95: return 'Thunderstorm';
      case 96: return 'Thunderstorm with slight hail';
      case 99: return 'Thunderstorm with heavy hail';
      default: return 'Unknown';
    }
  }
}

/// Provider for weather service.
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// Combined weather and moon data for a trophy.
class HarvestConditions {
  const HarvestConditions({
    this.weather,
    required this.moon,
    required this.source,
    this.edited = false,
  });

  final WeatherSnapshot? weather;
  final MoonSnapshot moon;
  final String source; // 'auto', 'user', 'mixed'
  final bool edited;

  /// Create a copy with modifications.
  HarvestConditions copyWith({
    WeatherSnapshot? weather,
    MoonSnapshot? moon,
    String? source,
    bool? edited,
  }) {
    return HarvestConditions(
      weather: weather ?? this.weather,
      moon: moon ?? this.moon,
      source: source ?? this.source,
      edited: edited ?? this.edited,
    );
  }
}

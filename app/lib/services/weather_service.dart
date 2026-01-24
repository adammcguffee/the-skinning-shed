import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/county_centroids.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TIME PARSING HELPERS (GLOBALLY CORRECT)
// ═══════════════════════════════════════════════════════════════════════════

/// Parse unix timestamp (seconds) to local DateTime.
/// This is the ONLY correct way to handle times from Open-Meteo when using timeformat=unixtime.
/// The returned DateTime is in the device's local timezone.
DateTime parseUnixtimeSecondsToLocal(int unixSeconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  ).toLocal();
}

/// Format hour for display (e.g., "7PM", "12AM").
String formatHourLabel(DateTime time) {
  final hour = time.hour;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour$suffix';
}

// ═══════════════════════════════════════════════════════════════════════════
// LIVE WEATHER DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Current weather conditions from live forecast.
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.tempF,
    required this.feelsLikeF,
    required this.humidity,
    required this.pressureInHg,
    required this.windSpeedMph,
    required this.windDirDeg,
    required this.windDirText,
    required this.gustsMph,
    required this.precipProbability,
    required this.cloudCover,
    required this.conditionText,
    required this.conditionCode,
    required this.visibility,
  });
  
  final DateTime time;
  final double tempF;
  final double feelsLikeF;
  final int humidity;
  final double pressureInHg;
  final double windSpeedMph;
  final int windDirDeg;
  final String windDirText;
  final double gustsMph;
  final int precipProbability;
  final int cloudCover;
  final String conditionText;
  final int conditionCode;
  final double visibility; // miles
}

/// Hourly forecast entry.
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.tempF,
    required this.feelsLikeF,
    required this.humidity,
    required this.pressureInHg,
    required this.windSpeedMph,
    required this.windDirDeg,
    required this.windDirText,
    required this.gustsMph,
    required this.precipProbability,
    required this.precipMm,
    required this.cloudCover,
    required this.conditionText,
    required this.conditionCode,
    required this.visibility,
    required this.isNow,
  });
  
  final DateTime time;
  final double tempF;
  final double feelsLikeF;
  final int humidity;
  final double pressureInHg;
  final double windSpeedMph;
  final int windDirDeg;
  final String windDirText;
  final double gustsMph;
  final int precipProbability;
  final double precipMm;
  final int cloudCover;
  final String conditionText;
  final int conditionCode;
  final double visibility;
  final bool isNow;
  
  /// Time label for UI ("Now", "7PM", etc).
  String get timeLabel => isNow ? 'Now' : formatHourLabel(time);
}

/// Daily forecast entry.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.highF,
    required this.lowF,
    required this.precipProbability,
    required this.precipSum,
    required this.windSpeedMax,
    required this.conditionText,
    required this.conditionCode,
    required this.sunrise,
    required this.sunset,
  });
  
  final DateTime date;
  final double highF;
  final double lowF;
  final int precipProbability;
  final double precipSum;
  final double windSpeedMax;
  final String conditionText;
  final int conditionCode;
  final DateTime sunrise;
  final DateTime sunset;
  
  /// Day label for UI ("Today", "Tomorrow", "Wednesday", etc).
  String get dayLabel {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[date.weekday % 7];
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Complete live weather response.
class LiveWeatherData {
  const LiveWeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.nowIndex,
    required this.fetchedAt,
    required this.lat,
    required this.lon,
  });
  
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final int nowIndex;
  final DateTime fetchedAt;
  final double lat;
  final double lon;
  
  /// Check if data is stale (>5 min old).
  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes > 5;
}

// ═══════════════════════════════════════════════════════════════════════════
// HISTORICAL WEATHER DATA MODEL (for trophy posts)
// ═══════════════════════════════════════════════════════════════════════════

/// Weather condition snapshot for a specific time (historical).
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

/// Weather data tier for source selection (historical only).
enum _WeatherTier {
  recent,
  historicalForecast,
  archive,
}

// ═══════════════════════════════════════════════════════════════════════════
// WEATHER SERVICE
// ═══════════════════════════════════════════════════════════════════════════

/// Weather service with EXPLICIT separation of live vs historical modes.
/// 
/// ## LIVE WEATHER (Weather Page)
/// - `getLiveWeatherForLocation(lat, lon)` - ALWAYS uses Forecast API
/// - Returns current + hourly + daily data
/// - Uses unixtime for globally correct timezone handling
/// 
/// ## HISTORICAL WEATHER (Trophy Post Auto-fill)
/// - `getHistoricalConditions(lat, lon, dateTime)` - uses 3-tier selection
/// - Tier 1: Recent (last 14 days) - Forecast API with past_days
/// - Tier 2: Historical Forecast (2022+) - Historical Forecast API
/// - Tier 3: Archive (pre-2022) - Archive API
class WeatherService {
  WeatherService() : _dio = Dio();

  final Dio _dio;
  
  // API endpoints
  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _historicalForecastUrl = 'https://historical-forecast-api.open-meteo.com/v1/forecast';
  static const _archiveUrl = 'https://archive-api.open-meteo.com/v1/archive';
  
  // Cache for live weather (5 min TTL)
  final Map<String, LiveWeatherData> _liveCache = {};
  
  String _cacheKey(double lat, double lon) => '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';

  // ═══════════════════════════════════════════════════════════════════════════
  // LIVE WEATHER (Weather Page) - ALWAYS uses Forecast API
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Fetch LIVE weather for a location. Weather page MUST use this method.
  /// 
  /// Always uses Open-Meteo Forecast API (never historical endpoints).
  /// Returns current conditions + 48 hours hourly + 7 days daily.
  /// 
  /// Uses unixtime for globally correct timezone handling.
  Future<LiveWeatherData?> getLiveWeatherForLocation({
    required double lat,
    required double lon,
  }) async {
    // Validate coordinates
    assert(lat >= -90 && lat <= 90, 'Invalid latitude: $lat');
    assert(lon >= -180 && lon <= 180, 'Invalid longitude: $lon');
    
    // Check cache
    final key = _cacheKey(lat, lon);
    final cached = _liveCache[key];
    if (cached != null && !cached.isStale) {
      if (kDebugMode) {
        debugPrint('WeatherService: Using cached data for $key');
      }
      return cached;
    }
    
    try {
      // Hourly variables
      const hourlyVars = 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'precipitation_probability,precipitation,weather_code,surface_pressure,'
          'cloud_cover,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m';
      
      // Daily variables
      const dailyVars = 'temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'precipitation_probability_max,weather_code,wind_speed_10m_max,'
          'sunrise,sunset';
      
      final url = _forecastUrl;
      final params = {
        'latitude': lat,
        'longitude': lon,
        'hourly': hourlyVars,
        'daily': dailyVars,
        'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
            'precipitation,weather_code,surface_pressure,cloud_cover,visibility,'
            'wind_speed_10m,wind_direction_10m,wind_gusts_10m',
        'temperature_unit': 'fahrenheit',
        'wind_speed_unit': 'mph',
        'precipitation_unit': 'inch',
        'timeformat': 'unixtime',
        'timezone': 'auto',
        'forecast_days': 7,
        'forecast_hours': 48,
      };
      
      if (kDebugMode) {
        debugPrint('WeatherService [LIVE]: Fetching from $url');
        debugPrint('WeatherService [LIVE]: lat=$lat, lon=$lon');
      }
      
      final response = await _dio.get(url, queryParameters: params);
      
      if (response.statusCode != 200) {
        debugPrint('WeatherService: API error ${response.statusCode}');
        return null;
      }
      
      final data = response.data as Map<String, dynamic>;
      final result = _parseLiveResponse(data, lat, lon);
      
      if (result != null) {
        _liveCache[key] = result;
        
        if (kDebugMode) {
          _logLiveWeatherDebug(result, lat, lon);
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('WeatherService [LIVE]: Error: $e');
      return null;
    }
  }
  
  /// Parse live weather response with unixtime.
  LiveWeatherData? _parseLiveResponse(
    Map<String, dynamic> data,
    double lat,
    double lon,
  ) {
    try {
      // Parse current
      final currentData = data['current'] as Map<String, dynamic>?;
      if (currentData == null) {
        debugPrint('WeatherService: No current data');
        return null;
      }
      
      final currentTimeUnix = currentData['time'] as int;
      final currentTime = parseUnixtimeSecondsToLocal(currentTimeUnix);
      final currentWeatherCode = _getInt(currentData, 'weather_code');
      final currentWindDir = _getInt(currentData, 'wind_direction_10m');
      final currentPressureHpa = _getDouble(currentData, 'surface_pressure');
      
      final current = CurrentWeather(
        time: currentTime,
        tempF: _getDouble(currentData, 'temperature_2m'),
        feelsLikeF: _getDouble(currentData, 'apparent_temperature'),
        humidity: _getInt(currentData, 'relative_humidity_2m'),
        pressureInHg: currentPressureHpa * 0.02953,
        windSpeedMph: _getDouble(currentData, 'wind_speed_10m'),
        windDirDeg: currentWindDir,
        windDirText: _degToDirection(currentWindDir),
        gustsMph: _getDouble(currentData, 'wind_gusts_10m'),
        precipProbability: 0, // Not in current, will get from hourly
        cloudCover: _getInt(currentData, 'cloud_cover'),
        conditionText: _weatherCodeToText(currentWeatherCode),
        conditionCode: currentWeatherCode,
        visibility: _getDouble(currentData, 'visibility') / 1609.34, // m to mi
      );
      
      // Parse hourly
      final hourlyData = data['hourly'] as Map<String, dynamic>?;
      if (hourlyData == null) {
        debugPrint('WeatherService: No hourly data');
        return null;
      }
      
      final hourlyTimes = (hourlyData['time'] as List).cast<int>();
      final hourlyCount = hourlyTimes.length;
      
      // Find "now" index: first hour that is >= current time
      final now = DateTime.now();
      int nowIndex = 0;
      for (int i = 0; i < hourlyTimes.length; i++) {
        final hourTime = parseUnixtimeSecondsToLocal(hourlyTimes[i]);
        if (hourTime.isAfter(now) || 
            (hourTime.hour == now.hour && hourTime.day == now.day)) {
          nowIndex = i;
          break;
        }
      }
      // Clamp to valid range
      nowIndex = nowIndex.clamp(0, hourlyCount - 1);
      
      final hourly = <HourlyForecast>[];
      for (int i = nowIndex; i < hourlyCount && hourly.length < 24; i++) {
        final time = parseUnixtimeSecondsToLocal(hourlyTimes[i]);
        final weatherCode = _getIntFromList(hourlyData['weather_code'], i);
        final windDir = _getIntFromList(hourlyData['wind_direction_10m'], i);
        final pressureHpa = _getDoubleFromList(hourlyData['surface_pressure'], i);
        
        hourly.add(HourlyForecast(
          time: time,
          tempF: _getDoubleFromList(hourlyData['temperature_2m'], i),
          feelsLikeF: _getDoubleFromList(hourlyData['apparent_temperature'], i),
          humidity: _getIntFromList(hourlyData['relative_humidity_2m'], i),
          pressureInHg: pressureHpa * 0.02953,
          windSpeedMph: _getDoubleFromList(hourlyData['wind_speed_10m'], i),
          windDirDeg: windDir,
          windDirText: _degToDirection(windDir),
          gustsMph: _getDoubleFromList(hourlyData['wind_gusts_10m'], i),
          precipProbability: _getIntFromList(hourlyData['precipitation_probability'], i),
          precipMm: _getDoubleFromList(hourlyData['precipitation'], i) * 25.4, // inch to mm
          cloudCover: _getIntFromList(hourlyData['cloud_cover'], i),
          conditionText: _weatherCodeToText(weatherCode),
          conditionCode: weatherCode,
          visibility: _getDoubleFromList(hourlyData['visibility'], i) / 1609.34,
          isNow: i == nowIndex,
        ));
      }
      
      // Parse daily
      final dailyData = data['daily'] as Map<String, dynamic>?;
      final daily = <DailyForecast>[];
      
      if (dailyData != null) {
        final dailyTimes = (dailyData['time'] as List).cast<int>();
        final sunrises = (dailyData['sunrise'] as List).cast<int>();
        final sunsets = (dailyData['sunset'] as List).cast<int>();
        
        for (int i = 0; i < dailyTimes.length && i < 7; i++) {
          final date = parseUnixtimeSecondsToLocal(dailyTimes[i]);
          final weatherCode = _getIntFromList(dailyData['weather_code'], i);
          
          daily.add(DailyForecast(
            date: date,
            highF: _getDoubleFromList(dailyData['temperature_2m_max'], i),
            lowF: _getDoubleFromList(dailyData['temperature_2m_min'], i),
            precipProbability: _getIntFromList(dailyData['precipitation_probability_max'], i),
            precipSum: _getDoubleFromList(dailyData['precipitation_sum'], i),
            windSpeedMax: _getDoubleFromList(dailyData['wind_speed_10m_max'], i),
            conditionText: _weatherCodeToText(weatherCode),
            conditionCode: weatherCode,
            sunrise: parseUnixtimeSecondsToLocal(sunrises[i]),
            sunset: parseUnixtimeSecondsToLocal(sunsets[i]),
          ));
        }
      }
      
      return LiveWeatherData(
        current: current,
        hourly: hourly,
        daily: daily,
        nowIndex: 0, // First item in hourly list is "now"
        fetchedAt: DateTime.now(),
        lat: lat,
        lon: lon,
      );
    } catch (e) {
      debugPrint('WeatherService: Parse error: $e');
      return null;
    }
  }
  
  /// Debug logging for live weather.
  void _logLiveWeatherDebug(LiveWeatherData data, double lat, double lon) {
    final sb = StringBuffer();
    sb.writeln('══════════════════════════════════════════');
    sb.writeln('WeatherService [LIVE] Debug:');
    sb.writeln('  lat=$lat, lon=$lon');
    sb.writeln('  endpoint=forecast (LIVE ONLY)');
    sb.writeln('  current: ${data.current.tempF.round()}°F, ${data.current.conditionText}');
    sb.writeln('  current time: ${data.current.time}');
    sb.writeln('  hourly count: ${data.hourly.length}');
    if (data.hourly.isNotEmpty) {
      sb.writeln('  first 3 hourly:');
      for (int i = 0; i < 3 && i < data.hourly.length; i++) {
        final h = data.hourly[i];
        sb.writeln('    [${h.timeLabel}] ${h.time} -> ${h.tempF.round()}°F');
      }
    }
    sb.writeln('  daily count: ${data.daily.length}');
    sb.writeln('══════════════════════════════════════════');
    debugPrint(sb.toString());
  }
  
  /// Invalidate cache for a location.
  void invalidateCache(double lat, double lon) {
    final key = _cacheKey(lat, lon);
    _liveCache.remove(key);
  }
  
  /// Clear all cached data.
  void clearCache() {
    _liveCache.clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORICAL WEATHER (Trophy Post Auto-fill) - Uses 3-tier selection
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const _recentWindowDays = 14;
  static final _historicalForecastStart = DateTime(2022, 1, 1);
  static const _hourlyVars = 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m';

  /// Fetch HISTORICAL weather conditions for trophy post auto-fill.
  /// Uses 3-tier API selection based on date.
  /// DO NOT use this for Weather page - use getLiveWeatherForLocation instead.
  Future<WeatherSnapshot?> getHistoricalConditions({
    required double lat,
    required double lon,
    required DateTime dateTime,
  }) async {
    final tier = _selectTier(dateTime);
    
    if (kDebugMode) {
      debugPrint('WeatherService [HISTORICAL]: Fetching for ${_formatDate(dateTime)} using tier: ${tier.name}');
    }
    
    var result = await _fetchFromTier(lat, lon, dateTime, tier);
    
    if (result == null && tier == _WeatherTier.recent) {
      result = await _fetchFromTier(lat, lon, dateTime, _WeatherTier.historicalForecast);
    }
    
    if (result == null && tier != _WeatherTier.archive) {
      result = await _fetchFromTier(lat, lon, dateTime, _WeatherTier.archive);
    }
    
    return result;
  }

  _WeatherTier _selectTier(DateTime dateTime) {
    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(days: _recentWindowDays));
    
    if (dateTime.isAfter(recentCutoff) || _isSameDay(dateTime, recentCutoff)) {
      return _WeatherTier.recent;
    } else if (dateTime.isAfter(_historicalForecastStart) || _isSameDay(dateTime, _historicalForecastStart)) {
      return _WeatherTier.historicalForecast;
    } else {
      return _WeatherTier.archive;
    }
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<WeatherSnapshot?> _fetchFromTier(
    double lat,
    double lon,
    DateTime dateTime,
    _WeatherTier tier,
  ) async {
    try {
      switch (tier) {
        case _WeatherTier.recent:
          return await _fetchRecent(lat, lon, dateTime);
        case _WeatherTier.historicalForecast:
          return await _fetchHistoricalForecast(lat, lon, dateTime);
        case _WeatherTier.archive:
          return await _fetchArchive(lat, lon, dateTime);
      }
    } catch (e) {
      debugPrint('WeatherService: ${tier.name} tier error: $e');
      return null;
    }
  }

  Future<WeatherSnapshot?> _fetchRecent(double lat, double lon, DateTime dateTime) async {
    final response = await _dio.get(_forecastUrl, queryParameters: {
      'latitude': lat,
      'longitude': lon,
      'hourly': _hourlyVars,
      'temperature_unit': 'fahrenheit',
      'wind_speed_unit': 'mph',
      'timezone': 'auto',
      'past_days': _recentWindowDays,
      'forecast_days': 2,
    });
    
    if (response.statusCode != 200) return null;
    return _parseHistoricalHourlyResponse(response.data, dateTime, 'auto_forecast_recent');
  }

  Future<WeatherSnapshot?> _fetchHistoricalForecast(double lat, double lon, DateTime dateTime) async {
    final dateStr = _formatDate(dateTime);
    
    final response = await _dio.get(_historicalForecastUrl, queryParameters: {
      'latitude': lat,
      'longitude': lon,
      'start_date': dateStr,
      'end_date': dateStr,
      'hourly': _hourlyVars,
      'temperature_unit': 'fahrenheit',
      'wind_speed_unit': 'mph',
      'timezone': 'auto',
    });
    
    if (response.statusCode != 200) return null;
    return _parseHistoricalHourlyResponse(response.data, dateTime, 'auto_historical_forecast');
  }

  Future<WeatherSnapshot?> _fetchArchive(double lat, double lon, DateTime dateTime) async {
    final dateStr = _formatDate(dateTime);
    
    final response = await _dio.get(_archiveUrl, queryParameters: {
      'latitude': lat,
      'longitude': lon,
      'start_date': dateStr,
      'end_date': dateStr,
      'hourly': _hourlyVars,
      'temperature_unit': 'fahrenheit',
      'wind_speed_unit': 'mph',
      'timezone': 'auto',
    });
    
    if (response.statusCode != 200) return null;
    return _parseHistoricalHourlyResponse(response.data, dateTime, 'auto_archive');
  }

  WeatherSnapshot? _parseHistoricalHourlyResponse(
    Map<String, dynamic> data,
    DateTime targetTime,
    String source,
  ) {
    final hourly = data['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return null;
    
    final times = hourly['time'] as List?;
    if (times == null || times.isEmpty) return null;
    
    final nearestIndex = _findNearestHourIndex(times.cast<String>(), targetTime);
    if (nearestIndex < 0) return null;
    
    final tempList = hourly['temperature_2m'] as List?;
    if (tempList == null || nearestIndex >= tempList.length || tempList[nearestIndex] == null) {
      return null;
    }

    final tempF = _getDoubleFromList(hourly['temperature_2m'], nearestIndex);
    final tempC = (tempF - 32) * 5 / 9;
    final feelsLikeF = _getDoubleFromList(hourly['apparent_temperature'], nearestIndex);
    final humidity = _getIntFromList(hourly['relative_humidity_2m'], nearestIndex);
    final precipMm = _getDoubleFromList(hourly['precipitation'], nearestIndex);
    final weatherCode = _getIntFromList(hourly['weather_code'], nearestIndex);
    final pressureHpa = _getDoubleFromList(hourly['surface_pressure'], nearestIndex);
    final pressureInHg = pressureHpa * 0.02953;
    final cloudPct = _getIntFromList(hourly['cloud_cover'], nearestIndex);
    final windSpeedMph = _getDoubleFromList(hourly['wind_speed_10m'], nearestIndex);
    final windDirDeg = _getIntFromList(hourly['wind_direction_10m'], nearestIndex);
    final gustsMph = _getDoubleFromList(hourly['wind_gusts_10m'], nearestIndex);

    final snapshotTimeStr = times[nearestIndex] as String;
    
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
      snapshotTime: DateTime.parse(snapshotTimeStr),
      source: source,
    );
  }

  int _findNearestHourIndex(List<String> times, DateTime targetTime) {
    if (times.isEmpty) return -1;
    
    int bestIndex = 0;
    int bestDiff = 999999999;
    final targetMs = targetTime.millisecondsSinceEpoch;
    
    for (int i = 0; i < times.length; i++) {
      try {
        final hourTime = DateTime.parse(times[i]);
        final diff = (hourTime.millisecondsSinceEpoch - targetMs).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIndex = i;
        }
      } catch (e) {
        continue;
      }
    }
    
    if (bestDiff > 2 * 60 * 60 * 1000) return -1;
    return bestIndex;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get historical weather for a US county by FIPS code.
  Future<WeatherSnapshot?> getHistoricalForCountyFips({
    required String countyFips,
    required DateTime dateTime,
  }) async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    final coords = centroids.getCoordinatesByFips(countyFips);
    if (coords == null) {
      debugPrint('No centroid for FIPS: $countyFips');
      return null;
    }
    
    return getHistoricalConditions(
      lat: coords.lat,
      lon: coords.lon,
      dateTime: dateTime,
    );
  }
  
  /// Get historical weather for a US county by state code and county name.
  Future<WeatherSnapshot?> getHistoricalForCounty({
    required String stateCode,
    required String county,
    required DateTime dateTime,
  }) async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    final coords = centroids.getCoordinates(stateCode, county);
    if (coords == null) {
      debugPrint('No centroid for $county, $stateCode');
      return null;
    }
    
    return getHistoricalConditions(
      lat: coords.lat,
      lon: coords.lon,
      dateTime: dateTime,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOON PHASE
  // ═══════════════════════════════════════════════════════════════════════════

  MoonSnapshot getMoonPhase(DateTime date) {
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    const lunarCycle = 29.530588853;
    
    final daysSinceKnown = date.difference(knownNewMoon).inHours / 24.0;
    final currentCycle = (daysSinceKnown % lunarCycle) / lunarCycle;
    
    final illumination = (1 - math.cos(currentCycle * 2 * math.pi)) / 2;
    final illuminationPct = (illumination * 100).roundToDouble();
    
    final phaseNumber = (currentCycle * 8).floor() % 8;
    final isWaxing = currentCycle < 0.5;
    
    const phases = [
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  double _getDouble(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return 0.0;
    return (val as num).toDouble();
  }
  
  int _getInt(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return 0;
    return (val as num).toInt();
  }

  double _getDoubleFromList(dynamic list, int index) {
    if (list == null || list is! List || index >= list.length) return 0.0;
    final val = list[index];
    if (val == null) return 0.0;
    return (val as num).toDouble();
  }

  int _getIntFromList(dynamic list, int index) {
    if (list == null || list is! List || index >= list.length) return 0;
    final val = list[index];
    if (val == null) return 0;
    return (val as num).toInt();
  }

  String _degToDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

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
  final String source;
  final bool edited;

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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/county_centroids.dart';
import 'location_service.dart';
import 'supabase_service.dart';
import 'weather_favorites_service.dart';
import 'weather_service.dart';

/// 🌤️ WEATHER PROVIDERS — Riverpod state management for weather screen
///
/// Provides:
/// - Selected location state (with source tracking)
/// - Live weather data (fetched from Open-Meteo Forecast API)
/// - Favorites list (synced via Supabase)
/// - Location service access

// ═══════════════════════════════════════════════════════════════════════════
// SERVICES
// ═══════════════════════════════════════════════════════════════════════════

/// Location service provider.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

/// Weather favorites service provider.
final weatherFavoritesServiceProvider = Provider<WeatherFavoritesService>((ref) {
  return WeatherFavoritesService.instance;
});

// ═══════════════════════════════════════════════════════════════════════════
// SELECTED LOCATION STATE
// ═══════════════════════════════════════════════════════════════════════════

/// Current selected location with source tracking.
class SelectedLocationState {
  const SelectedLocationState({
    this.selection,
    this.source,
    this.isLoading = false,
    this.error,
  });
  
  final CountySelection? selection;
  final SelectionSource? source;
  final bool isLoading;
  final String? error;
  
  SelectedLocationState copyWith({
    CountySelection? selection,
    SelectionSource? source,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return SelectedLocationState(
      selection: clearSelection ? null : (selection ?? this.selection),
      source: clearSelection ? null : (source ?? this.source),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Selected location state notifier.
class SelectedLocationNotifier extends StateNotifier<SelectedLocationState> {
  SelectedLocationNotifier(this._locationService)
      : super(const SelectedLocationState());
  
  final LocationService _locationService;
  bool _didInit = false;
  bool _isDetectingLocal = false;
  
  /// Check if initial auto-selection has been attempted.
  bool get didInit => _didInit;
  
  /// Initialize location on first load.
  /// 
  /// NON-BLOCKING flow for instant page load:
  /// 1. If already set, do nothing
  /// 2. Try last viewed from SharedPreferences (fast) -> show weather immediately
  /// 3. In PARALLEL, try geolocation with 6s timeout
  /// 4. If geolocation resolves to different county, swap selection
  /// 5. If no lastViewed and geolocation fails, show manual selection UI
  Future<void> initializeLocation() async {
    if (_didInit) return;
    _didInit = true;
    
    // Already has selection
    if (state.selection != null) return;
    
    // Try last viewed first (fast, no permission needed)
    final lastViewed = await _locationService.getLastViewedSelection();
    if (lastViewed != null) {
      state = SelectedLocationState(
        selection: lastViewed,
        source: SelectionSource.lastViewed,
      );
      
      // In parallel, try geolocation to see if user moved
      _tryGeolocationInBackground(lastViewed);
      return;
    }
    
    // No last viewed - must wait for geolocation
    state = state.copyWith(isLoading: true, clearError: true);
    
    final local = await _locationService.tryGetLocalCountySelection();
    if (local != null) {
      state = SelectedLocationState(
        selection: local,
        source: SelectionSource.local,
      );
      await _locationService.setLastViewedSelection(local);
      return;
    }
    
    // No automatic selection available
    state = const SelectedLocationState();
  }
  
  /// Try geolocation in background without blocking UI.
  /// If result is different from current selection, update.
  Future<void> _tryGeolocationInBackground(CountySelection currentSelection) async {
    if (_isDetectingLocal) return;
    _isDetectingLocal = true;
    
    try {
      final local = await _locationService.tryGetLocalCountySelection();
      
      if (local != null && local != currentSelection) {
        // User's actual location is different from last viewed
        // Update selection to local
        if (kDebugMode) {
          debugPrint('SelectedLocationNotifier: Geolocation detected different location');
          debugPrint('  lastViewed: ${currentSelection.fullName}');
          debugPrint('  local: ${local.fullName}');
        }
        
        state = SelectedLocationState(
          selection: local,
          source: SelectionSource.local,
        );
        await _locationService.setLastViewedSelection(local);
      }
    } finally {
      _isDetectingLocal = false;
    }
  }
  
  /// Set selection from user manual choice.
  Future<void> setManualSelection(CountySelection selection) async {
    state = SelectedLocationState(
      selection: selection,
      source: SelectionSource.manual,
    );
    await _locationService.setLastViewedSelection(selection);
  }
  
  /// Set selection from favorite tap.
  Future<void> setFavoriteSelection(CountySelection selection) async {
    state = SelectedLocationState(
      selection: selection,
      source: SelectionSource.favorite,
    );
    await _locationService.setLastViewedSelection(selection);
  }
  
  /// Trigger geolocation to get local county.
  Future<void> detectLocalLocation() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    final local = await _locationService.tryGetLocalCountySelection();
    if (local != null) {
      state = SelectedLocationState(
        selection: local,
        source: SelectionSource.local,
      );
      await _locationService.setLastViewedSelection(local);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not detect your location',
      );
    }
  }
  
  /// Load last viewed selection.
  Future<void> loadLastViewed() async {
    final lastViewed = await _locationService.getLastViewedSelection();
    if (lastViewed != null) {
      state = SelectedLocationState(
        selection: lastViewed,
        source: SelectionSource.lastViewed,
      );
    }
  }
  
  /// Clear selection.
  void clear() {
    state = const SelectedLocationState();
  }
  
  /// Clear error only.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Selected location provider.
final selectedLocationProvider =
    StateNotifierProvider<SelectedLocationNotifier, SelectedLocationState>(
  (ref) {
    final locationService = ref.watch(locationServiceProvider);
    return SelectedLocationNotifier(locationService);
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// FAVORITES
// ═══════════════════════════════════════════════════════════════════════════

/// Weather favorites state.
class WeatherFavoritesState {
  const WeatherFavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.error,
  });
  
  final List<WeatherFavoriteLocation> favorites;
  final bool isLoading;
  final String? error;
  
  WeatherFavoritesState copyWith({
    List<WeatherFavoriteLocation>? favorites,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WeatherFavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Weather favorites notifier.
class WeatherFavoritesNotifier extends StateNotifier<WeatherFavoritesState> {
  WeatherFavoritesNotifier(this._favoritesService)
      : super(const WeatherFavoritesState());
  
  final WeatherFavoritesService _favoritesService;
  
  /// Fetch favorites from Supabase.
  Future<void> fetchFavorites() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final favorites = await _favoritesService.fetchFavorites();
      state = WeatherFavoritesState(favorites: favorites);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load favorites',
      );
    }
  }
  
  /// Add a favorite.
  Future<bool> addFavorite(CountySelection selection) async {
    final result = await _favoritesService.addFavorite(selection: selection);
    if (result != null) {
      // Refresh list
      await fetchFavorites();
      return true;
    }
    return false;
  }
  
  /// Remove a favorite by ID.
  Future<bool> removeFavorite(String favoriteId) async {
    final result = await _favoritesService.removeFavorite(favoriteId: favoriteId);
    if (result) {
      // Refresh list
      await fetchFavorites();
      return true;
    }
    return false;
  }
  
  /// Remove favorite by selection.
  Future<bool> removeFavoriteBySelection(CountySelection selection) async {
    final result = await _favoritesService.removeFavoriteBySelection(
      selection: selection,
    );
    if (result) {
      await fetchFavorites();
      return true;
    }
    return false;
  }
  
  /// Check if selection is favorited.
  bool isFavorite(CountySelection? selection) {
    if (selection == null) return false;
    return state.favorites.any((f) {
      // Match by FIPS if available
      if (selection.countyFips != null && f.countyFips != null) {
        return f.countyFips == selection.countyFips;
      }
      // Fall back to state + county
      return f.stateCode == selection.stateCode &&
          f.countyName == selection.countyName;
    });
  }
  
  /// Find favorite by selection.
  WeatherFavoriteLocation? findBySelection(CountySelection? selection) {
    if (selection == null) return null;
    try {
      return state.favorites.firstWhere((f) {
        if (selection.countyFips != null && f.countyFips != null) {
          return f.countyFips == selection.countyFips;
        }
        return f.stateCode == selection.stateCode &&
            f.countyName == selection.countyName;
      });
    } catch (_) {
      return null;
    }
  }
}

/// Weather favorites provider.
final weatherFavoritesProvider =
    StateNotifierProvider<WeatherFavoritesNotifier, WeatherFavoritesState>(
  (ref) {
    final favoritesService = ref.watch(weatherFavoritesServiceProvider);
    return WeatherFavoritesNotifier(favoritesService);
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// DERIVED PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Check if current selection is a favorite.
final isCurrentLocationFavoriteProvider = Provider<bool>((ref) {
  final selectedState = ref.watch(selectedLocationProvider);
  final favoritesState = ref.watch(weatherFavoritesProvider);
  
  final selection = selectedState.selection;
  if (selection == null) return false;
  
  return favoritesState.favorites.any((f) {
    if (selection.countyFips != null && f.countyFips != null) {
      return f.countyFips == selection.countyFips;
    }
    return f.stateCode == selection.stateCode &&
        f.countyName == selection.countyName;
  });
});

/// Check if user is authenticated (for showing favorites UI).
final canUseFavoritesProvider = Provider<bool>((ref) {
  return ref.watch(isAuthenticatedProvider);
});

// ═══════════════════════════════════════════════════════════════════════════
// LIVE WEATHER DATA
// ═══════════════════════════════════════════════════════════════════════════

/// Live weather data state.
class LiveWeatherState {
  const LiveWeatherState({
    this.data,
    this.isLoading = false,
    this.error,
    this.lat,
    this.lon,
  });
  
  final LiveWeatherData? data;
  final bool isLoading;
  final String? error;
  final double? lat;
  final double? lon;
  
  LiveWeatherState copyWith({
    LiveWeatherData? data,
    bool? isLoading,
    String? error,
    double? lat,
    double? lon,
    bool clearError = false,
    bool clearData = false,
  }) {
    return LiveWeatherState(
      data: clearData ? null : (data ?? this.data),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}

/// Live weather notifier that fetches data when location changes.
class LiveWeatherNotifier extends StateNotifier<LiveWeatherState> {
  LiveWeatherNotifier(this._weatherService) : super(const LiveWeatherState());
  
  final WeatherService _weatherService;
  
  /// Fetch live weather for coordinates.
  /// This is ALWAYS called with county centroid coordinates.
  Future<void> fetchWeather({
    required double lat,
    required double lon,
    String? locationLabel,
  }) async {
    // Validate coordinates
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      if (kDebugMode) {
        debugPrint('LiveWeatherNotifier: Invalid coordinates lat=$lat lon=$lon');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Invalid location coordinates',
      );
      return;
    }
    
    // Check for obvious coordinate swap (lat looks like lon)
    if (lat.abs() > 90) {
      if (kDebugMode) {
        debugPrint('LiveWeatherNotifier: WARNING - lat=$lat appears swapped with lon=$lon');
      }
    }
    
    // Skip if same coordinates and data is fresh
    if (state.lat == lat && state.lon == lon && state.data != null && !state.data!.isStale) {
      if (kDebugMode) {
        debugPrint('LiveWeatherNotifier: Using existing data for lat=$lat lon=$lon');
      }
      return;
    }
    
    state = state.copyWith(isLoading: true, clearError: true, lat: lat, lon: lon);
    
    if (kDebugMode) {
      debugPrint('LiveWeatherNotifier: Fetching weather for lat=$lat lon=$lon ($locationLabel)');
    }
    
    final data = await _weatherService.getLiveWeatherForLocation(lat: lat, lon: lon);
    
    if (data != null) {
      state = LiveWeatherState(data: data, lat: lat, lon: lon);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load weather data',
      );
    }
  }
  
  /// Fetch weather for a county selection.
  Future<void> fetchWeatherForSelection(CountySelection selection) async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    // Get coordinates - prefer FIPS lookup
    ({double lat, double lon})? coords;
    
    if (selection.countyFips != null) {
      coords = centroids.getCoordinatesByFips(selection.countyFips!);
    }
    
    coords ??= centroids.getCoordinates(selection.stateCode, selection.countyName);
    
    if (coords == null) {
      if (kDebugMode) {
        debugPrint('LiveWeatherNotifier: No coordinates for ${selection.fullName}');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Location coordinates not found',
      );
      return;
    }
    
    await fetchWeather(
      lat: coords.lat,
      lon: coords.lon,
      locationLabel: selection.fullName,
    );
  }
  
  /// Clear weather data.
  void clear() {
    _weatherService.clearCache();
    state = const LiveWeatherState();
  }
  
  /// Refresh current location.
  Future<void> refresh() async {
    if (state.lat != null && state.lon != null) {
      _weatherService.invalidateCache(state.lat!, state.lon!);
      await fetchWeather(lat: state.lat!, lon: state.lon!);
    }
  }
}

/// Live weather provider.
final liveWeatherProvider =
    StateNotifierProvider<LiveWeatherNotifier, LiveWeatherState>(
  (ref) {
    final weatherService = ref.watch(weatherServiceProvider);
    return LiveWeatherNotifier(weatherService);
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// COORDINATE VALIDATION (Debug)
// ═══════════════════════════════════════════════════════════════════════════

/// Validate all county centroids (debug only).
/// Returns count of invalid entries.
Future<int> validateAllCountyCentroids() async {
  if (!kDebugMode) return 0;
  
  final centroids = CountyCentroids.instance;
  await centroids.ensureLoaded();
  
  int invalidCount = 0;
  const stateCodes = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL',
    'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME',
    'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH',
    'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI',
    'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  ];
  
  for (final stateCode in stateCodes) {
    final counties = centroids.getCountiesForState(stateCode);
    for (final county in counties) {
      // Check valid lat range
      if (county.lat < -90 || county.lat > 90) {
        debugPrint('INVALID LAT: ${county.name}, $stateCode -> lat=${county.lat}');
        invalidCount++;
      }
      // Check valid lon range
      if (county.lon < -180 || county.lon > 180) {
        debugPrint('INVALID LON: ${county.name}, $stateCode -> lon=${county.lon}');
        invalidCount++;
      }
      // Check for obvious swap (US counties should have negative longitude)
      if (county.lon > 0 && stateCode != 'AK') {
        // Most US states have negative longitude (west of prime meridian)
        // Alaska crosses the date line so some parts are positive
        debugPrint('SUSPICIOUS LON (positive): ${county.name}, $stateCode -> lon=${county.lon}');
      }
    }
  }
  
  debugPrint('County centroid validation complete: $invalidCount invalid entries');
  return invalidCount;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';
import 'supabase_service.dart';
import 'weather_favorites_service.dart';

/// 🌤️ WEATHER PROVIDERS — Riverpod state management for weather screen
///
/// Provides:
/// - Selected location state (with source tracking)
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
  
  /// Check if initial auto-selection has been attempted.
  bool get didInit => _didInit;
  
  /// Initialize location on first load.
  /// 
  /// Priority:
  /// 1. If already set, do nothing
  /// 2. Try last viewed from SharedPreferences
  /// 3. Try geolocation -> nearest county
  /// 4. Leave empty (show manual selection UI)
  Future<void> initializeLocation() async {
    if (_didInit) return;
    _didInit = true;
    
    // Already has selection
    if (state.selection != null) return;
    
    state = state.copyWith(isLoading: true, clearError: true);
    
    // Try last viewed first (fast, no permission needed)
    final lastViewed = await _locationService.getLastViewedSelection();
    if (lastViewed != null) {
      state = SelectedLocationState(
        selection: lastViewed,
        source: SelectionSource.lastViewed,
      );
      return;
    }
    
    // Try geolocation
    final local = await _locationService.tryGetLocalCountySelection();
    if (local != null) {
      state = SelectedLocationState(
        selection: local,
        source: SelectionSource.local,
      );
      // Also save as last viewed for next time
      await _locationService.setLastViewedSelection(local);
      return;
    }
    
    // No automatic selection available
    state = const SelectedLocationState();
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/data/county_centroids.dart';
import 'package:shed/services/location_service.dart';
import 'package:shed/services/solunar_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/weather_favorites_service.dart';
import 'package:shed/services/weather_providers.dart';
import 'package:shed/services/weather_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🌤️ WEATHER SCREEN - 2025 CINEMATIC DARK THEME
///
/// Premium weather with:
/// - LIVE weather data from Open-Meteo Forecast API
/// - Auto-detect local weather (geolocation)
/// - Quick location chips (Local, Last Viewed, Favorites)
/// - Synced favorites via Supabase
/// - Correct timezone handling via unixtime
/// - Hourly forecast (scrollable)
/// - Wind speed, direction, gusts
/// - Temperature & precipitation
/// - Accent color wind emphasis
/// - Hunting tools integration
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  USState? _selectedState;
  String? _selectedCounty;
  String? _selectedCountyFips;
  bool _didInit = false;
  CountySelection? _lastFetchedSelection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (_didInit) return;
    _didInit = true;
    
    // Initialize selected location (will try lastViewed then geolocation)
    await ref.read(selectedLocationProvider.notifier).initializeLocation();
    
    // Fetch favorites if authenticated
    if (ref.read(isAuthenticatedProvider)) {
      await ref.read(weatherFavoritesProvider.notifier).fetchFavorites();
    }
    
    // Fetch weather for initial selection
    final selection = ref.read(selectedLocationProvider).selection;
    if (selection != null) {
      await _fetchWeatherForSelection(selection);
    }
  }

  void _syncFromProviderState() {
    final locationState = ref.read(selectedLocationProvider);
    final selection = locationState.selection;
    
    if (selection != null) {
      final state = USStates.byCode(selection.stateCode);
      if (state != null && (_selectedState != state || _selectedCounty != selection.countyName)) {
        setState(() {
          _selectedState = state;
          _selectedCounty = selection.countyName;
          _selectedCountyFips = selection.countyFips;
        });
      }
      
      // Fetch weather if selection changed
      if (_lastFetchedSelection != selection) {
        _fetchWeatherForSelection(selection);
      }
    }
  }
  
  Future<void> _fetchWeatherForSelection(CountySelection selection) async {
    if (_lastFetchedSelection == selection) return;
    _lastFetchedSelection = selection;
    await ref.read(liveWeatherProvider.notifier).fetchWeatherForSelection(selection);
  }

  Future<void> _handleManualSelection(USState? state, String? county, String? fips) async {
    if (state != null && county != null) {
      final selection = CountySelection(
        stateCode: state.code,
        stateName: state.name,
        countyName: county,
        countyFips: fips,
      );
      await ref.read(selectedLocationProvider.notifier).setManualSelection(selection);
      await _fetchWeatherForSelection(selection);
    }
  }

  Future<void> _handleFavoriteSelection(WeatherFavoriteLocation favorite) async {
    final stateName = USStates.byCode(favorite.stateCode)?.name ?? favorite.stateCode;
    final selection = CountySelection(
      stateCode: favorite.stateCode,
      stateName: stateName,
      countyName: favorite.countyName,
      countyFips: favorite.countyFips,
    );
    await ref.read(selectedLocationProvider.notifier).setFavoriteSelection(selection);
    await _fetchWeatherForSelection(selection);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;
    
    // Watch provider states
    final locationState = ref.watch(selectedLocationProvider);
    final weatherState = ref.watch(liveWeatherProvider);
    final favoritesState = ref.watch(weatherFavoritesProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isFavorite = ref.watch(isCurrentLocationFavoriteProvider);
    
    // Sync local dropdown state from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromProviderState();
    });
    
    final hasSelection = _selectedState != null && _selectedCounty != null;
    final isLoading = locationState.isLoading || weatherState.isLoading;
    final hasWeatherData = weatherState.data != null;

    return CustomScrollView(
      slivers: [
        // Header with favorite toggle
        SliverToBoxAdapter(
          child: _buildHeader(
            context,
            isWide,
            locationState: locationState,
            isFavorite: isFavorite,
            isAuthenticated: isAuthenticated,
          ),
        ),

        // Quick location chips
        SliverToBoxAdapter(
          child: _QuickLocationsRow(
            favorites: favoritesState.favorites,
            isAuthenticated: isAuthenticated,
            isLoading: locationState.isLoading,
            onLocalTap: () async {
              await ref.read(selectedLocationProvider.notifier).detectLocalLocation();
              final selection = ref.read(selectedLocationProvider).selection;
              if (selection != null) {
                await _fetchWeatherForSelection(selection);
              }
            },
            onLastViewedTap: () async {
              await ref.read(selectedLocationProvider.notifier).loadLastViewed();
              final selection = ref.read(selectedLocationProvider).selection;
              if (selection != null) {
                await _fetchWeatherForSelection(selection);
              }
            },
            onFavoriteTap: _handleFavoriteSelection,
          ),
        ),

        // Location selector
        SliverToBoxAdapter(
          child: _LocationSelector(
            selectedState: _selectedState,
            selectedCounty: _selectedCounty,
            selectedCountyFips: _selectedCountyFips,
            onStateChanged: (state) {
              setState(() {
                _selectedState = state;
                _selectedCounty = null;
                _selectedCountyFips = null;
              });
            },
            onCountyChanged: (county, fips) async {
              setState(() {
                _selectedCounty = county;
                _selectedCountyFips = fips;
              });
              await _handleManualSelection(_selectedState, county, fips);
            },
          ),
        ),

        // Loading state
        if (isLoading)
          SliverToBoxAdapter(
            child: _LocationLoadingIndicator(
              message: locationState.isLoading 
                  ? 'Detecting your location...'
                  : 'Loading weather data...',
            ),
          ),

        // Weather content
        if (hasSelection && !isLoading && hasWeatherData) ...[
          // Source label
          if (locationState.source != null)
            SliverToBoxAdapter(
              child: _SourceLabel(source: locationState.source!),
            ),

          // Current conditions hero
          SliverToBoxAdapter(
            child: _CurrentConditionsHero(data: weatherState.data!),
          ),

          // Hourly forecast (scrollable)
          SliverToBoxAdapter(
            child: _HourlyForecast(hourly: weatherState.data!.hourly),
          ),

          // Wind section (emphasized)
          SliverToBoxAdapter(
            child: _WindSection(current: weatherState.data!.current),
          ),

          // 5-Day forecast
          SliverToBoxAdapter(
            child: _DailyForecast(
              daily: weatherState.data!.daily,
              hourly: weatherState.data!.hourly,
            ),
          ),

          // Hunting tools
          SliverToBoxAdapter(
            child: _HuntingTools(
              daily: weatherState.data!.daily,
              hourly: weatherState.data!.hourly,
              current: weatherState.data!.current,
              lat: weatherState.data!.lat,
              lon: weatherState.data!.lon,
            ),
          ),
        ] else if (hasSelection && !isLoading && weatherState.error != null)
          SliverToBoxAdapter(
            child: _WeatherErrorState(error: weatherState.error!),
          )
        else if (!hasSelection && !isLoading)
          SliverToBoxAdapter(
            child: _LocationPrompt(),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isWide, {
    required SelectedLocationState locationState,
    required bool isFavorite,
    required bool isAuthenticated,
  }) {
    final selection = locationState.selection;
    final hasSelection = selection != null;
    
    return Container(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.md,
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: AppColors.shadowAccent,
            ),
            child: const Icon(
              Icons.cloud_rounded,
              color: AppColors.textInverse,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather & Tools',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  hasSelection
                      ? selection.fullName
                      : 'Select a location',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Favorite toggle (only show when authenticated and has selection)
          if (isAuthenticated && hasSelection) ...[
            const SizedBox(width: AppSpacing.sm),
            _FavoriteToggle(
              isFavorite: isFavorite,
              onToggle: () async {
                if (isFavorite) {
                  final removed = await ref
                      .read(weatherFavoritesProvider.notifier)
                      .removeFavoriteBySelection(selection);
                  if (removed && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from favorites'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  final added = await ref
                      .read(weatherFavoritesProvider.notifier)
                      .addFavorite(selection);
                  if (added && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to favorites'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FAVORITE TOGGLE
// ═══════════════════════════════════════════════════════════════════════════

class _FavoriteToggle extends StatefulWidget {
  const _FavoriteToggle({
    required this.isFavorite,
    required this.onToggle,
  });
  
  final bool isFavorite;
  final VoidCallback onToggle;
  
  @override
  State<_FavoriteToggle> createState() => _FavoriteToggleState();
}

class _FavoriteToggleState extends State<_FavoriteToggle> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : () async {
          setState(() => _isLoading = true);
          widget.onToggle();
          // Brief delay to prevent rapid tapping
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() => _isLoading = false);
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isFavorite
                ? AppColors.accent.withOpacity(0.15)
                : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isFavorite
                  ? AppColors.accent.withOpacity(0.3)
                  : AppColors.borderSubtle,
            ),
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                )
              : Icon(
                  widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 24,
                  color: widget.isFavorite ? AppColors.accent : AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK LOCATIONS ROW
// ═══════════════════════════════════════════════════════════════════════════

class _QuickLocationsRow extends StatelessWidget {
  const _QuickLocationsRow({
    required this.favorites,
    required this.isAuthenticated,
    required this.isLoading,
    required this.onLocalTap,
    required this.onLastViewedTap,
    required this.onFavoriteTap,
  });
  
  final List<WeatherFavoriteLocation> favorites;
  final bool isAuthenticated;
  final bool isLoading;
  final VoidCallback onLocalTap;
  final VoidCallback onLastViewedTap;
  final ValueChanged<WeatherFavoriteLocation> onFavoriteTap;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Local chip (always visible)
            _QuickLocationChip(
              icon: Icons.my_location_rounded,
              label: 'Local',
              onTap: isLoading ? null : onLocalTap,
              isLoading: isLoading,
            ),
            const SizedBox(width: AppSpacing.sm),
            
            // Last Viewed chip
            _QuickLocationChip(
              icon: Icons.history_rounded,
              label: 'Recent',
              onTap: onLastViewedTap,
            ),
            
            // Favorite chips (only if authenticated and has favorites)
            if (isAuthenticated && favorites.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                color: AppColors.borderSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              ...favorites.map((fav) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _QuickLocationChip(
                  icon: Icons.star_rounded,
                  label: fav.label,
                  onTap: () => onFavoriteTap(fav),
                  color: AppColors.accent,
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickLocationChip extends StatefulWidget {
  const _QuickLocationChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isLoading = false,
  });
  
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLoading;
  
  @override
  State<_QuickLocationChip> createState() => _QuickLocationChipState();
}

class _QuickLocationChipState extends State<_QuickLocationChip> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.primary;
    final isEnabled = widget.onTap != null && !widget.isLoading;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered && isEnabled
                  ? effectiveColor.withOpacity(0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: _isHovered && isEnabled
                    ? effectiveColor.withOpacity(0.3)
                    : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(effectiveColor),
                    ),
                  )
                else
                  Icon(
                    widget.icon,
                    size: 16,
                    color: isEnabled ? effectiveColor : AppColors.textTertiary,
                  ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isEnabled ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCATION LOADING INDICATOR
// ═══════════════════════════════════════════════════════════════════════════

class _LocationLoadingIndicator extends StatelessWidget {
  const _LocationLoadingIndicator({this.message = 'Loading...'});
  
  final String message;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WEATHER ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════

class _WeatherErrorState extends StatelessWidget {
  const _WeatherErrorState({required this.error});
  
  final String error;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Weather Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOURCE LABEL
// ═══════════════════════════════════════════════════════════════════════════

class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.source});
  
  final SelectionSource source;
  
  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (source) {
      SelectionSource.local => (
        Icons.my_location_rounded,
        'Local (near you)',
        AppColors.success,
      ),
      SelectionSource.lastViewed => (
        Icons.history_rounded,
        'Last viewed location',
        AppColors.textSecondary,
      ),
      SelectionSource.favorite => (
        Icons.star_rounded,
        'Favorite',
        AppColors.accent,
      ),
      SelectionSource.manual => (
        Icons.touch_app_rounded,
        'Selected',
        AppColors.textSecondary,
      ),
    };
    
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Location selector with dark theme
class _LocationSelector extends ConsumerWidget {
  const _LocationSelector({
    required this.selectedState,
    required this.selectedCounty,
    required this.selectedCountyFips,
    required this.onStateChanged,
    required this.onCountyChanged,
  });

  final USState? selectedState;
  final String? selectedCounty;
  final String? selectedCountyFips;
  final ValueChanged<USState?> onStateChanged;
  final void Function(String? county, String? fips) onCountyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: LocationSelector(
          selectedState: selectedState,
          selectedCounty: selectedCounty,
          selectedCountyFips: selectedCountyFips,
          onStateChanged: onStateChanged,
          onCountyChanged: (county) => onCountyChanged(county, null),
          onCountyChangedWithFips: (selected) {
            if (selected != null) {
              onCountyChanged(selected.name, selected.fips);
            } else {
              onCountyChanged(null, null);
            }
          },
        ),
      ),
    );
  }
}

/// Location prompt when no location selected
class _LocationPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.location_searching_rounded,
                size: 32,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Select a Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Choose your state and county to see weather conditions, hourly forecast, and hunting tools.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Current conditions hero card - Premium dense layout
class _CurrentConditionsHero extends StatelessWidget {
  const _CurrentConditionsHero({required this.data});
  
  final LiveWeatherData data;
  
  String _getPrecipType() {
    final temp = data.current.tempF;
    final precip = data.current.precipProbability;
    if (precip < 20) return '';
    if (temp <= 28) return 'Snow likely';
    if (temp <= 34) return 'Freezing rain risk';
    return 'Rain';
  }
  
  String _getPressureTrend() {
    if (data.hourly.length < 6) return 'Steady';
    final now = data.hourly.first.pressureInHg;
    final later = data.hourly[5].pressureInHg;
    final diff = later - now;
    if (diff > 0.05) return 'Rising ↑';
    if (diff < -0.05) return 'Falling ↓';
    return 'Steady →';
  }
  
  List<Widget> _getAlertChips() {
    final current = data.current;
    final chips = <Widget>[];
    
    // Precipitation type chip
    final precipType = _getPrecipType();
    if (precipType.isNotEmpty) {
      final color = precipType.contains('Snow') || precipType.contains('Freezing')
          ? AppColors.info
          : AppColors.warning;
      chips.add(_AlertChip(label: precipType, color: color));
    }
    
    // High wind
    if (current.gustsMph > 25) {
      chips.add(_AlertChip(label: 'High gusts', color: AppColors.warning));
    }
    
    // Low visibility
    if (current.visibility < 3) {
      chips.add(_AlertChip(label: 'Low visibility', color: AppColors.warning));
    }
    
    return chips;
  }
  
  String _getUpdatedAgo() {
    final diff = DateTime.now().difference(data.fetchedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
  
  @override
  Widget build(BuildContext context) {
    final current = data.current;
    final icon = _getWeatherIcon(current.conditionCode);
    final alertChips = _getAlertChips();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppColors.shadowElevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main hero row: Temp + Large Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Temperature + condition
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${current.tempF.round()}',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              '°F',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        current.conditionText,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      Text(
                        'Feels like ${current.feelsLikeF.round()}°F',
                        style: const TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                
                // Right: Large icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(icon, size: 64, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Alert chips
            if (alertChips.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 4, children: alertChips),
            
            const SizedBox(height: AppSpacing.md),
            
            // "Now Strip" - compact stat tiles
            _NowStrip(current: current, pressureTrend: _getPressureTrend()),
            
            const SizedBox(height: AppSpacing.md),
            
            // Metrics grid - dense 2x3
            _MetricsPillGrid(current: current),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Updated timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.update_rounded, size: 12, color: Colors.white38),
                const SizedBox(width: 4),
                Text('Updated ${_getUpdatedAgo()}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Now Strip" - compact horizontal stat tiles for immediate conditions
class _NowStrip extends StatelessWidget {
  const _NowStrip({required this.current, required this.pressureTrend});
  
  final CurrentWeather current;
  final String pressureTrend;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          // Wind tile
          Expanded(
            child: _NowTile(
              icon: Icons.air_rounded,
              label: 'Wind',
              value: '${current.windSpeedMph.round()} ${current.windDirText}',
              trailing: Transform.rotate(
                angle: current.windDirDeg * math.pi / 180,
                child: const Icon(Icons.navigation_rounded, size: 14, color: Colors.white70),
              ),
            ),
          ),
          _verticalDivider(),
          // Precip tile
          Expanded(
            child: _NowTile(
              icon: Icons.umbrella_outlined,
              label: 'Precip',
              value: '${current.precipProbability}%',
            ),
          ),
          _verticalDivider(),
          // Pressure trend tile
          Expanded(
            child: _NowTile(
              icon: Icons.compress_rounded,
              label: 'Pressure',
              value: pressureTrend,
            ),
          ),
          _verticalDivider(),
          // Visibility tile
          Expanded(
            child: _NowTile(
              icon: Icons.visibility_outlined,
              label: 'Vis.',
              value: '${current.visibility.round()} mi',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _verticalDivider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.white.withOpacity(0.15),
  );
}

class _NowTile extends StatelessWidget {
  const _NowTile({required this.icon, required this.label, required this.value, this.trailing});
  
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            if (trailing != null) ...[const SizedBox(width: 2), trailing!],
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.label, required this.color});
  
  final String label;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _MetricsPillGrid extends StatelessWidget {
  const _MetricsPillGrid({required this.current});
  
  final CurrentWeather current;
  
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MetricPill(icon: Icons.water_drop_outlined, label: 'Humidity', value: '${current.humidity}%'),
        _MetricPill(icon: Icons.speed_rounded, label: 'Gusts', value: '${current.gustsMph.round()} mph'),
        _MetricPill(icon: Icons.compress_rounded, label: 'Pressure', value: '${current.pressureInHg.toStringAsFixed(2)}"'),
        _MetricPill(icon: Icons.cloud_outlined, label: 'Cloud', value: '${current.cloudCover}%'),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label, required this.value});
  
  final IconData icon;
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45))),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _getWeatherIcon(int code) {
  if (code == 0 || code == 1) return Icons.wb_sunny_outlined;
  if (code == 2) return Icons.cloud_outlined;
  if (code == 3) return Icons.cloud;
  if (code >= 45 && code <= 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.water_drop;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.grain;
  if (code >= 85 && code <= 86) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.cloud_outlined;
}

/// Hourly forecast - scrollable
class _HourlyForecast extends StatelessWidget {
  const _HourlyForecast({required this.hourly});
  
  final List<HourlyForecast> hourly;

  @override
  Widget build(BuildContext context) {
    // Convert HourlyForecast to _HourData for UI compatibility
    final hours = hourly.map((h) => _HourData(
      time: h.timeLabel,
      temp: h.tempF.round(),
      feelsLike: h.feelsLikeF.round(),
      icon: _getWeatherIcon(h.conditionCode),
      precip: h.precipProbability,
      windSpeed: h.windSpeedMph.round(),
      windDirectionDegrees: h.windDirDeg,
      windDirectionText: h.windDirText,
      gusts: h.gustsMph.round(),
      humidity: h.humidity,
      pressure: h.pressureInHg,
      visibility: h.visibility.round(),
      condition: h.conditionText,
    )).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Row(
              children: [
                const Text(
                  'Hourly Forecast',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              itemCount: hours.length,
              itemBuilder: (context, index) => _HourCard(
                data: hours[index],
                isFirst: index == 0,
                onTap: () => _showHourlyDetails(context, hours[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHourlyDetails(BuildContext context, _HourData data) {
    showShedModal(
      context: context,
      child: _HourlyDetailContent(data: data),
    );
  }
}

/// Full hourly data model with all weather details
class _HourData {
  const _HourData({
    required this.time,
    required this.icon,
    this.temp,
    this.feelsLike,
    this.precip,
    this.windSpeed,
    this.windDirectionDegrees,
    this.windDirectionText,
    this.gusts,
    this.humidity,
    this.pressure,
    this.visibility,
    this.condition,
  });

  final String time;
  final IconData icon;
  final int? temp;
  final int? feelsLike;
  final int? precip;
  final int? windSpeed;
  final int? windDirectionDegrees; // degrees (0-360)
  final String? windDirectionText; // N, NE, E, SE, S, SW, W, NW
  final int? gusts;
  final int? humidity;
  final double? pressure;
  final int? visibility;
  final String? condition;
}

/// Hourly card with wind direction arrow
class _HourCard extends StatefulWidget {
  const _HourCard({
    required this.data,
    required this.onTap,
    this.isFirst = false,
  });

  final _HourData data;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  State<_HourCard> createState() => _HourCardState();
}

class _HourCardState extends State<_HourCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final windDirectionText = _directionLabel(
      widget.data.windDirectionDegrees,
      widget.data.windDirectionText,
    );
    final hasWindDirection = widget.data.windDirectionDegrees != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 80,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: widget.isFirst
                ? AppColors.accent.withOpacity(0.15)
                : _isHovered || _isPressed
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: widget.isFirst
                  ? AppColors.accent.withOpacity(0.3)
                  : _isHovered
                      ? AppColors.borderStrong
                      : AppColors.borderSubtle,
            ),
            boxShadow: _isPressed ? null : (_isHovered ? AppColors.shadowCard : null),
          ),
          transform: _isPressed ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time
              Text(
                widget.data.time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isFirst ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isFirst ? AppColors.accent : AppColors.textSecondary,
                ),
              ),

              // Icon
              Icon(
                widget.data.icon,
                size: 24,
                color: widget.isFirst ? AppColors.accent : AppColors.textSecondary,
              ),

              // Temperature
              Text(
                _formatTemp(widget.data.temp),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isFirst ? AppColors.accent : AppColors.textPrimary,
                ),
              ),

              // Wind with direction arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: hasWindDirection
                        ? (widget.data.windDirectionDegrees! + 180) * math.pi / 180
                        : 0,
                    child: Icon(
                      hasWindDirection ? Icons.navigation_rounded : Icons.remove,
                      size: 10,
                      color: hasWindDirection ? AppColors.accent : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatValue(widget.data.windSpeed),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    ' $windDirectionText',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),

              // Precip
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 10,
                    color: (widget.data.precip ?? 0) > 20
                        ? AppColors.info
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatPercent(widget.data.precip),
                    style: TextStyle(
                      fontSize: 10,
                      color: (widget.data.precip ?? 0) > 20
                          ? AppColors.info
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail content for the hourly weather bottom sheet.
/// Uses mainAxisSize.min to size-to-content (no micro-scroll).
class _HourlyDetailContent extends StatelessWidget {
  const _HourlyDetailContent({required this.data});

  final _HourData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        _HeaderRow(data: data),
        const SizedBox(height: AppSpacing.xl),

        // Details grid
        _MetricsGrid(data: data),
      ],
    );
  }
}

/// Header row with icon, time, condition, and temperature.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.data});

  final _HourData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(data.icon, size: 32, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.time,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                data.condition ?? '—',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _formatTempF(data.temp),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Metrics grid with all weather details.
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final _HourData data;

  @override
  Widget build(BuildContext context) {
    final windDirectionText = _directionLabel(
      data.windDirectionDegrees,
      data.windDirectionText,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.lg,
        children: [
          // Row 1: Feels Like + Humidity
          _MetricRow(
            item1: _DetailItem(
              icon: Icons.thermostat_outlined,
              label: 'Feels Like',
              value: _formatTempF(data.feelsLike),
            ),
            item2: _DetailItem(
              icon: Icons.water_drop_outlined,
              label: 'Humidity',
              value: _formatPercent(data.humidity),
            ),
          ),

          // Row 2: Wind Speed + Gusts
          _MetricRow(
            item1: _DetailItem(
              icon: Icons.air_rounded,
              label: 'Wind Speed',
              value: _formatMph(data.windSpeed, suffix: ' $windDirectionText'),
              valueColor: AppColors.accent,
            ),
            item2: _DetailItem(
              icon: Icons.speed_rounded,
              label: 'Gusts',
              value: _formatMph(data.gusts),
              valueColor: AppColors.accent,
            ),
          ),

          // Row 3: Wind Direction + Precip
          _MetricRow(
            item1: _DetailItem(
              icon: Icons.explore_outlined,
              label: 'Wind Direction',
              value: _formatDirection(data.windDirectionDegrees, windDirectionText),
              valueColor: AppColors.accent,
            ),
            item2: _DetailItem(
              icon: Icons.umbrella_outlined,
              label: 'Precipitation',
              value: _formatPercent(data.precip),
              valueColor: (data.precip ?? 0) > 20 ? AppColors.info : null,
            ),
          ),

          // Row 4: Pressure + Visibility
          _MetricRow(
            item1: _DetailItem(
              icon: Icons.compress_rounded,
              label: 'Pressure',
              value: _formatPressure(data.pressure),
            ),
            item2: _DetailItem(
              icon: Icons.visibility_outlined,
              label: 'Visibility',
              value: _formatMiles(data.visibility),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of two metric items that adapts to available width.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.item1,
    required this.item2,
  });

  final Widget item1;
  final Widget item2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(child: item1),
          Expanded(child: item2),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatValue(num? value, {String suffix = ''}) {
  if (value == null) return '—';
  return '$value$suffix';
}

String _formatTemp(int? value) {
  if (value == null) return '—';
  return '$value°';
}

String _formatTempF(int? value) {
  if (value == null) return '—';
  return '$value°F';
}

String _formatPercent(int? value) {
  if (value == null) return '—';
  return '$value%';
}

String _formatMph(int? value, {String suffix = ''}) {
  if (value == null) return '—';
  return '$value mph$suffix';
}

String _formatPressure(double? value) {
  if (value == null) return '—';
  return '${value.toStringAsFixed(2)} in';
}

String _formatMiles(int? value) {
  if (value == null) return '—';
  return '$value mi';
}

String _formatDirection(int? degrees, String? label) {
  if (degrees == null) return '—';
  return '$degrees° ($label)';
}

String _directionLabel(int? degrees, String? label) {
  if (label != null && label.trim().isNotEmpty) return label;
  if (degrees == null) return '—';
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((degrees % 360) / 45).round() % directions.length;
  return directions[index];
}

/// Wind section with emphasis
class _WindSection extends StatelessWidget {
  const _WindSection({required this.current});
  
  final CurrentWeather current;
  
  @override
  Widget build(BuildContext context) {
    final windSpeed = current.windSpeedMph.round();
    final gustSpeed = current.gustsMph.round();
    final isGoodForHunting = windSpeed >= 5 && windSpeed <= 15;
    final hasStrongGusts = gustSpeed > 20;
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Wind Conditions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isGoodForHunting)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text(
                    'Good for Hunting',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                // Wind compass
                _WindCompass(directionDeg: current.windDirDeg),
                const SizedBox(width: AppSpacing.xl),

                // Wind details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Speed
                      Row(
                        children: [
                          Text(
                            '$windSpeed',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'mph',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                              Text(
                                'Wind Speed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Direction & Gusts
                      Row(
                        children: [
                          _WindStat(
                            label: 'Direction',
                            value: current.windDirText,
                            icon: Icons.navigation_rounded,
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _WindStat(
                            label: 'Gusts',
                            value: '$gustSpeed mph',
                            icon: Icons.air_rounded,
                            isWarning: hasStrongGusts,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindCompass extends StatelessWidget {
  const _WindCompass({required this.directionDeg});
  
  final int directionDeg;
  
  @override
  Widget build(BuildContext context) {
    // Convert wind direction to radians
    // Wind direction indicates where wind is coming FROM, arrow points in that direction
    final angleRadians = directionDeg * math.pi / 180;
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Compass marks
          ...['N', 'E', 'S', 'W'].asMap().entries.map((entry) {
            final index = entry.key;
            final letter = entry.value;
            final isNorth = index == 0;
            return Positioned(
              top: index == 0 ? 8 : null,
              bottom: index == 2 ? 8 : null,
              left: index == 3 ? 8 : null,
              right: index == 1 ? 8 : null,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isNorth ? FontWeight.w700 : FontWeight.w500,
                  color: isNorth ? AppColors.accent : AppColors.textTertiary,
                ),
              ),
            );
          }),

          // Wind arrow (points where wind is coming from)
          Transform.rotate(
            angle: angleRadians,
            child: Icon(
              Icons.navigation_rounded,
              size: 36,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindStat extends StatelessWidget {
  const _WindStat({
    required this.label,
    required this.value,
    required this.icon,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isWarning
                ? AppColors.warning.withOpacity(0.15)
                : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isWarning ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isWarning ? AppColors.warning : AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 5-Day forecast - clickable with day details
class _DailyForecast extends StatelessWidget {
  const _DailyForecast({required this.daily, this.hourly});
  
  final List<DailyForecast> daily;
  final List<HourlyForecast>? hourly;
  
  void _showDayDetails(BuildContext context, DailyForecast day, int dayIndex) {
    showShedModal(
      context: context,
      child: _DayDetailContent(day: day, dayIndex: dayIndex),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${daily.length}-Day Forecast',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Tap for details',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                for (int i = 0; i < daily.length; i++) ...[
                  _ForecastDayRow(
                    dayData: daily[i],
                    onTap: () => _showDayDetails(context, daily[i], i),
                  ),
                  if (i < daily.length - 1)
                    const Divider(height: 1, color: AppColors.divider),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastDayRow extends StatefulWidget {
  const _ForecastDayRow({required this.dayData, required this.onTap});

  final DailyForecast dayData;
  final VoidCallback onTap;

  @override
  State<_ForecastDayRow> createState() => _ForecastDayRowState();
}

class _ForecastDayRowState extends State<_ForecastDayRow> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final day = widget.dayData;
    final icon = _getWeatherIcon(day.conditionCode);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              // Day
              SizedBox(
                width: 90,
                child: Text(
                  day.dayLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Icon
              Icon(icon, size: 24, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),

              // Precip
              SizedBox(
                width: 50,
                child: Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      size: 14,
                      color: day.precipProbability > 50 ? AppColors.info : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${day.precipProbability}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: day.precipProbability > 50 ? AppColors.info : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Wind
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    Icon(
                      Icons.air_rounded,
                      size: 14,
                      color: day.windSpeedMax > 15 ? AppColors.accent : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${day.windSpeedMax.round()}mph',
                      style: TextStyle(
                        fontSize: 12,
                        color: day.windSpeedMax > 15 ? AppColors.accent : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Temps
              Text(
                '${day.highF.round()}°',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${day.lowF.round()}°',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day detail modal content
class _DayDetailContent extends StatelessWidget {
  const _DayDetailContent({required this.day, required this.dayIndex});
  
  final DailyForecast day;
  final int dayIndex;
  
  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
  
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
  
  @override
  Widget build(BuildContext context) {
    final icon = _getWeatherIcon(day.conditionCode);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.dayLabel,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_formatDate(day.date)} • ${day.conditionText}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${day.highF.round()}°',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  '${day.lowF.round()}°',
                  style: const TextStyle(fontSize: 16, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.xl),
        
        // Metrics grid
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: [
              _DayMetricRow(
                icon1: Icons.umbrella_outlined, label1: 'Precip Chance', value1: '${day.precipProbability}%',
                icon2: Icons.water_drop_outlined, label2: 'Precip Amount', value2: '${day.precipSum.toStringAsFixed(2)}"',
              ),
              const SizedBox(height: AppSpacing.md),
              _DayMetricRow(
                icon1: Icons.air_rounded, label1: 'Max Wind', value1: '${day.windSpeedMax.round()} mph',
                icon2: Icons.wb_sunny_outlined, label2: 'Sunrise', value2: _formatTime(day.sunrise),
              ),
              const SizedBox(height: AppSpacing.md),
              _DayMetricRow(
                icon1: Icons.nightlight_round, label1: 'Sunset', value1: _formatTime(day.sunset),
                icon2: Icons.schedule_rounded, label2: 'Daylight', 
                value2: '${day.sunset.difference(day.sunrise).inHours}h ${day.sunset.difference(day.sunrise).inMinutes % 60}m',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Hunting guidance
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Hunting Windows',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getHuntingGuidance(),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getHuntingGuidance() {
    final parts = <String>[];
    
    // Dawn window
    parts.add('Best dawn: ${_formatTime(day.sunrise.subtract(const Duration(minutes: 30)))} - ${_formatTime(day.sunrise.add(const Duration(hours: 2)))}');
    
    // Dusk window
    parts.add('Best dusk: ${_formatTime(day.sunset.subtract(const Duration(hours: 2)))} - ${_formatTime(day.sunset)}');
    
    // Wind advice
    if (day.windSpeedMax > 20) {
      parts.add('Wind may be strong - consider sheltered spots.');
    } else if (day.windSpeedMax < 10) {
      parts.add('Light wind - scent control important.');
    }
    
    // Precip advice
    if (day.precipProbability > 50) {
      parts.add('Rain likely - animals may move early.');
    }
    
    return parts.join('\n');
  }
}

class _DayMetricRow extends StatelessWidget {
  const _DayMetricRow({
    required this.icon1, required this.label1, required this.value1,
    required this.icon2, required this.label2, required this.value2,
  });
  
  final IconData icon1;
  final String label1;
  final String value1;
  final IconData icon2;
  final String label2;
  final String value2;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DayMetric(icon: icon1, label: label1, value: value1)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _DayMetric(icon: icon2, label: label2, value: value2)),
      ],
    );
  }
}

class _DayMetric extends StatelessWidget {
  const _DayMetric({required this.icon, required this.label, required this.value});
  
  final IconData icon;
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hunting tools section - clickable with detail modals
class _HuntingTools extends StatelessWidget {
  const _HuntingTools({required this.daily, this.hourly, this.current, this.lat, this.lon});
  
  final List<DailyForecast> daily;
  final List<HourlyForecast>? hourly;
  final CurrentWeather? current;
  final double? lat;
  final double? lon;
  
  String _formatTimeShort(DateTime time) {
    final hour = time.hour;
    final suffix = hour >= 12 ? 'p' : 'a';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${time.minute.toString().padLeft(2, '0')}$suffix';
  }
  
  SolunarTimes? _getSolunarTimes() {
    if (lat == null || lon == null) return null;
    final solunar = SolunarService();
    return solunar.getSolunarTimes(date: DateTime.now(), latitude: lat!, longitude: lon!);
  }
  
  @override
  Widget build(BuildContext context) {
    final today = daily.isNotEmpty ? daily.first : null;
    final moonService = WeatherService();
    final moon = moonService.getMoonPhase(DateTime.now());
    final solunar = _getSolunarTimes();
    
    // Next Solunar period
    String nextPeriodText = '—';
    if (solunar != null) {
      final next = solunar.getNextPeriod(DateTime.now());
      if (next != null) {
        nextPeriodText = '${next.type}: ${_formatTimeShort(next.start)}';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Hunting Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Text('Tap for details', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DenseToolCard(
                  icon: Icons.air_rounded,
                  title: 'Wind',
                  mainValue: current != null ? '${current!.windSpeedMph.round()} mph' : '—',
                  line1: current != null ? '${current!.windDirText} direction' : '—',
                  line2: current != null ? 'Gusts ${current!.gustsMph.round()} mph' : '—',
                  color: AppColors.accent,
                  onTap: () => _showWindModal(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DenseToolCard(
                  icon: Icons.compress_rounded,
                  title: 'Pressure',
                  mainValue: current != null ? '${current!.pressureInHg.toStringAsFixed(2)}"' : '—',
                  line1: _getPressureTrend(),
                  line2: current != null ? '${(current!.pressureInHg * 33.8639).round()} hPa' : '—',
                  color: AppColors.primary,
                  onTap: () => _showPressureModal(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DenseToolCard(
                  icon: Icons.dark_mode_outlined,
                  title: 'Moon',
                  mainValue: moon.phaseName,
                  line1: '${moon.illuminationPct.round()}% illuminated',
                  line2: moon.isWaxing ? 'Waxing' : 'Waning',
                  color: AppColors.info,
                  onTap: () => _showMoonModal(context, moon),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DenseToolCard(
                  icon: Icons.schedule_rounded,
                  title: 'Solunar',
                  mainValue: nextPeriodText,
                  line1: solunar?.major1 != null ? 'Major: ${_formatTimeShort(solunar!.major1!.start)}' : 'Major: —',
                  line2: solunar?.minor1 != null ? 'Minor: ${_formatTimeShort(solunar!.minor1!.start)}' : 'Minor: —',
                  color: AppColors.success,
                  onTap: () => _showActivityModal(context, today, moon, solunar),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _getPressureTrend() {
    if (hourly == null || hourly!.length < 6) return 'Trend unknown';
    final now = hourly!.first.pressureInHg;
    final later = hourly![5].pressureInHg;
    final diff = later - now;
    if (diff > 0.05) return 'Rising ↑';
    if (diff < -0.05) return 'Falling ↓';
    return 'Steady →';
  }
  
  void _showWindModal(BuildContext context) {
    showShedModal(context: context, child: _WindToolContent(current: current, hourly: hourly));
  }
  
  void _showPressureModal(BuildContext context) {
    showShedModal(context: context, child: _PressureToolContent(current: current, hourly: hourly));
  }
  
  void _showMoonModal(BuildContext context, MoonSnapshot moon) {
    showShedModal(context: context, child: _MoonToolContent(moon: moon));
  }
  
  void _showActivityModal(BuildContext context, DailyForecast? today, MoonSnapshot moon, SolunarTimes? solunar) {
    showShedModal(context: context, child: _SolunarActivityContent(today: today, hourly: hourly, moon: moon, solunar: solunar));
  }
}

/// Dense tool card with more data visible
class _DenseToolCard extends StatefulWidget {
  const _DenseToolCard({
    required this.icon,
    required this.title,
    required this.mainValue,
    required this.line1,
    required this.line2,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String mainValue;
  final String line1;
  final String line2;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_DenseToolCard> createState() => _DenseToolCardState();
}

class _DenseToolCardState extends State<_DenseToolCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: _isHovered || _isPressed ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _isHovered ? widget.color.withOpacity(0.3) : AppColors.borderSubtle),
          ),
          transform: _isPressed ? (Matrix4.identity()..scale(0.98)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + title + chevron
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: 6),
              // Main value
              Text(widget.mainValue, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: widget.color)),
              const SizedBox(height: 2),
              // Secondary info
              Text(widget.line1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(widget.line2, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HUNTING TOOL MODALS
// ═══════════════════════════════════════════════════════════════════════════

class _WindToolContent extends StatelessWidget {
  const _WindToolContent({this.current, this.hourly});
  
  final CurrentWeather? current;
  final List<HourlyForecast>? hourly;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolHeader(icon: Icons.air_rounded, title: 'Wind Conditions', color: AppColors.accent),
        const SizedBox(height: AppSpacing.lg),
        
        if (current != null) ...[
          // Current wind
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                _WindCompass(directionDeg: current!.windDirDeg),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${current!.windSpeedMph.round()} mph', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent)),
                      Text('Direction: ${current!.windDirText} (${current!.windDirDeg}°)', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      Text('Gusts: ${current!.gustsMph.round()} mph', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        // Next 12 hours wind
        if (hourly != null && hourly!.isNotEmpty) ...[
          const Text('Next 12 Hours', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: hourly!.length > 12 ? 12 : hourly!.length,
              itemBuilder: (context, i) {
                final h = hourly![i];
                return Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h.timeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      Text('${h.windSpeedMph.round()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      Transform.rotate(
                        angle: h.windDirDeg * math.pi / 180,
                        child: const Icon(Icons.navigation_rounded, size: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        // Guidance
        _ToolGuidance(text: 'For deer hunting: Calmer winds (5-15 mph) are often best. Wind direction matters for scent - position downwind of expected game.'),
      ],
    );
  }
}

class _PressureToolContent extends StatelessWidget {
  const _PressureToolContent({this.current, this.hourly});
  
  final CurrentWeather? current;
  final List<HourlyForecast>? hourly;
  
  String _getTrend() {
    if (hourly == null || hourly!.length < 6) return 'Unknown';
    final now = hourly!.first.pressureInHg;
    final later = hourly![5].pressureInHg;
    final diff = later - now;
    if (diff > 0.05) return 'Rising';
    if (diff < -0.05) return 'Falling';
    return 'Steady';
  }
  
  @override
  Widget build(BuildContext context) {
    final trend = _getTrend();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolHeader(icon: Icons.compress_rounded, title: 'Barometric Pressure', color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        
        if (current != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${current!.pressureInHg.toStringAsFixed(2)}"', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    Text('${(current!.pressureInHg * 33.8639).round()} hPa', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: trend == 'Rising' ? AppColors.success.withOpacity(0.15) 
                         : trend == 'Falling' ? AppColors.warning.withOpacity(0.15) 
                         : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trend == 'Rising' ? Icons.trending_up : trend == 'Falling' ? Icons.trending_down : Icons.trending_flat,
                        size: 16,
                        color: trend == 'Rising' ? AppColors.success : trend == 'Falling' ? AppColors.warning : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(trend, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: trend == 'Rising' ? AppColors.success : trend == 'Falling' ? AppColors.warning : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        // Next 12 hours pressure
        if (hourly != null && hourly!.isNotEmpty) ...[
          const Text('Next 12 Hours', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: hourly!.length > 12 ? 12 : hourly!.length,
              itemBuilder: (context, i) {
                final h = hourly![i];
                return Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h.timeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      Text(h.pressureInHg.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        _ToolGuidance(text: 'Many hunters report increased deer movement during pressure changes, especially falling pressure before storms. This is anecdotal guidance, not guaranteed.'),
      ],
    );
  }
}

class _MoonToolContent extends StatelessWidget {
  const _MoonToolContent({required this.moon});
  
  final MoonSnapshot moon;
  
  IconData _getMoonIcon() {
    switch (moon.phaseNumber) {
      case 0: return Icons.brightness_3; // New
      case 1: return Icons.brightness_2; // Waxing crescent
      case 2: return Icons.brightness_4; // First quarter
      case 3: return Icons.brightness_5; // Waxing gibbous
      case 4: return Icons.brightness_7; // Full
      case 5: return Icons.brightness_6; // Waning gibbous
      case 6: return Icons.brightness_4; // Last quarter
      case 7: return Icons.brightness_2; // Waning crescent
      default: return Icons.dark_mode_outlined;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolHeader(icon: Icons.dark_mode_outlined, title: 'Moon Phase', color: AppColors.info),
        const SizedBox(height: AppSpacing.lg),
        
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getMoonIcon(), size: 48, color: AppColors.info),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moon.phaseName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${moon.illuminationPct.round()}% illuminated', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text(moon.isWaxing ? 'Waxing (growing)' : 'Waning (shrinking)', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        _ToolGuidance(text: 'Some hunters believe deer are more active during full and new moons. Bright moonlight may shift feeding patterns to nighttime. Results vary.'),
      ],
    );
  }
}

/// Solunar-based Activity Forecast modal
class _SolunarActivityContent extends StatelessWidget {
  const _SolunarActivityContent({this.today, this.hourly, required this.moon, this.solunar});
  
  final DailyForecast? today;
  final List<HourlyForecast>? hourly;
  final MoonSnapshot moon;
  final SolunarTimes? solunar;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolHeader(icon: Icons.schedule_rounded, title: 'Solunar Activity', color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        
        // Solunar Major/Minor periods
        if (solunar != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    const Text('Major Periods (~2h peak activity)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _SolunarPeriodTile(period: solunar!.major1, label: 'Major 1')),
                    const SizedBox(width: 8),
                    Expanded(child: _SolunarPeriodTile(period: solunar!.major2, label: 'Major 2')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_half_rounded, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    const Text('Minor Periods (~1h activity)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.info)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _SolunarPeriodTile(period: solunar!.minor1, label: 'Minor 1', color: AppColors.info)),
                    const SizedBox(width: 8),
                    Expanded(child: _SolunarPeriodTile(period: solunar!.minor2, label: 'Minor 2', color: AppColors.info)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
                SizedBox(width: 8),
                Expanded(child: Text('Solunar times unavailable for this location.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        // Dawn/Dusk reference (separate from Solunar)
        if (today != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dawn & Dusk Reference', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.wb_twilight_rounded, size: 14, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text('Sunrise: ${_fmtTime(today!.sunrise)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.nightlight_round, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Sunset: ${_fmtTime(today!.sunset)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Weather adjustment note
        if (hourly != null && hourly!.isNotEmpty)
          _WeatherAdjustmentNote(hourly: hourly!),
        
        const SizedBox(height: AppSpacing.md),
        
        _ToolGuidance(text: 'Solunar theory suggests game activity peaks when the moon is overhead or underfoot (Major) and at moonrise/moonset (Minor). Weather conditions may shift actual behavior. Use as guidance only.'),
      ],
    );
  }
  
  String _fmtTime(DateTime t) {
    final h = t.hour;
    final m = t.minute;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $suffix';
  }
}

class _SolunarPeriodTile extends StatelessWidget {
  const _SolunarPeriodTile({this.period, required this.label, this.color});
  
  final SolunarPeriod? period;
  final String label;
  final Color? color;
  
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.success;
    if (period == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
          ],
        ),
      );
    }
    
    final isActive = period!.isActive(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? c.withOpacity(0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: isActive ? Border.all(color: c.withOpacity(0.4)) : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isActive ? c : AppColors.textTertiary)),
              if (isActive) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('NOW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(period!.timeRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? c : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _WeatherAdjustmentNote extends StatelessWidget {
  const _WeatherAdjustmentNote({required this.hourly});
  
  final List<HourlyForecast> hourly;
  
  @override
  Widget build(BuildContext context) {
    final notes = <String>[];
    final next6h = hourly.take(6).toList();
    
    // Check wind
    final avgWind = next6h.map((h) => h.windSpeedMph).reduce((a, b) => a + b) / next6h.length;
    if (avgWind > 20) {
      notes.add('High winds may reduce activity');
    } else if (avgWind < 8) {
      notes.add('Calm winds favorable');
    }
    
    // Check precip
    final maxPrecip = next6h.map((h) => h.precipProbability).reduce(math.max);
    if (maxPrecip > 60) {
      notes.add('Rain may shift feeding earlier');
    }
    
    // Check pressure trend
    if (hourly.length >= 6) {
      final diff = hourly[5].pressureInHg - hourly.first.pressureInHg;
      if (diff < -0.08) {
        notes.add('Falling pressure often increases movement');
      }
    }
    
    if (notes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wb_cloudy_outlined, size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Weather factors: ${notes.join('. ')}.',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolHeader extends StatelessWidget {
  const _ToolHeader({required this.icon, required this.title, required this.color});
  
  final IconData icon;
  final String title;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ToolGuidance extends StatelessWidget {
  const _ToolGuidance({required this.text});
  
  final String text;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

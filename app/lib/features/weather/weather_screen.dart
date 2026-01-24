import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/location_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/weather_favorites_service.dart';
import 'package:shed/services/weather_providers.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🌤️ WEATHER SCREEN - 2025 CINEMATIC DARK THEME
///
/// Premium weather with:
/// - Auto-detect local weather (geolocation)
/// - Quick location chips (Local, Last Viewed, Favorites)
/// - Synced favorites via Supabase
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

  @override
  void initState() {
    super.initState();
    // Initialize location on first build
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
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;
    
    // Watch provider state and sync local state
    final locationState = ref.watch(selectedLocationProvider);
    final favoritesState = ref.watch(weatherFavoritesProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isFavorite = ref.watch(isCurrentLocationFavoriteProvider);
    
    // Sync local dropdown state from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromProviderState();
    });

    return CustomScrollView(
      slivers: [
        // Banner header is now rendered by AppScaffold

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
            },
            onLastViewedTap: () async {
              await ref.read(selectedLocationProvider.notifier).loadLastViewed();
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

        // Loading state for location detection
        if (locationState.isLoading)
          SliverToBoxAdapter(
            child: _LocationLoadingIndicator(),
          ),

        // Weather content
        if (_selectedState != null && _selectedCounty != null && !locationState.isLoading) ...[
          // Source label
          if (locationState.source != null)
            SliverToBoxAdapter(
              child: _SourceLabel(source: locationState.source!),
            ),

          // Current conditions hero
          SliverToBoxAdapter(
            child: _CurrentConditionsHero(),
          ),

          // Hourly forecast (scrollable)
          SliverToBoxAdapter(
            child: _HourlyForecast(),
          ),

          // Wind section (emphasized)
          SliverToBoxAdapter(
            child: _WindSection(),
          ),

          // 5-Day forecast
          SliverToBoxAdapter(
            child: _DailyForecast(),
          ),

          // Hunting tools
          SliverToBoxAdapter(
            child: _HuntingTools(),
          ),
        ] else if (!locationState.isLoading)
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
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text(
              'Detecting your location...',
              style: TextStyle(
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

/// Current conditions hero card
class _CurrentConditionsHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temperature & conditions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Conditions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '58°F',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Partly Cloudy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Feels like 55°F',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),

                // Weather icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(
                    Icons.cloud_outlined,
                    size: 48,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickStat(icon: Icons.water_drop_outlined, label: 'Humidity', value: '65%'),
                _QuickStat(icon: Icons.umbrella_outlined, label: 'Precip', value: '10%'),
                _QuickStat(icon: Icons.visibility_outlined, label: 'Visibility', value: '10 mi'),
                _QuickStat(icon: Icons.speed_outlined, label: 'Pressure', value: '30.12"'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

/// Hourly forecast - scrollable
class _HourlyForecast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mock hourly data with full details
    final hours = [
      _HourData(time: 'Now', temp: 58, feelsLike: 55, icon: Icons.cloud_outlined, precip: 10, windSpeed: 12, windDirectionDegrees: 225, windDirectionText: 'SW', gusts: 18, humidity: 65, pressure: 30.12, visibility: 10, condition: 'Partly Cloudy'),
      _HourData(time: '1PM', temp: 60, feelsLike: 58, icon: Icons.wb_sunny_outlined, precip: 5, windSpeed: 14, windDirectionDegrees: 230, windDirectionText: 'SW', gusts: 20, humidity: 60, pressure: 30.10, visibility: 10, condition: 'Mostly Sunny'),
      _HourData(time: '2PM', temp: 62, feelsLike: 60, icon: Icons.wb_sunny_outlined, precip: 0, windSpeed: 15, windDirectionDegrees: 235, windDirectionText: 'SW', gusts: 22, humidity: 55, pressure: 30.08, visibility: 10, condition: 'Sunny'),
      _HourData(time: '3PM', temp: 63, feelsLike: 61, icon: Icons.wb_sunny_outlined, precip: 0, windSpeed: 16, windDirectionDegrees: 240, windDirectionText: 'WSW', gusts: 24, humidity: 52, pressure: 30.06, visibility: 10, condition: 'Sunny'),
      _HourData(time: '4PM', temp: 61, feelsLike: 59, icon: Icons.cloud_outlined, precip: 5, windSpeed: 14, windDirectionDegrees: 245, windDirectionText: 'WSW', gusts: 21, humidity: 58, pressure: 30.04, visibility: 10, condition: 'Partly Cloudy'),
      _HourData(time: '5PM', temp: 58, feelsLike: 55, icon: Icons.cloud_outlined, precip: 15, windSpeed: 12, windDirectionDegrees: 250, windDirectionText: 'W', gusts: 18, humidity: 62, pressure: 30.02, visibility: 9, condition: 'Cloudy'),
      _HourData(time: '6PM', temp: 54, feelsLike: 51, icon: Icons.wb_twilight_rounded, precip: 20, windSpeed: 10, windDirectionDegrees: 255, windDirectionText: 'W', gusts: 15, humidity: 68, pressure: 30.00, visibility: 8, condition: 'Evening Clouds'),
      _HourData(time: '7PM', temp: 50, feelsLike: 47, icon: Icons.nightlight_round, precip: 25, windSpeed: 8, windDirectionDegrees: 260, windDirectionText: 'W', gusts: 12, humidity: 72, pressure: 29.98, visibility: 8, condition: 'Partly Cloudy'),
      _HourData(time: '8PM', temp: 48, feelsLike: 44, icon: Icons.nightlight_round, precip: 30, windSpeed: 7, windDirectionDegrees: 265, windDirectionText: 'W', gusts: 10, humidity: 75, pressure: 29.96, visibility: 7, condition: 'Scattered Showers'),
    ];

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HourlyDetailSheet(data: data),
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

/// Detail sheet shown when tapping an hourly card.
/// Uses DraggableScrollableSheet for responsive scroll behavior.
class _HourlyDetailSheet extends StatelessWidget {
  const _HourlyDetailSheet({required this.data});

  final _HourData data;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab handle
                  _GrabHandle(),
                  const SizedBox(height: AppSpacing.lg),

                  // Header row
                  _HeaderRow(data: data),
                  const SizedBox(height: AppSpacing.xl),

                  // Details grid
                  _MetricsGrid(data: data),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Grab handle for the bottom sheet.
class _GrabHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
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
  @override
  Widget build(BuildContext context) {
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
                _WindCompass(),
                const SizedBox(width: AppSpacing.xl),

                // Wind details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Speed
                      Row(
                        children: [
                          const Text(
                            '12',
                            style: TextStyle(
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
                            value: 'NNW',
                            icon: Icons.navigation_rounded,
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _WindStat(
                            label: 'Gusts',
                            value: '18 mph',
                            icon: Icons.air_rounded,
                            isWarning: true,
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
  @override
  Widget build(BuildContext context) {
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

          // Wind arrow
          Transform.rotate(
            angle: -0.4, // NNW direction
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

/// 5-Day forecast
class _DailyForecast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5-Day Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
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
                _ForecastDay(day: 'Today', high: 58, low: 42, icon: Icons.cloud_outlined, precip: 10, wind: 12),
                const Divider(height: 1, color: AppColors.divider),
                _ForecastDay(day: 'Tomorrow', high: 62, low: 45, icon: Icons.wb_sunny_outlined, precip: 5, wind: 8),
                const Divider(height: 1, color: AppColors.divider),
                _ForecastDay(day: 'Wednesday', high: 55, low: 38, icon: Icons.grain_outlined, precip: 65, wind: 15),
                const Divider(height: 1, color: AppColors.divider),
                _ForecastDay(day: 'Thursday', high: 48, low: 32, icon: Icons.ac_unit_outlined, precip: 40, wind: 20),
                const Divider(height: 1, color: AppColors.divider),
                _ForecastDay(day: 'Friday', high: 52, low: 35, icon: Icons.wb_cloudy_outlined, precip: 20, wind: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastDay extends StatelessWidget {
  const _ForecastDay({
    required this.day,
    required this.high,
    required this.low,
    required this.icon,
    required this.precip,
    required this.wind,
  });

  final String day;
  final int high;
  final int low;
  final IconData icon;
  final int precip;
  final int wind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          // Day
          SizedBox(
            width: 90,
            child: Text(
              day,
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
                  color: precip > 50 ? AppColors.info : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$precip%',
                  style: TextStyle(
                    fontSize: 12,
                    color: precip > 50 ? AppColors.info : AppColors.textTertiary,
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
                  color: wind > 15 ? AppColors.accent : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${wind}mph',
                  style: TextStyle(
                    fontSize: 12,
                    color: wind > 15 ? AppColors.accent : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Temps
          Text(
            '$high°',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$low°',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hunting tools section
class _HuntingTools extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hunting Tools',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ToolCard(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Sunrise',
                  value: '6:42 AM',
                  subtitle: 'Golden hour: 6:12-6:42',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ToolCard(
                  icon: Icons.nightlight_round,
                  title: 'Sunset',
                  value: '5:48 PM',
                  subtitle: 'Golden hour: 5:18-5:48',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ToolCard(
                  icon: Icons.dark_mode_outlined,
                  title: 'Moon Phase',
                  value: 'Waxing Gibbous',
                  subtitle: '67% illuminated',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ToolCard(
                  icon: Icons.pest_control_outlined,
                  title: 'Activity',
                  value: 'Moderate',
                  subtitle: 'Best: 6-9 AM, 4-6 PM',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: _isHovered ? widget.color.withOpacity(0.3) : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),

            // Value
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),

            // Subtitle
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

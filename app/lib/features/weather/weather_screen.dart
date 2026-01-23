import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/location_providers.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🌤️ WEATHER SCREEN - 2025 CINEMATIC DARK THEME
///
/// Premium weather with:
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: _buildHeader(context, isWide),
        ),

        // Location selector
        SliverToBoxAdapter(
          child: _LocationSelector(
            selectedState: _selectedState,
            selectedCounty: _selectedCounty,
            onStateChanged: (state) {
              setState(() {
                _selectedState = state;
                _selectedCounty = null;
              });
            },
            onCountyChanged: (county) {
              setState(() => _selectedCounty = county);
            },
          ),
        ),

        // Weather content
        if (_selectedState != null && _selectedCounty != null) ...[
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
        ] else
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

  Widget _buildHeader(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.only(
        top: isWide ? AppSpacing.xxl : MediaQuery.of(context).padding.top + AppSpacing.lg,
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
                  _selectedState != null && _selectedCounty != null
                      ? '$_selectedCounty, ${_selectedState!.name}'
                      : 'Select a location',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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

/// Location selector with dark theme
class _LocationSelector extends ConsumerWidget {
  const _LocationSelector({
    required this.selectedState,
    required this.selectedCounty,
    required this.onStateChanged,
    required this.onCountyChanged,
  });

  final USState? selectedState;
  final String? selectedCounty;
  final ValueChanged<USState?> onStateChanged;
  final ValueChanged<String?> onCountyChanged;

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
          onStateChanged: onStateChanged,
          onCountyChanged: onCountyChanged,
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
    // Mock hourly data
    final hours = [
      _HourData(time: 'Now', temp: 58, icon: Icons.cloud_outlined, precip: 10, wind: 12),
      _HourData(time: '1PM', temp: 60, icon: Icons.wb_sunny_outlined, precip: 5, wind: 14),
      _HourData(time: '2PM', temp: 62, icon: Icons.wb_sunny_outlined, precip: 0, wind: 15),
      _HourData(time: '3PM', temp: 63, icon: Icons.wb_sunny_outlined, precip: 0, wind: 16),
      _HourData(time: '4PM', temp: 61, icon: Icons.cloud_outlined, precip: 5, wind: 14),
      _HourData(time: '5PM', temp: 58, icon: Icons.cloud_outlined, precip: 15, wind: 12),
      _HourData(time: '6PM', temp: 54, icon: Icons.wb_twilight_rounded, precip: 20, wind: 10),
      _HourData(time: '7PM', temp: 50, icon: Icons.nightlight_round, precip: 25, wind: 8),
      _HourData(time: '8PM', temp: 48, icon: Icons.nightlight_round, precip: 30, wind: 7),
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
                  'Next 9 hours',
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
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              itemCount: hours.length,
              itemBuilder: (context, index) => _HourCard(
                data: hours[index],
                isFirst: index == 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourData {
  const _HourData({
    required this.time,
    required this.temp,
    required this.icon,
    required this.precip,
    required this.wind,
  });

  final String time;
  final int temp;
  final IconData icon;
  final int precip;
  final int wind;
}

class _HourCard extends StatelessWidget {
  const _HourCard({
    required this.data,
    this.isFirst = false,
  });

  final _HourData data;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isFirst ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isFirst ? AppColors.accent.withOpacity(0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time
          Text(
            data.time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isFirst ? FontWeight.w600 : FontWeight.w500,
              color: isFirst ? AppColors.accent : AppColors.textSecondary,
            ),
          ),

          // Icon
          Icon(
            data.icon,
            size: 24,
            color: isFirst ? AppColors.accent : AppColors.textSecondary,
          ),

          // Temperature
          Text(
            '${data.temp}°',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isFirst ? AppColors.accent : AppColors.textPrimary,
            ),
          ),

          // Precip & wind
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 10,
                color: data.precip > 20 ? AppColors.info : AppColors.textTertiary,
              ),
              const SizedBox(width: 2),
              Text(
                '${data.precip}%',
                style: TextStyle(
                  fontSize: 10,
                  color: data.precip > 20 ? AppColors.info : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

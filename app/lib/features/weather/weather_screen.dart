import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/location_providers.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🌤️ WEATHER SCREEN - 2025 PREMIUM
///
/// Weather conditions and hunting tools with accent colors.
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

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Weather & Tools',
            subtitle: _selectedState != null
                ? '${_selectedCounty ?? ''}, ${_selectedState!.name}'
                : 'Select a location',
          ),

        // Content
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Mobile header
              if (!isWide)
                const SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: 'Weather & Tools',
                    subtitle: 'Conditions for your hunt',
                  ),
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
                // Current conditions
                SliverToBoxAdapter(
                  child: _CurrentConditions(),
                ),

                // Wind card
                SliverToBoxAdapter(
                  child: _WindCard(),
                ),

                // Forecast
                SliverToBoxAdapter(
                  child: _ForecastSection(),
                ),

                // Tools section
                SliverToBoxAdapter(
                  child: _ToolsSection(),
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
          ),
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppColors.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Select Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            LocationSelector(
              selectedState: selectedState,
              selectedCounty: selectedCounty,
              onStateChanged: onStateChanged,
              onCountyChanged: onCountyChanged,
            ),
          ],
        ),
      ),
    );
  }
}

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
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.cloud_outlined,
                size: 32,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Select a Location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose your state and county to see weather conditions and hunting tools.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _CurrentConditions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryMuted,
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppColors.shadowCard,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Conditions',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '58°F',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Partly Cloudy',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.cloud_outlined,
                  size: 64,
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ConditionItem(
                  icon: Icons.water_drop_outlined,
                  label: 'Humidity',
                  value: '65%',
                ),
                _ConditionItem(
                  icon: Icons.thermostat_outlined,
                  label: 'Feels Like',
                  value: '55°F',
                ),
                _ConditionItem(
                  icon: Icons.visibility_outlined,
                  label: 'Visibility',
                  value: '10 mi',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionItem extends StatelessWidget {
  const _ConditionItem({
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
        Icon(
          icon,
          size: 20,
          color: Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}

class _WindCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppColors.shadowCard,
        ),
        child: Row(
          children: [
            // Wind compass
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    size: 48,
                    color: AppColors.accent,
                  ),
                  Positioned(
                    top: 8,
                    child: Text(
                      'N',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),

            // Wind info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wind',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        '12 mph',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'NNW',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Gusts up to 18 mph',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5-Day Forecast',
            style: Theme.of(context).textTheme.titleMedium,
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
                _ForecastDay(day: 'Today', high: 58, low: 42, icon: Icons.cloud_outlined),
                const Divider(height: 1),
                _ForecastDay(day: 'Tomorrow', high: 62, low: 45, icon: Icons.wb_sunny_outlined),
                const Divider(height: 1),
                _ForecastDay(day: 'Wednesday', high: 55, low: 38, icon: Icons.grain_outlined),
                const Divider(height: 1),
                _ForecastDay(day: 'Thursday', high: 48, low: 32, icon: Icons.ac_unit_outlined),
                const Divider(height: 1),
                _ForecastDay(day: 'Friday', high: 52, low: 35, icon: Icons.wb_cloudy_outlined),
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
  });

  final String day;
  final int high;
  final int low;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              day,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Icon(
            icon,
            size: 24,
            color: AppColors.textSecondary,
          ),
          const Spacer(),
          Text(
            '$high°',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$low°',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ToolsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hunting Tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ToolCard(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Sun Times',
                  value: '6:42 AM',
                  subtitle: 'Sunrise',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ToolCard(
                  icon: Icons.nightlight_round,
                  title: 'Moon Phase',
                  value: 'Waxing',
                  subtitle: '67% illuminated',
                  color: AppColors.primary,
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
          boxShadow: _isHovered ? AppColors.shadowCard : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: widget.color,
                  ),
            ),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

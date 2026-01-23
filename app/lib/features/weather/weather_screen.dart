import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/premium_dropdown.dart';

/// Weather tab - current conditions, forecast, wind direction.
/// Privacy-safe: uses coarse location (county level) only.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String? _selectedState;
  String? _selectedCounty;

  final _states = ['Texas', 'Alabama', 'Florida', 'Georgia'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather & Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Location selector
          PremiumDropdown<String>(
            label: 'State',
            items: _states,
            value: _selectedState,
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedCounty = null;
              });
            },
            itemLabel: (item) => item,
            hint: 'Select your state',
          ),
          const SizedBox(height: AppSpacing.md),
          
          PremiumDropdown<String>(
            label: 'County',
            items: _selectedState != null
                ? ['${_selectedState!} County 1', '${_selectedState!} County 2']
                : [],
            value: _selectedCounty,
            onChanged: (value) {
              setState(() => _selectedCounty = value);
            },
            itemLabel: (item) => item,
            hint: _selectedState == null ? 'Select state first' : 'Select county',
            enabled: _selectedState != null,
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Current conditions placeholder
          _WeatherCard(
            title: 'Current Conditions',
            subtitle: _selectedCounty ?? 'Select a location',
            child: _selectedCounty != null
                ? _buildCurrentConditions()
                : const _PlaceholderMessage(
                    message: 'Select a state and county to see weather',
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Wind section
          _WeatherCard(
            title: 'Wind',
            child: _selectedCounty != null
                ? _buildWindSection()
                : const _PlaceholderMessage(
                    message: 'Wind direction is critical for hunting success',
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Forecast placeholder
          _WeatherCard(
            title: '5-Day Forecast',
            child: _selectedCounty != null
                ? _buildForecast()
                : const _PlaceholderMessage(
                    message: 'Plan your hunt with the forecast',
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Quick links to other tools
          Text(
            'More Tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          
          _ToolLink(
            icon: Icons.schedule,
            title: 'Activity / Feeding Times',
            subtitle: 'Best windows for deer, turkey, and fishing',
            onTap: () {
              // TODO: Navigate to activity times
            },
          ),
          _ToolLink(
            icon: Icons.analytics,
            title: 'Research / Patterns',
            subtitle: 'Analyze harvest conditions by state & county',
            onTap: () {
              // TODO: Navigate to research dashboard
            },
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Privacy note
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.boneLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip, size: 20, color: AppColors.forest),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Weather is based on county-level location only. We never use or store your exact GPS coordinates.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentConditions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ConditionItem(
              icon: Icons.thermostat,
              value: '52°F',
              label: 'Temperature',
            ),
            _ConditionItem(
              icon: Icons.water_drop,
              value: '45%',
              label: 'Humidity',
            ),
            _ConditionItem(
              icon: Icons.speed,
              value: '30.12',
              label: 'Pressure',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ConditionItem(
              icon: Icons.dark_mode,
              value: 'First Q',
              label: 'Moon',
            ),
            _ConditionItem(
              icon: Icons.wb_sunny,
              value: '6:52 AM',
              label: 'Sunrise',
            ),
            _ConditionItem(
              icon: Icons.nightlight,
              value: '5:38 PM',
              label: 'Sunset',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWindSection() {
    return Row(
      children: [
        // Compass placeholder
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.boneLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderLight, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass points
              ...['N', 'E', 'S', 'W'].asMap().entries.map((entry) {
                final angle = entry.key * 90 * 3.14159 / 180;
                final offset = Offset.fromDirection(angle - 3.14159 / 2, 45);
                return Positioned(
                  left: 60 + offset.dx - 8,
                  top: 60 + offset.dy - 8,
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              }),
              // Wind direction indicator
              Transform.rotate(
                angle: -45 * 3.14159 / 180, // NW
                child: const Icon(
                  Icons.navigation,
                  size: 40,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        
        // Wind details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NW',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Northwest',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoalLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _WindStat(label: 'Speed', value: '8 mph'),
                  const SizedBox(width: AppSpacing.lg),
                  _WindStat(label: 'Gusts', value: '12 mph'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ForecastDay(day: 'Thu', high: '55°', low: '38°', icon: Icons.wb_sunny),
        _ForecastDay(day: 'Fri', high: '58°', low: '42°', icon: Icons.wb_sunny),
        _ForecastDay(day: 'Sat', high: '52°', low: '40°', icon: Icons.cloud),
        _ForecastDay(day: 'Sun', high: '48°', low: '35°', icon: Icons.water_drop),
        _ForecastDay(day: 'Mon', high: '54°', low: '38°', icon: Icons.wb_sunny),
      ],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (subtitle != null) ...[
                const Spacer(),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _PlaceholderMessage extends StatelessWidget {
  const _PlaceholderMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.charcoalLight,
        ),
      ),
    );
  }
}

class _ConditionItem extends StatelessWidget {
  const _ConditionItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.forest),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _WindStat extends StatelessWidget {
  const _WindStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
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
  final String high;
  final String low;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(day, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Icon(icon, color: AppColors.charcoalLight),
        const SizedBox(height: AppSpacing.xs),
        Text(high, style: Theme.of(context).textTheme.titleSmall),
        Text(
          low,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.charcoalLight,
          ),
        ),
      ],
    );
  }
}

class _ToolLink extends StatelessWidget {
  const _ToolLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.forestLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: AppColors.forest),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

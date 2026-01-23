import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_states.dart';
import '../../shared/widgets/animated_entry.dart';

/// 🌤️ MODERN WEATHER & TOOLS SCREEN
/// 
/// Features:
/// - Accent color usage for visual hierarchy
/// - Cards with real hierarchy
/// - Meaningful icons (not decorative)
/// - Privacy-safe county-level data
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  USState? _selectedState;
  String? _selectedCounty;

  bool get _hasLocation => _selectedCounty != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Weather & Tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Location selector
                _LocationSelector(
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
                const SizedBox(height: 24),

                // Current conditions
                if (_hasLocation) ...[
                  AnimatedEntry(
                    child: _CurrentConditions(),
                  ),
                  const SizedBox(height: 16),
                  AnimatedEntry(
                    delay: const Duration(milliseconds: 60),
                    child: _WindCard(),
                  ),
                  const SizedBox(height: 16),
                  AnimatedEntry(
                    delay: const Duration(milliseconds: 120),
                    child: _ForecastCard(),
                  ),
                ] else
                  AnimatedEntry(child: _LocationPrompt()),

                const SizedBox(height: 32),

                // Tools section
                _SectionHeader(title: 'Hunting Tools'),
                const SizedBox(height: 12),
                _ToolCard(
                  icon: Icons.schedule_rounded,
                  title: 'Activity & Feeding Times',
                  subtitle: 'Best windows for deer, turkey, and fishing',
                  color: AppColors.accent,
                  onTap: () {},
                ),
                _ToolCard(
                  icon: Icons.insights_rounded,
                  title: 'Research & Patterns',
                  subtitle: 'Analyze harvest conditions by region',
                  color: AppColors.primary,
                  onTap: () {},
                ),
                _ToolCard(
                  icon: Icons.dark_mode_rounded,
                  title: 'Moon Phase Calendar',
                  subtitle: 'Plan around lunar cycles',
                  color: AppColors.secondary,
                  onTap: () {},
                ),
                const SizedBox(height: 24),

                // Privacy notice
                _PrivacyNotice(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Your Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DropdownButton(
                  label: 'State',
                  value: selectedState?.name,
                  hint: 'Select state',
                  onTap: () => _showStatePicker(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DropdownButton(
                  label: 'County',
                  value: selectedCounty,
                  hint: selectedState == null ? 'Select state first' : 'Select county',
                  enabled: selectedState != null,
                  onTap: () => _showCountyPicker(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StatePickerSheet(
        selectedState: selectedState,
        onSelected: (state) {
          onStateChanged(state);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCountyPicker(BuildContext context) {
    if (selectedState == null) return;
    // TODO: Show county picker
  }
}

class _DropdownButton extends StatelessWidget {
  const _DropdownButton({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.primary.withOpacity(0.06),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? hint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CURRENT CONDITIONS
// ═══════════════════════════════════════════════════════════════════════════════

class _CurrentConditions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Conditions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ConditionItem(
                icon: Icons.thermostat_rounded,
                value: '52°F',
                label: 'Temp',
                color: AppColors.accent,
              ),
              _ConditionItem(
                icon: Icons.water_drop_rounded,
                value: '45%',
                label: 'Humidity',
                color: AppColors.categoryBass,
              ),
              _ConditionItem(
                icon: Icons.speed_rounded,
                value: '30.12',
                label: 'Pressure',
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ConditionItem(
                icon: Icons.dark_mode_rounded,
                value: 'First Q',
                label: 'Moon',
                color: AppColors.secondary,
              ),
              _ConditionItem(
                icon: Icons.wb_sunny_rounded,
                value: '6:52 AM',
                label: 'Sunrise',
                color: AppColors.warning,
              ),
              _ConditionItem(
                icon: Icons.nightlight_rounded,
                value: '5:38 PM',
                label: 'Sunset',
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionItem extends StatelessWidget {
  const _ConditionItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIND CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _WindCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wind',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Compass
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Direction labels
                    Positioned(top: 8, child: _compassLabel('N')),
                    Positioned(bottom: 8, child: _compassLabel('S')),
                    Positioned(left: 8, child: _compassLabel('W')),
                    Positioned(right: 8, child: _compassLabel('E')),
                    // Arrow
                    Transform.rotate(
                      angle: -0.785, // NW
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 32,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Wind details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'NW',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Favorable',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Northwest',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _WindStat(label: 'Speed', value: '8 mph'),
                        const SizedBox(width: 24),
                        _WindStat(label: 'Gusts', value: '12 mph'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compassLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _WindStat extends StatelessWidget {
  const _WindStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORECAST CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ForecastCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5-Day Forecast',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ForecastDay(day: 'Thu', high: '55°', low: '38°', icon: Icons.wb_sunny_rounded, color: AppColors.warning),
              _ForecastDay(day: 'Fri', high: '58°', low: '42°', icon: Icons.wb_sunny_rounded, color: AppColors.warning),
              _ForecastDay(day: 'Sat', high: '52°', low: '40°', icon: Icons.cloud_rounded, color: AppColors.textTertiary),
              _ForecastDay(day: 'Sun', high: '48°', low: '35°', icon: Icons.water_drop_rounded, color: AppColors.categoryBass),
              _ForecastDay(day: 'Mon', high: '54°', low: '38°', icon: Icons.wb_sunny_rounded, color: AppColors.warning),
            ],
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
    required this.color,
  });

  final String day;
  final String high;
  final String low;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          day,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          high,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          low,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOOL CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            hoverColor: widget.color.withOpacity(0.06),
            splashColor: widget.color.withOpacity(0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered 
                      ? widget.color.withOpacity(0.3) 
                      : AppColors.border.withOpacity(0.5),
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(_isHovered ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _isHovered ? widget.color : AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION PROMPT
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a Location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your state and county above to view weather conditions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVACY NOTICE
// ═══════════════════════════════════════════════════════════════════════════════

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Weather is based on county-level location only. We never use or store your exact GPS coordinates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _StatePickerSheet extends StatefulWidget {
  const _StatePickerSheet({
    required this.selectedState,
    required this.onSelected,
  });

  final USState? selectedState;
  final ValueChanged<USState> onSelected;

  @override
  State<_StatePickerSheet> createState() => _StatePickerSheetState();
}

class _StatePickerSheetState extends State<_StatePickerSheet> {
  final _searchController = TextEditingController();
  List<USState> _filteredStates = USStates.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStates() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStates = USStates.all
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select State',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search states...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredStates.length,
              itemBuilder: (context, index) {
                final state = _filteredStates[index];
                final isSelected = state == widget.selectedState;
                return ListTile(
                  title: Text(state.name),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => widget.onSelected(state),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

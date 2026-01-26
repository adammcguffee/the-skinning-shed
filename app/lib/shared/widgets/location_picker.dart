import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/county_centroids.dart';
import '../../data/us_states.dart';

/// 📍 UNIFIED LOCATION PICKER COMPONENTS
///
/// Use these components for ALL state/county selection in the app:
/// - Post Trophy
/// - Weather & Tools
/// - Land listings
/// - Explore filters
/// - Any future location-based features
///
/// Now uses Census Gazetteer data for full US county coverage (3200+ counties).
/// Each county has a FIPS code (5-digit GEOID) for precise identification.

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTED COUNTY MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Selected county with FIPS code for precise identification.
class SelectedCounty {
  const SelectedCounty({
    required this.name,
    required this.fips,
  });
  
  /// Display name (e.g., "Travis County").
  final String name;
  
  /// 5-digit FIPS code (GEOID).
  final String fips;
  
  @override
  String toString() => name;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedCounty && fips == other.fips;
  
  @override
  int get hashCode => fips.hashCode;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION SELECTOR WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

/// Combined state + county selector widget.
/// 
/// For new code, use [onCountyChangedWithFips] to get the FIPS code.
/// [onCountyChanged] is retained for backward compatibility.
class LocationSelector extends StatelessWidget {
  const LocationSelector({
    super.key,
    required this.selectedState,
    required this.selectedCounty,
    required this.onStateChanged,
    required this.onCountyChanged,
    this.selectedCountyFips,
    this.onCountyChangedWithFips,
    this.stateLabel = 'State',
    this.countyLabel = 'County',
    this.stateHint = 'Select state',
    this.countyHint = 'Select county',
    this.countyDisabledHint = 'Select state first',
    this.showLabels = true,
    this.direction = Axis.horizontal,
  });

  final USState? selectedState;
  final String? selectedCounty;
  final String? selectedCountyFips;
  final ValueChanged<USState?> onStateChanged;
  final ValueChanged<String?> onCountyChanged;
  /// New callback that provides both name and FIPS code.
  final ValueChanged<SelectedCounty?>? onCountyChangedWithFips;
  final String stateLabel;
  final String countyLabel;
  final String stateHint;
  final String countyHint;
  final String countyDisabledHint;
  final bool showLabels;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final stateField = _LocationField(
      label: showLabels ? stateLabel : null,
      value: selectedState?.name,
      hint: stateHint,
      onTap: () => _showStatePicker(context),
    );

    final countyField = _LocationField(
      label: showLabels ? countyLabel : null,
      value: selectedCounty,
      hint: selectedState == null ? countyDisabledHint : countyHint,
      enabled: selectedState != null,
      onTap: () => _showCountyPicker(context),
    );

    if (direction == Axis.horizontal) {
      return Row(
        children: [
          Expanded(child: stateField),
          const SizedBox(width: 12),
          Expanded(child: countyField),
        ],
      );
    } else {
      return Column(
        children: [
          stateField,
          const SizedBox(height: 12),
          countyField,
        ],
      );
    }
  }

  void _showStatePicker(BuildContext context) {
    showModalBottomSheet<USState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true, // Ensures modal sits above entire app shell
      builder: (context) => StatePickerSheet(
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
    showModalBottomSheet<SelectedCounty>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true, // Ensures modal sits above entire app shell
      builder: (context) => CountyPickerSheet(
        stateCode: selectedState!.code,
        selectedCountyFips: selectedCountyFips,
        onSelected: (county) {
          // Call both callbacks for compatibility
          onCountyChanged(county.name);
          onCountyChangedWithFips?.call(county);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.value,
    required this.hint,
    required this.onTap,
    this.label,
    this.enabled = true,
  });

  final String? label;
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          // Use dark surface for dark theme compatibility
          color: enabled ? AppColors.surfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.borderStrong : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (label != null) const SizedBox(height: 2),
                  Text(
                    value ?? hint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      // High contrast: white for selected value, muted for hint
                      color: value != null 
                          ? Colors.white 
                          : AppColors.textTertiary,
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════════

/// Searchable bottom sheet for selecting a US state
class StatePickerSheet extends StatefulWidget {
  const StatePickerSheet({
    super.key,
    required this.selectedState,
    required this.onSelected,
  });

  final USState? selectedState;
  final ValueChanged<USState> onSelected;

  @override
  State<StatePickerSheet> createState() => _StatePickerSheetState();
}

class _StatePickerSheetState extends State<StatePickerSheet> {
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
      _filteredStates = query.isEmpty
          ? USStates.all
          : USStates.all.where((s) =>
              s.name.toLowerCase().contains(query) ||
              s.code.toLowerCase().contains(query)).toList();
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
                    fillColor: AppColors.backgroundAlt,
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
                  subtitle: Text(state.code),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  tileColor: isSelected ? AppColors.primary.withOpacity(0.05) : null,
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

// ═══════════════════════════════════════════════════════════════════════════════
// COUNTY PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════════

/// Searchable bottom sheet for selecting a county within a state.
/// Uses Census Gazetteer data for full US coverage (3200+ counties).
class CountyPickerSheet extends StatefulWidget {
  const CountyPickerSheet({
    super.key,
    required this.stateCode,
    required this.selectedCountyFips,
    required this.onSelected,
  });

  final String stateCode;
  final String? selectedCountyFips;
  final ValueChanged<SelectedCounty> onSelected;

  @override
  State<CountyPickerSheet> createState() => _CountyPickerSheetState();
}

class _CountyPickerSheetState extends State<CountyPickerSheet> {
  final _searchController = TextEditingController();
  List<CountyData> _allCounties = [];
  List<CountyData> _filteredCounties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounties();
    _searchController.addListener(_filterCounties);
  }

  Future<void> _loadCounties() async {
    final centroids = CountyCentroids.instance;
    await centroids.ensureLoaded();
    
    if (mounted) {
      setState(() {
        _allCounties = centroids.getCountiesForState(widget.stateCode);
        _filteredCounties = _allCounties;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCounties() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCounties = query.isEmpty
          ? _allCounties
          : _allCounties.where((c) => 
              c.name.toLowerCase().contains(query) ||
              c.normalizedName.contains(query)
            ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateName = USStates.byCode(widget.stateCode)?.name ?? widget.stateCode;

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
                  'Select County',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading 
                      ? 'Loading...'
                      : '$stateName • ${_allCounties.length} counties',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search counties...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.backgroundAlt,
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  )
                : _filteredCounties.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No counties found',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCounties.length,
                        itemBuilder: (context, index) {
                          final county = _filteredCounties[index];
                          final isSelected = county.fips == widget.selectedCountyFips;
                          return ListTile(
                            title: Text(county.name),
                            // No FIPS subtitle - just show county name
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primary)
                                : null,
                            tileColor: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                            onTap: () => widget.onSelected(SelectedCounty(
                              name: county.name,
                              fips: county.fips,
                            )),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/widgets.dart';

/// Main feed showing latest trophies.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Skinning Shed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilters(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh feed
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  _CategoryChip(label: 'All', isSelected: true),
                  _CategoryChip(label: 'Deer', icon: '🦌'),
                  _CategoryChip(label: 'Turkey', icon: '🦃'),
                  _CategoryChip(label: 'Bass', icon: '🐟'),
                  _CategoryChip(label: 'Other Game'),
                  _CategoryChip(label: 'Other Fishing'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Placeholder trophy cards
            _buildPlaceholderCard(
              context,
              species: 'Deer',
              speciesIcon: '🦌',
              location: 'Texas • Travis County',
              date: 'Jan 15, 2026',
              stats: '142" • Rifle • 8pt',
              temp: '52°F',
              wind: 'NW 8mph',
            ),
            _buildPlaceholderCard(
              context,
              species: 'Turkey',
              speciesIcon: '🦃',
              location: 'Alabama • Jefferson County',
              date: 'Jan 12, 2026',
              stats: '22 lbs • 10" beard',
              temp: '58°F',
              wind: 'S 5mph',
            ),
            _buildPlaceholderCard(
              context,
              species: 'Bass',
              speciesIcon: '🐟',
              location: 'Florida • Lake County',
              date: 'Jan 10, 2026',
              stats: '8.2 lbs • 22"',
              temp: '72°F',
              wind: 'E 3mph',
            ),
            
            // Empty state message
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                'More trophies will appear here once users start posting!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.charcoalLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(),
    );
  }

  Widget _buildPlaceholderCard(
    BuildContext context, {
    required String species,
    required String speciesIcon,
    required String location,
    required String date,
    required String stats,
    required String temp,
    required String wind,
  }) {
    return PremiumCard(
      placeholder: Container(
        color: AppColors.boneLight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(speciesIcon, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'Photo placeholder',
                style: TextStyle(color: AppColors.charcoalLight),
              ),
            ],
          ),
        ),
      ),
      title: '$speciesIcon $species Trophy',
      subtitle: location,
      metadata: StatsStrip(
        items: [
          StatsStripItem(label: date, icon: Icons.calendar_today),
          StatsStripItem(label: temp, icon: Icons.thermostat),
          StatsStripItem(label: wind, icon: Icons.air),
          StatsStripItem(label: stats),
        ],
      ),
      onTap: () {
        // TODO: Navigate to trophy detail
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.icon,
    this.isSelected = false,
  });

  final String label;
  final String? icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(icon != null ? '$icon $label' : label),
        selected: isSelected,
        onSelected: (selected) {
          // TODO: Filter by category
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.forestLight.withOpacity(0.2),
        checkmarkColor: AppColors.forest,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.forest : AppColors.charcoal,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(
            color: isSelected ? AppColors.forest : AppColors.borderLight,
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Placeholder dropdowns
              PremiumDropdown<String>(
                label: 'State',
                items: const ['Texas', 'Alabama', 'Florida', 'Georgia'],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'All States',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<String>(
                label: 'County',
                items: const [],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'All Counties',
                enabled: false,
                hint: 'Select a state first',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<String>(
                label: 'Species',
                items: const ['Deer', 'Turkey', 'Bass', 'Other Game', 'Other Fishing'],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'All Species',
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              PremiumButton(
                label: 'Apply Filters',
                onPressed: () => Navigator.pop(context),
                isExpanded: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

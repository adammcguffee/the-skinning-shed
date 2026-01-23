import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Explore screen for browsing species hubs, states, and discovery.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Species Hubs section
          _SectionHeader(title: 'Species Hubs'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              _SpeciesHub(
                icon: '🦌',
                label: 'Deer',
                color: AppColors.speciesDeer,
                onTap: () {},
              ),
              _SpeciesHub(
                icon: '🦃',
                label: 'Turkey',
                color: AppColors.speciesTurkey,
                onTap: () {},
              ),
              _SpeciesHub(
                icon: '🐟',
                label: 'Bass',
                color: AppColors.speciesBass,
                onTap: () {},
              ),
              _SpeciesHub(
                icon: '🎯',
                label: 'Other Game',
                color: AppColors.speciesOtherGame,
                onTap: () {},
              ),
              _SpeciesHub(
                icon: '🎣',
                label: 'Other Fishing',
                color: AppColors.speciesOtherFishing,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // Quick Links section
          _SectionHeader(title: 'Quick Links'),
          const SizedBox(height: AppSpacing.md),
          _QuickLink(
            icon: Icons.terrain,
            label: 'Land for Lease',
            onTap: () => context.go('/land'),
          ),
          _QuickLink(
            icon: Icons.sell,
            label: 'Land for Sale',
            onTap: () => context.go('/land'),
          ),
          _QuickLink(
            icon: Icons.swap_horiz,
            label: 'The Swap Shop',
            onTap: () => context.go('/swap-shop'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // Browse by State section
          _SectionHeader(title: 'Browse by State'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              'Texas', 'Alabama', 'Florida', 'Georgia', 'Tennessee',
              'Arkansas', 'Louisiana', 'Mississippi', 'Oklahoma', 'Missouri',
            ].map((state) {
              return ActionChip(
                label: Text(state),
                onPressed: () {},
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.borderLight),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {},
            child: const Text('View all states →'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _SpeciesHub extends StatelessWidget {
  const _SpeciesHub({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

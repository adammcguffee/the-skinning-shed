import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Trophy detail screen showing full trophy information.
class TrophyDetailScreen extends StatelessWidget {
  const TrophyDetailScreen({
    super.key,
    required this.trophyId,
  });

  final String trophyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image with app bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.surfaceAlt,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🦌', style: TextStyle(fontSize: 64)),
                      SizedBox(height: 8),
                      Text(
                        'Trophy Photo',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Share trophy
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  // TODO: More options
                },
              ),
            ],
          ),
          
          // Trophy content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Species and location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.categoryDeer.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        child: Text(
                          '🦌 Deer',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.categoryDeer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const _ReactionButton(
                        icon: Icons.favorite_border,
                        label: 'Respect',
                        count: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppColors.textTertiary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Texas • Travis County',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  
                  // Dates
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.textTertiary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Harvested: Jan 15, 2026 • Morning',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Weather conditions at harvest
                  _SectionCard(
                    title: 'Conditions at Harvest',
                    icon: Icons.cloud,
                    child: Column(
                      children: [
                        _ConditionRow(label: 'Temperature', value: '52°F'),
                        _ConditionRow(label: 'Wind', value: 'NW at 8 mph'),
                        _ConditionRow(label: 'Moon Phase', value: 'First Quarter'),
                        _ConditionRow(label: 'Pressure', value: '30.12 inHg (Rising)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Stats
                  _SectionCard(
                    title: 'Trophy Stats',
                    icon: Icons.bar_chart,
                    child: Column(
                      children: [
                        _ConditionRow(label: 'Score', value: '142"'),
                        _ConditionRow(label: 'Points', value: '8'),
                        _ConditionRow(label: 'Weapon', value: 'Rifle'),
                        _ConditionRow(label: 'Distance', value: '120 yards'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Story
                  _SectionCard(
                    title: 'The Story',
                    icon: Icons.auto_stories,
                    child: Text(
                      'This is where the hunter\'s story about the harvest would appear. '
                      'They can share the experience, the setup, and any memorable moments from the hunt.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // User info
                  _UserTile(),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        // TODO: React to trophy
      },
      icon: Icon(icon, size: 20),
      label: Text('$label ($count)'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryContainer.withOpacity(0.2),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hunter Name',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Posted Jan 15, 2026',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              // TODO: View trophy wall
            },
            child: const Text('View Wall'),
          ),
        ],
      ),
    );
  }
}

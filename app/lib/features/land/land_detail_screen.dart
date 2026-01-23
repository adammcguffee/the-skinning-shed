import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/premium_button.dart';

/// Land listing detail screen.
class LandDetailScreen extends StatelessWidget {
  const LandDetailScreen({
    super.key,
    required this.listingId,
  });

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.boneLight,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.terrain, size: 64, color: AppColors.forest),
                      SizedBox(height: 8),
                      Text(
                        'Property Photo',
                        style: TextStyle(color: AppColors.charcoalLight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
            ],
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      'FOR LEASE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Title
                  Text(
                    '150 Acres Hill Country Ranch',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppColors.charcoalLight),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Texas • Travis County',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoalLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Price and details row
                  Row(
                    children: [
                      Expanded(
                        child: _DetailBox(
                          label: 'Price',
                          value: '\$2,500/year',
                          icon: Icons.attach_money,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _DetailBox(
                          label: 'Acreage',
                          value: '150 acres',
                          icon: Icons.square_foot,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Species present
                  Text(
                    'Species Present',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: ['Whitetail Deer', 'Turkey', 'Hog', 'Dove'].map((s) {
                      return Chip(
                        label: Text(s),
                        backgroundColor: AppColors.forestLight.withOpacity(0.1),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Beautiful 150-acre ranch in the heart of Texas Hill Country. '
                    'Excellent deer and turkey hunting. Property features multiple '
                    'food plots, blinds, and feeders. Creek runs through property. '
                    'Cabin available for overnight stays.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Discovery only. The Skinning Shed does not handle contracts or payments.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: PremiumButton(
            label: 'Contact Owner',
            onPressed: () {
              // TODO: Show contact options
            },
            icon: Icons.mail_outline,
            isExpanded: true,
          ),
        ),
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  const _DetailBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.charcoalLight),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

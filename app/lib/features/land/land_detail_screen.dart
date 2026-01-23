import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏞️ LAND DETAIL SCREEN - 2025 PREMIUM
class LandDetailScreen extends StatelessWidget {
  const LandDetailScreen({super.key, required this.landId});

  final String landId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.white),
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.bookmark_outline_rounded, color: Colors.white),
                ),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.backgroundAlt,
                child: const Center(
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            '\$2,500/season',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.textInverse,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Title
                        Text(
                          '500 Acre Deer Lease',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hill Country, Texas',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Row(
                      children: [
                        _StatItem(
                          icon: Icons.straighten_outlined,
                          label: '500 acres',
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _StatItem(
                          icon: Icons.people_outline_rounded,
                          label: '4 hunters max',
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _StatItem(
                          icon: Icons.calendar_today_outlined,
                          label: 'Full season',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Game available
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Game Available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppCategoryChip(category: 'Whitetail'),
                            AppCategoryChip(category: 'Turkey'),
                            AppChip(label: 'Hog'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Beautiful 500-acre property in the heart of Texas Hill Country. Excellent whitetail deer population with multiple mature bucks on camera. Property features rolling hills, oak motts, and several food plots. Includes a comfortable cabin with AC/heat, running water, and electricity. Perfect for a small group of serious hunters.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Amenities
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amenities',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _AmenityItem(icon: Icons.cabin_rounded, label: 'Cabin'),
                        _AmenityItem(icon: Icons.water_drop_outlined, label: 'Running water'),
                        _AmenityItem(icon: Icons.bolt_outlined, label: 'Electricity'),
                        _AmenityItem(icon: Icons.local_parking_outlined, label: 'Parking'),
                        _AmenityItem(icon: Icons.grass_outlined, label: 'Food plots'),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Contact
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: AppSurface(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Listed by John Smith',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  'Member since 2022',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          AppButtonPrimary(
                            label: 'Contact',
                            icon: Icons.message_outlined,
                            onPressed: () {},
                            size: AppButtonSize.small,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _AmenityItem extends StatelessWidget {
  const _AmenityItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

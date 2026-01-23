import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🛒 SWAP SHOP SCREEN - 2025 PREMIUM
class SwapShopScreen extends StatelessWidget {
  const SwapShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Swap Shop'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            // Categories
            SliverToBoxAdapter(
              child: _CategoriesSection(),
            ),

            // Listings
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  mainAxisSpacing: AppSpacing.gridGap,
                  crossAxisSpacing: AppSpacing.gridGap,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ListingCard(index: index),
                  childCount: 6,
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = [
      ('All', Icons.grid_view_rounded),
      ('Firearms', Icons.gps_fixed_rounded),
      ('Bows', Icons.sports_rounded),
      ('Gear', Icons.backpack_rounded),
      ('Clothing', Icons.checkroom_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: categories.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: AppChip(
              label: entry.value.$1,
              icon: entry.value.$2,
              isSelected: isFirst,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ListingCard extends StatefulWidget {
  const _ListingCard({required this.index});

  final int index;

  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final listings = [
      ('Compound Bow', '\$450', 'Like new'),
      ('Trail Camera', '\$85', 'Great condition'),
      ('Hunting Boots', '\$120', 'Size 11'),
      ('Tree Stand', '\$200', 'Barely used'),
      ('Rifle Scope', '\$350', '3-9x40'),
      ('Camo Jacket', '\$75', 'XL'),
    ];

    final listing = listings[widget.index % listings.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -4.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Container(
                  color: AppColors.backgroundAlt,
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.$1,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        listing.$3,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        listing.$2,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_states.dart';
import '../../shared/widgets/widgets.dart';

/// The Swap Shop - buy/sell/trade classifieds.
class SwapShopScreen extends StatelessWidget {
  const SwapShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Swap Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context),
          ),
        ],
      ),
      body: ListView(
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
                _CategoryChip(label: 'Firearms'),
                _CategoryChip(label: 'Bows'),
                _CategoryChip(label: 'Fishing Gear'),
                _CategoryChip(label: 'Clothing'),
                _CategoryChip(label: 'Other'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Disclaimer banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppColors.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Discovery only. Contact sellers directly. No payments handled.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Listings
          _buildPlaceholderListing(
            context,
            title: 'Compound Bow - Like New',
            category: 'Bows',
            price: '\$350',
            location: 'Texas • Dallas County',
          ),
          _buildPlaceholderListing(
            context,
            title: 'Hunting Blind',
            category: 'Equipment',
            price: '\$200',
            location: 'Alabama • Mobile County',
          ),
          _buildPlaceholderListing(
            context,
            title: 'Bass Boat Trolling Motor',
            category: 'Fishing Gear',
            price: '\$150',
            location: 'Florida • Orange County',
          ),
          
          // Empty state
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'More listings coming soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
      floatingActionButton: PremiumFAB(
        icon: Icons.add,
        label: 'Post Listing',
        isExtended: true,
        onPressed: () {
          // TODO: Create swap shop listing
        },
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SwapShopFilterSheet(),
    );
  }

  Widget _buildPlaceholderListing(
    BuildContext context, {
    required String title,
    required String category,
    required String price,
    required String location,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.cardMargin,
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to listing detail
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                ),
                child: const Icon(
                  Icons.image,
                  size: 32,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.isSelected = false,
  });

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {},
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryContainer.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _SwapShopFilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusModal),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              Text(
                'Filter Listings',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              PremiumDropdown<String>(
                label: 'Category',
                items: const ['Firearms', 'Bows', 'Fishing Gear', 'Clothing', 'Other'],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'All Categories',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<USState>(
                label: 'State',
                items: USStates.all,
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item.name,
                allOptionLabel: 'All States',
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

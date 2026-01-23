import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_states.dart';
import '../../shared/widgets/widgets.dart';

/// Land listings screen (Lease and Sale).
class LandScreen extends StatefulWidget {
  const LandScreen({super.key});

  @override
  State<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends State<LandScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Land'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'For Lease'),
            Tab(text: 'For Sale'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilters(context);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LandListingsList(type: 'lease'),
          _LandListingsList(type: 'sale'),
        ],
      ),
      floatingActionButton: PremiumFAB(
        icon: Icons.add,
        label: 'List Property',
        isExtended: true,
        onPressed: () {
          // TODO: Create land listing
        },
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LandFilterSheet(),
    );
  }
}

class _LandListingsList extends StatelessWidget {
  const _LandListingsList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        _buildPlaceholderListing(
          context,
          title: '150 Acres ${type == 'lease' ? 'Hunting Lease' : 'For Sale'}',
          location: 'Texas • Hill Country',
          price: type == 'lease' ? '\$2,500/year' : '\$450,000',
          acreage: '150 acres',
          species: ['Deer', 'Turkey', 'Hog'],
        ),
        _buildPlaceholderListing(
          context,
          title: '80 Acres ${type == 'lease' ? 'Hunting Lease' : 'For Sale'}',
          location: 'Alabama • Baldwin County',
          price: type == 'lease' ? '\$1,200/year' : '\$180,000',
          acreage: '80 acres',
          species: ['Deer', 'Turkey'],
        ),
        
        // Empty state message
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'More land listings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderListing(
    BuildContext context, {
    required String title,
    required String location,
    required String price,
    required String acreage,
    required List<String> species,
  }) {
    return PremiumCard(
      placeholder: Container(
        color: AppColors.surfaceAlt,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.terrain, size: 48, color: AppColors.primary),
              SizedBox(height: 8),
              Text(
                'Property Photo',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
      aspectRatio: 16 / 9,
      title: title,
      subtitle: location,
      metadata: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsStrip(
            items: [
              StatsStripItem(label: price, icon: Icons.attach_money),
              StatsStripItem(label: acreage, icon: Icons.square_foot),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: species.map((s) {
              return Chip(
                label: Text(s),
                labelStyle: const TextStyle(fontSize: 11),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.primaryContainer.withOpacity(0.1),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ),
      onTap: () {
        // TODO: Navigate to land detail
      },
    );
  }
}

class _LandFilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
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
                'Filter Land Listings',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              PremiumDropdown<USState>(
                label: 'State',
                items: USStates.all,
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item.name,
                allOptionLabel: 'All States',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<String>(
                label: 'Price Range',
                items: const [
                  'Under \$100k',
                  '\$100k - \$250k',
                  '\$250k - \$500k',
                  'Over \$500k',
                ],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'Any Price',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<String>(
                label: 'Acreage',
                items: const [
                  'Under 50 acres',
                  '50-100 acres',
                  '100-250 acres',
                  'Over 250 acres',
                ],
                value: null,
                onChanged: (value) {},
                itemLabel: (item) => item,
                allOptionLabel: 'Any Size',
              ),
              const SizedBox(height: AppSpacing.lg),
              
              Text(
                'Species Present',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: ['Deer', 'Turkey', 'Hog', 'Bass', 'Duck'].map((species) {
                  return FilterChip(
                    label: Text(species),
                    selected: false,
                    onSelected: (selected) {},
                  );
                }).toList(),
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

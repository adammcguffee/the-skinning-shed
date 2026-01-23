import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏞️ LAND SCREEN - 2025 PREMIUM
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: BannerHeader.appTop(),
          ),
        ),

        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Land Listings',
            subtitle: 'Find hunting land',
            onSearch: () {},
            onFilter: () {},
          ),

        // Content
        Expanded(
          child: Column(
            children: [
              // Mobile header
              if (!isWide)
                const AppPageHeader(
                  title: 'Land Listings',
                  subtitle: 'Find hunting land',
                ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: AppColors.shadowCard,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: Theme.of(context).textTheme.labelLarge,
                  tabs: const [
                    Tab(text: 'For Lease'),
                    Tab(text: 'For Sale'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LandList(type: 'lease', isWide: isWide),
                    _LandList(type: 'sale', isWide: isWide),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandList extends StatelessWidget {
  const _LandList({
    required this.type,
    required this.isWide,
  });

  final String type;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    // Demo data
    final listings = [
      _LandListing(
        title: '500 Acre Deer Lease',
        location: 'Hill Country, TX',
        price: type == 'lease' ? '\$2,500/season' : '\$1,250,000',
        acres: 500,
        features: ['Whitetail', 'Turkey', 'Hog'],
      ),
      _LandListing(
        title: 'Premium Duck Hunting',
        location: 'East Texas',
        price: type == 'lease' ? '\$1,800/season' : '\$850,000',
        acres: 320,
        features: ['Waterfowl', 'Deer'],
      ),
      _LandListing(
        title: 'Family Hunting Ranch',
        location: 'South Texas',
        price: type == 'lease' ? '\$3,200/season' : '\$2,100,000',
        acres: 750,
        features: ['Whitetail', 'Exotics', 'Turkey'],
      ),
    ];

    if (listings.isEmpty) {
      return AppEmptyState(
        icon: Icons.landscape_outlined,
        title: 'No listings yet',
        message: 'Check back soon for new land listings.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      itemCount: listings.length,
      itemBuilder: (context, index) => _LandCard(
        listing: listings[index],
        onTap: () => context.push('/land/demo-$index'),
      ),
    );
  }
}

class _LandListing {
  const _LandListing({
    required this.title,
    required this.location,
    required this.price,
    required this.acres,
    required this.features,
  });

  final String title;
  final String location;
  final String price;
  final int acres;
  final List<String> features;
}

class _LandCard extends StatefulWidget {
  const _LandCard({
    required this.listing,
    required this.onTap,
  });

  final _LandListing listing;
  final VoidCallback onTap;

  @override
  State<_LandCard> createState() => _LandCardState();
}

class _LandCardState extends State<_LandCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
              // Image placeholder
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: AppColors.backgroundAlt,
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.landscape_outlined,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      // Price badge
                      Positioned(
                        top: AppSpacing.md,
                        right: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            widget.listing.price,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textInverse,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.listing.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.listing.location,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Icon(
                          Icons.straighten_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.listing.acres} acres',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: widget.listing.features
                          .map((f) => AppChip(
                                label: f,
                                size: AppChipSize.small,
                              ))
                          .toList(),
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

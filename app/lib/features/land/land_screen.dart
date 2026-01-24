import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/land_listing_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏞️ LAND SCREEN - 2025 PREMIUM
/// 
/// Browse land listings with filters for lease/sale, location, and more.
class LandScreen extends ConsumerStatefulWidget {
  const LandScreen({super.key});

  @override
  ConsumerState<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends ConsumerState<LandScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFilters = false;
  LandSortBy _sortBy = LandSortBy.newest;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Load initial data
    Future.microtask(() => _loadListings('lease'));
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final type = _tabController.index == 0 ? 'lease' : 'sale';
      _loadListings(type);
    }
  }

  void _loadListings(String type) {
    final params = LandSearchParams(
      type: type,
      sortBy: _sortBy,
    );
    
    ref.read(landListingsNotifierProvider.notifier).fetchListings(params: params);
  }

  void _onSortChanged(LandSortBy sort) {
    setState(() {
      _sortBy = sort;
    });
    final type = _tabController.index == 0 ? 'lease' : 'sale';
    _loadListings(type);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;
    final listingsState = ref.watch(landListingsNotifierProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Land Listings',
            subtitle: 'Find hunting land',
            onSearch: () {
              setState(() => _showFilters = !_showFilters);
            },
            onFilter: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),

        // Content
        Expanded(
          child: Column(
            children: [
              // Mobile header
              if (!isWide)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Land Listings',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find hunting land for lease or sale',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Filter toggle
                      _FilterToggle(
                        isActive: _showFilters,
                        onTap: () => setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: AppSpacing.lg),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
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
              
              // Filters panel
              if (_showFilters) ...[
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: _FiltersPanel(
                    sortBy: _sortBy,
                    onSortChanged: _onSortChanged,
                  ),
                ),
              ],
              
              const SizedBox(height: AppSpacing.lg),

              // Tab content
              Expanded(
                child: listingsState.isLoading
                    ? _buildLoadingState()
                    : listingsState.error != null
                        ? AppErrorState(
                            message: listingsState.error!,
                            onRetry: () {
                              final type = _tabController.index == 0 ? 'lease' : 'sale';
                              _loadListings(type);
                            },
                          )
                        : listingsState.listings.isEmpty
                            ? AppEmptyState(
                                icon: Icons.landscape_outlined,
                                title: 'No listings yet',
                                message: 'Be the first to list hunting land!',
                                actionLabel: 'Create Listing',
                                onAction: () => context.push('/land/create'),
                              )
                            : _buildListingsList(listingsState.listings, isWide),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCardSkeleton(
            aspectRatio: 16 / 9,
            hasContent: true,
          ),
        ),
      ),
    );
  }

  Widget _buildListingsList(List<LandListing> listings, bool isWide) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      itemCount: listings.length,
      itemBuilder: (context, index) => _LandCard(
        listing: listings[index],
        onTap: () => context.push('/land/${listings[index].id}'),
      ),
    );
  }
}

/// Filter toggle button
class _FilterToggle extends StatefulWidget {
  const _FilterToggle({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterToggle> createState() => _FilterToggleState();
}

class _FilterToggleState extends State<_FilterToggle> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.success.withValues(alpha: 0.1)
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: widget.isActive ? AppColors.success : AppColors.borderSubtle,
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 20,
            color: widget.isActive ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Filters panel for land listings
class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.sortBy,
    required this.onSortChanged,
  });

  final LandSortBy sortBy;
  final void Function(LandSortBy) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort by',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SortChip(
                label: 'Newest',
                isSelected: sortBy == LandSortBy.newest,
                onTap: () => onSortChanged(LandSortBy.newest),
              ),
              _SortChip(
                label: 'Price: Low to High',
                isSelected: sortBy == LandSortBy.priceLowToHigh,
                onTap: () => onSortChanged(LandSortBy.priceLowToHigh),
              ),
              _SortChip(
                label: 'Price: High to Low',
                isSelected: sortBy == LandSortBy.priceHighToLow,
                onTap: () => onSortChanged(LandSortBy.priceHighToLow),
              ),
              _SortChip(
                label: 'Acres: Low to High',
                isSelected: sortBy == LandSortBy.acreageLowToHigh,
                onTap: () => onSortChanged(LandSortBy.acreageLowToHigh),
              ),
              _SortChip(
                label: 'Acres: High to Low',
                isSelected: sortBy == LandSortBy.acreageHighToLow,
                onTap: () => onSortChanged(LandSortBy.acreageHighToLow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: isSelected ? null : Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Land listing card with real data
class _LandCard extends ConsumerStatefulWidget {
  const _LandCard({
    required this.listing,
    required this.onTap,
  });

  final LandListing listing;
  final VoidCallback onTap;

  @override
  ConsumerState<_LandCard> createState() => _LandCardState();
}

class _LandCardState extends ConsumerState<_LandCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final service = ref.read(landListingServiceProvider);
    final hasPhoto = listing.photos.isNotEmpty;
    final photoUrl = hasPhoto ? service.getPhotoUrl(listing.photos.first) : null;

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
                      // Image
                      if (hasPhoto)
                        Positioned.fill(
                          child: Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.landscape_outlined,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else
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
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            listing.priceDisplay,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textInverse,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      // Type badge
                      Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            listing.type == 'lease' ? 'FOR LEASE' : 'FOR SALE',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
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
                      listing.title,
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
                          listing.locationDisplay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (listing.acreage != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          const Icon(
                            Icons.straighten_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${listing.acreage!.toStringAsFixed(0)} acres',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    if (listing.speciesTags != null && listing.speciesTags!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: listing.speciesTags!
                            .take(3)
                            .map((tag) => AppChip(
                                  label: tag,
                                  size: AppChipSize.small,
                                ))
                            .toList(),
                      ),
                    ],
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/swap_shop_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🛒 SWAP SHOP SCREEN - 2025 PREMIUM
/// 
/// Browse swap shop listings with search, filters, and sorting.
class SwapShopScreen extends ConsumerStatefulWidget {
  const SwapShopScreen({super.key});

  @override
  ConsumerState<SwapShopScreen> createState() => _SwapShopScreenState();
}

class _SwapShopScreenState extends ConsumerState<SwapShopScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  String? _selectedCategory;
  SwapShopSortBy _sortBy = SwapShopSortBy.newest;
  bool _showFilters = false;
  
  static const _categories = [
    'All',
    'Firearms',
    'Bows & Archery',
    'Ammunition',
    'Optics',
    'Clothing & Apparel',
    'Camping & Gear',
    'Boats & Watercraft',
    'ATVs & Vehicles',
    'Decoys & Calls',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Load listings on init
    Future.microtask(() => _loadListings());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadListings() {
    final params = SwapShopSearchParams(
      query: _searchController.text.isNotEmpty ? _searchController.text : null,
      category: _selectedCategory,
      sortBy: _sortBy,
    );
    
    ref.read(swapShopListingsNotifierProvider.notifier).fetchListings(params: params);
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadListings();
    });
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category == 'All' ? null : category;
    });
    _loadListings();
  }

  void _onSortChanged(SwapShopSortBy sort) {
    setState(() {
      _sortBy = sort;
    });
    _loadListings();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;
    final listingsState = ref.watch(swapShopListingsNotifierProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            // Banner header
            const SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: BannerHeader.appTop(),
                ),
              ),
            ),

            // Page title and search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Swap Shop',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buy, sell, and trade hunting & fishing gear',
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
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Search bar
                    AppSearchField(
                      controller: _searchController,
                      hint: 'Search listings...',
                      onChanged: _onSearchChanged,
                      onClear: () {
                        _searchController.clear();
                        _loadListings();
                      },
                    ),
                    
                    // Filters panel
                    if (_showFilters) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _FiltersPanel(
                        selectedCategory: _selectedCategory,
                        sortBy: _sortBy,
                        onCategoryChanged: _onCategorySelected,
                        onSortChanged: _onSortChanged,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Categories (horizontal scroll)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = (category == 'All' && _selectedCategory == null) ||
                        category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppChip(
                        label: category,
                        isSelected: isSelected,
                        onTap: () => _onCategorySelected(category),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg),
            ),

            // Content
            if (listingsState.isLoading)
              SliverToBoxAdapter(
                child: _buildLoadingState(isWide),
              )
            else if (listingsState.error != null)
              SliverToBoxAdapter(
                child: AppErrorState(
                  message: listingsState.error!,
                  onRetry: _loadListings,
                ),
              )
            else if (listingsState.listings.isEmpty)
              SliverToBoxAdapter(
                child: AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No listings found',
                  message: _searchController.text.isNotEmpty || _selectedCategory != null
                      ? 'Try adjusting your search or filters'
                      : 'Be the first to list something for sale!',
                  actionLabel: 'Create Listing',
                  onAction: () => context.push('/swap-shop/create'),
                ),
              )
            else
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
                    (context, index) {
                      final listing = listingsState.listings[index];
                      return _ListingCard(
                        listing: listing,
                        onTap: () => context.push('/swap-shop/detail/${listing.id}'),
                      );
                    },
                    childCount: listingsState.listings.length,
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
      
      // FAB for create
      floatingActionButton: _CreateFab(
        onTap: () {
          if (!isAuthenticated) {
            context.go('/auth');
            return;
          }
          showCreateMenu(
            context: context,
            createContext: CreateContext.swapShop,
            isAuthenticated: isAuthenticated,
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(bool isWide) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : 2,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const AppCardSkeleton(
          aspectRatio: 0.75,
          hasContent: true,
        ),
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
                ? AppColors.primary.withValues(alpha: 0.1)
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: widget.isActive ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 20,
            color: widget.isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Expanded filters panel
class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.selectedCategory,
    required this.sortBy,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final String? selectedCategory;
  final SwapShopSortBy sortBy;
  final void Function(String?) onCategoryChanged;
  final void Function(SwapShopSortBy) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort options
          Text(
            'Sort by',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              _SortChip(
                label: 'Newest',
                isSelected: sortBy == SwapShopSortBy.newest,
                onTap: () => onSortChanged(SwapShopSortBy.newest),
              ),
              _SortChip(
                label: 'Price: Low to High',
                isSelected: sortBy == SwapShopSortBy.priceLowToHigh,
                onTap: () => onSortChanged(SwapShopSortBy.priceLowToHigh),
              ),
              _SortChip(
                label: 'Price: High to Low',
                isSelected: sortBy == SwapShopSortBy.priceHighToLow,
                onTap: () => onSortChanged(SwapShopSortBy.priceHighToLow),
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
          color: isSelected ? AppColors.primary : AppColors.surface,
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

/// Listing card with real data
class _ListingCard extends ConsumerStatefulWidget {
  const _ListingCard({
    required this.listing,
    required this.onTap,
  });

  final SwapShopListing listing;
  final VoidCallback onTap;

  @override
  ConsumerState<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends ConsumerState<_ListingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final service = ref.read(swapShopServiceProvider);
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
                  child: hasPhoto
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
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
                        listing.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        listing.locationDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (listing.price != null)
                        Text(
                          '\$${listing.price!.toStringAsFixed(0)}',
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

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Create FAB for swap shop
class _CreateFab extends StatefulWidget {
  const _CreateFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateFab> createState() => _CreateFabState();
}

class _CreateFabState extends State<_CreateFab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Create Listing',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.08))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    ...AppColors.shadowAccent,
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AppColors.shadowAccent,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.textInverse,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

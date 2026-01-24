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
  String? _selectedCondition;
  String? _selectedState;
  double? _minPrice;
  double? _maxPrice;
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

  static const _conditions = [
    'New',
    'Like New',
    'Very Good',
    'Good',
    'Fair',
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
      condition: _selectedCondition,
      state: _selectedState,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      sortBy: _sortBy,
    );
    
    ref.read(swapShopListingsNotifierProvider.notifier).fetchListings(params: params);
  }

  void _onConditionSelected(String? condition) {
    setState(() {
      _selectedCondition = condition;
    });
    _loadListings();
  }

  void _onStateSelected(String? state) {
    setState(() {
      _selectedState = state;
    });
    _loadListings();
  }

  void _onPriceRangeChanged(double? min, double? max) {
    setState(() {
      _minPrice = min;
      _maxPrice = max;
    });
    _loadListings();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedCondition = null;
      _selectedState = null;
      _minPrice = null;
      _maxPrice = null;
      _searchController.clear();
    });
    _loadListings();
  }

  bool get _hasActiveFilters {
    return _selectedCategory != null ||
        _selectedCondition != null ||
        _selectedState != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _searchController.text.isNotEmpty;
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
                        selectedCondition: _selectedCondition,
                        selectedState: _selectedState,
                        minPrice: _minPrice,
                        maxPrice: _maxPrice,
                        sortBy: _sortBy,
                        hasActiveFilters: _hasActiveFilters,
                        onConditionChanged: _onConditionSelected,
                        onStateChanged: _onStateSelected,
                        onPriceRangeChanged: _onPriceRangeChanged,
                        onSortChanged: _onSortChanged,
                        onClearAll: _clearAllFilters,
                        conditions: _conditions,
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
class _FiltersPanel extends StatefulWidget {
  const _FiltersPanel({
    required this.selectedCondition,
    required this.selectedState,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.hasActiveFilters,
    required this.onConditionChanged,
    required this.onStateChanged,
    required this.onPriceRangeChanged,
    required this.onSortChanged,
    required this.onClearAll,
    required this.conditions,
  });

  final String? selectedCondition;
  final String? selectedState;
  final double? minPrice;
  final double? maxPrice;
  final SwapShopSortBy sortBy;
  final bool hasActiveFilters;
  final void Function(String?) onConditionChanged;
  final void Function(String?) onStateChanged;
  final void Function(double?, double?) onPriceRangeChanged;
  final void Function(SwapShopSortBy) onSortChanged;
  final VoidCallback onClearAll;
  final List<String> conditions;

  @override
  State<_FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<_FiltersPanel> {
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.minPrice != null) {
      _minPriceController.text = widget.minPrice!.toStringAsFixed(0);
    }
    if (widget.maxPrice != null) {
      _maxPriceController.text = widget.maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyPriceFilter() {
    final min = double.tryParse(_minPriceController.text);
    final max = double.tryParse(_maxPriceController.text);
    widget.onPriceRangeChanged(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with clear button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (widget.hasActiveFilters)
                GestureDetector(
                  onTap: widget.onClearAll,
                  child: Text(
                    'Clear all',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

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
            runSpacing: AppSpacing.sm,
            children: [
              _SortChip(
                label: 'Newest',
                isSelected: widget.sortBy == SwapShopSortBy.newest,
                onTap: () => widget.onSortChanged(SwapShopSortBy.newest),
              ),
              _SortChip(
                label: 'Price: Low',
                isSelected: widget.sortBy == SwapShopSortBy.priceLowToHigh,
                onTap: () => widget.onSortChanged(SwapShopSortBy.priceLowToHigh),
              ),
              _SortChip(
                label: 'Price: High',
                isSelected: widget.sortBy == SwapShopSortBy.priceHighToLow,
                onTap: () => widget.onSortChanged(SwapShopSortBy.priceHighToLow),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Condition filter
          Text(
            'Condition',
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
                label: 'Any',
                isSelected: widget.selectedCondition == null,
                onTap: () => widget.onConditionChanged(null),
              ),
              ...widget.conditions.map((condition) => _SortChip(
                label: condition,
                isSelected: widget.selectedCondition == condition,
                onTap: () => widget.onConditionChanged(condition),
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Price range
          Text(
            'Price Range',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Min',
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onSubmitted: (_) => _applyPriceFilter(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('–', style: TextStyle(color: AppColors.textTertiary)),
              ),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Max',
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onSubmitted: (_) => _applyPriceFilter(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _applyPriceFilter,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
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
              // Image with badges
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    Container(
                      color: AppColors.backgroundAlt,
                      child: hasPhoto
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Condition badge (top-left)
                    if (listing.condition != null)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: _ConditionBadge(condition: listing.condition!),
                      ),
                    // Price badge (bottom-right)
                    if (listing.price != null)
                      Positioned(
                        bottom: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '\$${listing.price!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      listing.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.locationDisplay,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
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

/// Condition badge with color coding
class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({required this.condition});

  final String condition;

  Color get _backgroundColor {
    switch (condition.toLowerCase()) {
      case 'new':
        return AppColors.success;
      case 'like new':
        return const Color(0xFF4CAF50);
      case 'very good':
        return const Color(0xFF8BC34A);
      case 'good':
        return AppColors.accent;
      case 'fair':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        condition,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
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

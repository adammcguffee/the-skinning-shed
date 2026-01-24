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
  String? _selectedState;
  double? _minPrice;
  double? _maxPrice;
  double? _minAcres;
  double? _maxAcres;

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
      state: _selectedState,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      minAcreage: _minAcres,
      maxAcreage: _maxAcres,
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

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
    });
    final type = _tabController.index == 0 ? 'lease' : 'sale';
    _loadListings(type);
  }

  void _onPriceRangeChanged(double? min, double? max) {
    setState(() {
      _minPrice = min;
      _maxPrice = max;
    });
    final type = _tabController.index == 0 ? 'lease' : 'sale';
    _loadListings(type);
  }

  void _onAcresRangeChanged(double? min, double? max) {
    setState(() {
      _minAcres = min;
      _maxAcres = max;
    });
    final type = _tabController.index == 0 ? 'lease' : 'sale';
    _loadListings(type);
  }

  void _clearAllFilters() {
    setState(() {
      _selectedState = null;
      _minPrice = null;
      _maxPrice = null;
      _minAcres = null;
      _maxAcres = null;
    });
    final type = _tabController.index == 0 ? 'lease' : 'sale';
    _loadListings(type);
  }

  bool get _hasActiveFilters {
    return _selectedState != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _minAcres != null ||
        _maxAcres != null;
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
                    selectedState: _selectedState,
                    minPrice: _minPrice,
                    maxPrice: _maxPrice,
                    minAcres: _minAcres,
                    maxAcres: _maxAcres,
                    hasActiveFilters: _hasActiveFilters,
                    onSortChanged: _onSortChanged,
                    onStateChanged: _onStateChanged,
                    onPriceRangeChanged: _onPriceRangeChanged,
                    onAcresRangeChanged: _onAcresRangeChanged,
                    onClearAll: _clearAllFilters,
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
                                onAction: () {
                                  final mode = _tabController.index == 0 ? 'lease' : 'sale';
                                  context.push('/land/create?mode=$mode');
                                },
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
class _FiltersPanel extends StatefulWidget {
  const _FiltersPanel({
    required this.sortBy,
    required this.selectedState,
    required this.minPrice,
    required this.maxPrice,
    required this.minAcres,
    required this.maxAcres,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onStateChanged,
    required this.onPriceRangeChanged,
    required this.onAcresRangeChanged,
    required this.onClearAll,
  });

  final LandSortBy sortBy;
  final String? selectedState;
  final double? minPrice;
  final double? maxPrice;
  final double? minAcres;
  final double? maxAcres;
  final bool hasActiveFilters;
  final void Function(LandSortBy) onSortChanged;
  final void Function(String?) onStateChanged;
  final void Function(double?, double?) onPriceRangeChanged;
  final void Function(double?, double?) onAcresRangeChanged;
  final VoidCallback onClearAll;

  @override
  State<_FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<_FiltersPanel> {
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minAcresController = TextEditingController();
  final _maxAcresController = TextEditingController();

  static const _states = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.minPrice != null) {
      _minPriceController.text = widget.minPrice!.toStringAsFixed(0);
    }
    if (widget.maxPrice != null) {
      _maxPriceController.text = widget.maxPrice!.toStringAsFixed(0);
    }
    if (widget.minAcres != null) {
      _minAcresController.text = widget.minAcres!.toStringAsFixed(0);
    }
    if (widget.maxAcres != null) {
      _maxAcresController.text = widget.maxAcres!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAcresController.dispose();
    _maxAcresController.dispose();
    super.dispose();
  }

  void _applyPriceFilter() {
    final min = double.tryParse(_minPriceController.text);
    final max = double.tryParse(_maxPriceController.text);
    widget.onPriceRangeChanged(min, max);
  }

  void _applyAcresFilter() {
    final min = double.tryParse(_minAcresController.text);
    final max = double.tryParse(_maxAcresController.text);
    widget.onAcresRangeChanged(min, max);
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
                isSelected: widget.sortBy == LandSortBy.newest,
                onTap: () => widget.onSortChanged(LandSortBy.newest),
              ),
              _SortChip(
                label: 'Price ↓',
                isSelected: widget.sortBy == LandSortBy.priceLowToHigh,
                onTap: () => widget.onSortChanged(LandSortBy.priceLowToHigh),
              ),
              _SortChip(
                label: 'Price ↑',
                isSelected: widget.sortBy == LandSortBy.priceHighToLow,
                onTap: () => widget.onSortChanged(LandSortBy.priceHighToLow),
              ),
              _SortChip(
                label: 'Acres ↓',
                isSelected: widget.sortBy == LandSortBy.acreageLowToHigh,
                onTap: () => widget.onSortChanged(LandSortBy.acreageLowToHigh),
              ),
              _SortChip(
                label: 'Acres ↑',
                isSelected: widget.sortBy == LandSortBy.acreageHighToLow,
                onTap: () => widget.onSortChanged(LandSortBy.acreageHighToLow),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // State filter
          Text(
            'State',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortChip(
                  label: 'All States',
                  isSelected: widget.selectedState == null,
                  onTap: () => widget.onStateChanged(null),
                ),
                const SizedBox(width: AppSpacing.sm),
                ..._states.map((state) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: _SortChip(
                    label: state,
                    isSelected: widget.selectedState == state,
                    onTap: () => widget.onStateChanged(state),
                  ),
                )),
              ],
            ),
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
                child: _RangeInput(
                  controller: _minPriceController,
                  hint: 'Min',
                  prefix: '\$ ',
                  onSubmit: _applyPriceFilter,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('–', style: TextStyle(color: AppColors.textTertiary)),
              ),
              Expanded(
                child: _RangeInput(
                  controller: _maxPriceController,
                  hint: 'Max',
                  prefix: '\$ ',
                  onSubmit: _applyPriceFilter,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ApplyButton(onTap: _applyPriceFilter),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Acres range
          Text(
            'Acreage',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _RangeInput(
                  controller: _minAcresController,
                  hint: 'Min',
                  suffix: ' ac',
                  onSubmit: _applyAcresFilter,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('–', style: TextStyle(color: AppColors.textTertiary)),
              ),
              Expanded(
                child: _RangeInput(
                  controller: _maxAcresController,
                  hint: 'Max',
                  suffix: ' ac',
                  onSubmit: _applyAcresFilter,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ApplyButton(onTap: _applyAcresFilter),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeInput extends StatelessWidget {
  const _RangeInput({
    required this.controller,
    required this.hint,
    this.prefix,
    this.suffix,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? suffix;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
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
      onSubmitted: (_) => onSubmit(),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 20,
          color: Colors.white,
        ),
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
    final photoCount = listing.photos.length;

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
              // Main image with badges
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: AppColors.backgroundAlt,
                  child: Stack(
                    children: [
                      // Main image
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
                      
                      // Type badge (top-left)
                      Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: listing.type == 'lease' 
                                ? AppColors.accent 
                                : AppColors.success,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            listing.type == 'lease' ? 'LEASE' : 'SALE',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      
                      // Price badge (top-right)
                      Positioned(
                        top: AppSpacing.md,
                        right: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            listing.priceDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Photo count badge (bottom-right)
                      if (photoCount > 1)
                        Positioned(
                          bottom: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$photoCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Acreage badge (bottom-left)
                      if (listing.acreage != null)
                        Positioned(
                          bottom: AppSpacing.sm,
                          left: AppSpacing.sm,
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
                              '${listing.acreage!.toStringAsFixed(0)} ac',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Photo thumbnails (if multiple photos)
              if (photoCount > 1) ...[
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: photoCount > 4 ? 4 : photoCount,
                    itemBuilder: (context, index) {
                      final isLast = index == 3 && photoCount > 4;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: SizedBox(
                            width: 56,
                            height: 42,
                            child: isLast
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        service.getPhotoUrl(listing.photos[index]),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.backgroundAlt,
                                        ),
                                      ),
                                      Container(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '+${photoCount - 3}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Image.network(
                                    service.getPhotoUrl(listing.photos[index]),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.backgroundAlt,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        Expanded(
                          child: Text(
                            listing.locationDisplay,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (listing.speciesTags != null && listing.speciesTags!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
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

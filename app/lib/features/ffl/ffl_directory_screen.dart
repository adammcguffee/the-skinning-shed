import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../data/us_states.dart';
import '../../services/ffl_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// FFL DIRECTORY SCREEN
// ════════════════════════════════════════════════════════════════════════════

class FFLDirectoryScreen extends ConsumerStatefulWidget {
  const FFLDirectoryScreen({super.key});

  @override
  ConsumerState<FFLDirectoryScreen> createState() => _FFLDirectoryScreenState();
}

class _FFLDirectoryScreenState extends ConsumerState<FFLDirectoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<FFLDealer> _dealers = [];
  int _offset = 0;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    final filter = ref.read(fflFilterProvider);
    if (!filter.canQuery) return;

    setState(() => _isLoadingMore = true);

    final service = ref.read(fflServiceProvider);
    final newDealers = await service.searchDealers(
      filter: filter,
      limit: _pageSize,
      offset: _offset + _pageSize,
    );

    if (mounted && newDealers.isNotEmpty) {
      setState(() {
        _dealers.addAll(newDealers);
        _offset += _pageSize;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  void _resetAndRefresh() {
    setState(() {
      _dealers.clear();
      _offset = 0;
    });
    ref.invalidate(fflDealersProvider);
    ref.invalidate(fflDealerCountProvider);
  }

  void _onSearch(String query) {
    final currentFilter = ref.read(fflFilterProvider);
    ref.read(fflFilterProvider.notifier).state = currentFilter.copyWith(
      searchQuery: query.isEmpty ? null : query,
    );
    _resetAndRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(fflFilterProvider);
    final dealersAsync = ref.watch(fflDealersProvider);
    final countAsync = ref.watch(fflDealerCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _FFLHeader(),

            // Filter Card
            _FilterCard(
              filter: filter,
              searchController: _searchController,
              onSearch: _onSearch,
              onFilterChanged: (newFilter) {
                ref.read(fflFilterProvider.notifier).state = newFilter;
                _resetAndRefresh();
              },
            ),

            // Result count
            if (filter.canQuery)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    countAsync.when(
                      loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const Text(
                        'Error',
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                      data: (count) => Text(
                        '$count dealers found',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (filter.hasFilters)
                      GestureDetector(
                        onTap: () {
                          ref.read(fflFilterProvider.notifier).state = const FFLFilter();
                          _searchController.clear();
                          _resetAndRefresh();
                        },
                        child: const Text(
                          'Clear filters',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: !filter.canQuery
                  ? _EmptyPrompt()
                  : dealersAsync.when(
                      loading: () => _LoadingState(),
                      error: (e, _) => _ErrorState(
                        onRetry: () => ref.invalidate(fflDealersProvider),
                      ),
                      data: (dealers) {
                        // Sync with state
                        if (_dealers.isEmpty && dealers.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _dealers = List.from(dealers);
                              });
                            }
                          });
                        }

                        final displayDealers = _dealers.isNotEmpty ? _dealers : dealers;

                        if (displayDealers.isEmpty) {
                          return _EmptyResults(
                            hasFilters: filter.county != null || filter.city != null ||
                                (filter.searchQuery?.isNotEmpty == true),
                            onClearFilters: () {
                              ref.read(fflFilterProvider.notifier).state = FFLFilter(
                                state: filter.state,
                              );
                              _searchController.clear();
                              _resetAndRefresh();
                            },
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            _resetAndRefresh();
                          },
                          color: AppColors.primary,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 600;
                              
                              if (isWide) {
                                // 2-column grid for desktop/tablet
                                return GridView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: displayDealers.length + (_isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= displayDealers.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return _DealerCard(dealer: displayDealers[index]);
                                  },
                                );
                              }

                              // Single column list for mobile
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: displayDealers.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= displayDealers.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DealerCard(dealer: displayDealers[index]),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HEADER
// ════════════════════════════════════════════════════════════════════════════

class _FFLHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FFL Dealers',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Federal Firearms Licensee Directory',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FILTER CARD
// ════════════════════════════════════════════════════════════════════════════

class _FilterCard extends ConsumerWidget {
  const _FilterCard({
    required this.filter,
    required this.searchController,
    required this.onSearch,
    required this.onFilterChanged,
  });

  final FFLFilter filter;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<FFLFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // State and County row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // State dropdown
                Expanded(
                  child: _FilterDropdown<String>(
                    value: filter.state,
                    hint: 'State',
                    icon: Icons.location_on_outlined,
                    items: USStates.all.map((s) => DropdownMenuItem(
                      value: s.code,
                      child: Text(s.code),
                    )).toList(),
                    onChanged: (v) => onFilterChanged(FFLFilter(state: v)),
                  ),
                ),
                const SizedBox(width: 8),

                // County dropdown
                Expanded(
                  flex: 2,
                  child: _CountyDropdown(
                    state: filter.state,
                    value: filter.county,
                    onChanged: (v) => onFilterChanged(filter.copyWith(
                      county: v,
                      clearCity: true,
                    )),
                  ),
                ),
              ],
            ),
          ),

          // City and Search row
          if (filter.state != null && filter.county != null) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // City dropdown
                  Expanded(
                    child: _CityDropdown(
                      state: filter.state!,
                      county: filter.county!,
                      value: filter.city,
                      onChanged: (v) => onFilterChanged(filter.copyWith(city: v)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Search bar
          if (filter.state != null) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchController,
                onSubmitted: onSearch,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by dealer name...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearch('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(hint, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CountyDropdown extends ConsumerWidget {
  const _CountyDropdown({
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final String? state;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Text(
          'Select state first',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    final countiesAsync = ref.watch(fflCountiesProvider(state));

    return countiesAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Text('Error'),
      data: (counties) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: const Text('All Counties', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Counties', style: TextStyle(color: AppColors.textTertiary))),
                ...counties.map((c) => DropdownMenuItem(
                  value: c.county,
                  child: Text('${c.county} (${c.dealerCount})'),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

class _CityDropdown extends ConsumerWidget {
  const _CityDropdown({
    required this.state,
    required this.county,
    required this.value,
    required this.onChanged,
  });

  final String state;
  final String county;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(fflCitiesProvider((state, county)));

    return citiesAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Text('Error'),
      data: (cities) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: const Text('All Cities', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Cities', style: TextStyle(color: AppColors.textTertiary))),
                ...cities.map((c) => DropdownMenuItem(
                  value: c.city,
                  child: Text('${c.city} (${c.dealerCount})'),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DEALER CARD
// ════════════════════════════════════════════════════════════════════════════

class _DealerCard extends ConsumerWidget {
  const _DealerCard({required this.dealer});

  final FFLDealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(fflServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => service.openInMaps(dealer),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dealer name
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dealer.licenseName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dealer.fullAddress,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Phone (if available)
                if (dealer.phone != null && dealer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        dealer.phone!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    // Open maps
                    Expanded(
                      child: GestureDetector(
                        onTap: () => service.openInMaps(dealer),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'Directions',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy address
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: dealer.fullAddress));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Address copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Call (if phone available)
                    if (dealer.phone != null && dealer.phone!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => service.callPhone(dealer.phone!),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_rounded, size: 16, color: AppColors.success),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STATE WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select a State',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a state to browse FFL dealers in your area',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.hasFilters, required this.onClearFilters});

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.search_off_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'No dealers found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters ? 'Try adjusting your filters' : 'Try another county',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onClearFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  Container(width: 200, height: 16, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4))),
                ],
              ),
              const SizedBox(height: 12),
              Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(width: 150, height: 12, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load dealers',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

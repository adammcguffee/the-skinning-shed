import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme/app_colors.dart';
import '../../data/us_states.dart';
import '../../services/club_openings_service.dart';
import '../../services/messaging_service.dart';
import '../../services/supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// OPENINGS HOME SCREEN
// ════════════════════════════════════════════════════════════════════════════

class OpeningsScreen extends ConsumerStatefulWidget {
  const OpeningsScreen({super.key});

  @override
  ConsumerState<OpeningsScreen> createState() => _OpeningsScreenState();
}

class _OpeningsScreenState extends ConsumerState<OpeningsScreen> {
  @override
  Widget build(BuildContext context) {
    final openingsAsync = ref.watch(openingsProvider);
    final filter = ref.watch(openingsFilterProvider);
    final isLoggedIn = SupabaseService.instance.client?.auth.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _OpeningsHeader(
              onCreateTap: isLoggedIn ? () => context.push('/openings/create') : null,
            ),

            // Filter bar
            _FilterBar(
              filter: filter,
              onFilterChanged: (f) => ref.read(openingsFilterProvider.notifier).state = f,
            ),

            // Content
            Expanded(
              child: openingsAsync.when(
                loading: () => const _LoadingGrid(),
                error: (e, _) => _ErrorState(
                  message: 'Could not load openings',
                  onRetry: () => ref.invalidate(openingsProvider),
                ),
                data: (openings) {
                  if (openings.isEmpty) {
                    return _EmptyState(
                      hasFilters: filter.hasFilters,
                      onClearFilters: () =>
                          ref.read(openingsFilterProvider.notifier).state = const OpeningsFilter(),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(openingsProvider),
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: openings.length,
                      itemBuilder: (context, index) => _OpeningCard(
                        opening: openings[index],
                        onTap: () => context.push('/openings/${openings[index].id}'),
                        onMessage: isLoggedIn && openings[index].ownerId != SupabaseService.instance.client?.auth.currentUser?.id
                            ? () => _messageOwner(openings[index])
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/openings/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Post Opening', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Future<void> _messageOwner(ClubOpening opening) async {
    HapticFeedback.mediumImpact();
    final service = ref.read(messagingServiceProvider);
    final threadId = await service.getOrCreateDM(otherUserId: opening.ownerId);
    if (threadId != null && mounted) {
      context.push('/messages/$threadId');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HEADER
// ════════════════════════════════════════════════════════════════════════════

class _OpeningsHeader extends StatelessWidget {
  const _OpeningsHeader({this.onCreateTap});

  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Club Openings',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Find hunting clubs with spots available',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FILTER BAR
// ════════════════════════════════════════════════════════════════════════════

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({
    required this.filter,
    required this.onFilterChanged,
  });

  final OpeningsFilter filter;
  final ValueChanged<OpeningsFilter> onFilterChanged;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Main filter row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // State dropdown
                Expanded(
                  child: _FilterDropdown(
                    value: widget.filter.stateCode,
                    hint: 'State',
                    items: USStates.all.map((s) => DropdownMenuItem(
                      value: s.code,
                      child: Text(s.code),
                    )).toList(),
                    onChanged: (v) => widget.onFilterChanged(
                      widget.filter.copyWith(stateCode: v, clearCounty: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // County dropdown
                Expanded(
                  flex: 2,
                  child: _CountyDropdown(
                    stateCode: widget.filter.stateCode,
                    value: widget.filter.county,
                    onChanged: (v) => widget.onFilterChanged(
                      widget.filter.copyWith(county: v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Expand button
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _expanded || widget.filter.hasFilters
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                      size: 20,
                      color: _expanded || widget.filter.hasFilters
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded filters
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game chips
                  const Text(
                    'Game',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Whitetail', 'Turkey', 'Duck', 'Hog', 'Other'].map((g) {
                      final selected = widget.filter.game.contains(g.toLowerCase());
                      return _ChipButton(
                        label: g,
                        isSelected: selected,
                        onTap: () {
                          final newGame = selected
                              ? widget.filter.game.where((x) => x != g.toLowerCase()).toList()
                              : [...widget.filter.game, g.toLowerCase()];
                          widget.onFilterChanged(widget.filter.copyWith(game: newGame));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Amenities chips
                  const Text(
                    'Amenities',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Camp', 'Electric', 'Water', 'Lodging'].map((a) {
                      final selected = widget.filter.amenities.contains(a.toLowerCase());
                      return _ChipButton(
                        label: a,
                        isSelected: selected,
                        onTap: () {
                          final newAmenities = selected
                              ? widget.filter.amenities.where((x) => x != a.toLowerCase()).toList()
                              : [...widget.filter.amenities, a.toLowerCase()];
                          widget.onFilterChanged(widget.filter.copyWith(amenities: newAmenities));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Clear filters
                  if (widget.filter.hasFilters)
                    GestureDetector(
                      onTap: () => widget.onFilterChanged(const OpeningsFilter()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 6),
                            Text(
                              'Clear all filters',
                              style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: [
            DropdownMenuItem<String>(value: null, child: Text('All $hint', style: const TextStyle(color: AppColors.textTertiary))),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CountyDropdown extends ConsumerWidget {
  const _CountyDropdown({
    required this.stateCode,
    required this.value,
    required this.onChanged,
  });

  final String? stateCode;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stateCode == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Text(
          'Select state first',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    final countiesAsync = ref.watch(availableCountiesProvider(stateCode!));

    return countiesAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Text('Error'),
      data: (counties) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: const Text('County', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Counties', style: TextStyle(color: AppColors.textTertiary))),
                ...counties.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// OPENING CARD
// ════════════════════════════════════════════════════════════════════════════

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({
    required this.opening,
    required this.onTap,
    this.onMessage,
  });

  final ClubOpening opening;
  final VoidCallback onTap;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo
            SizedBox(
              height: 140,
              child: opening.photoUrls.isNotEmpty
                  ? Image.network(
                      opening.photoUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
                    )
                  : const _PhotoPlaceholder(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    opening.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          opening.locationDisplay,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Price
                      _Badge(
                        label: opening.priceFormatted,
                        color: AppColors.success,
                      ),
                      // Spots
                      if (opening.spotsAvailable != null)
                        _Badge(
                          label: '${opening.spotsAvailable} spot${opening.spotsAvailable == 1 ? '' : 's'}',
                          color: AppColors.primary,
                        ),
                      // Game
                      if (opening.game.isNotEmpty)
                        _Badge(
                          label: opening.game.take(2).map((g) => g[0].toUpperCase() + g.substring(1)).join(' • '),
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Footer
                  Row(
                    children: [
                      Text(
                        timeago.format(opening.createdAt),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                      const Spacer(),
                      if (onMessage != null)
                        GestureDetector(
                          onTap: onMessage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Message',
                                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.landscape_rounded, color: AppColors.textTertiary.withValues(alpha: 0.5), size: 40),
            const SizedBox(height: 4),
            Text(
              'No photo',
              style: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.5), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOADING / EMPTY / ERROR STATES
// ════════════════════════════════════════════════════════════════════════════

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 200, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 150, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(height: 24, width: 80, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 8),
                      Container(height: 24, width: 60, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onClearFilters});

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
              'No openings found',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters ? 'Try adjusting your filters' : 'Check back later for new listings',
              style: const TextStyle(color: AppColors.textSecondary),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
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
            Text(message, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme/app_colors.dart';
import '../../data/us_states.dart';
import '../../services/club_openings_service.dart';
import '../../services/messaging_service.dart';
import '../../services/opening_alerts_service.dart';
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

                // Alerts button
                GestureDetector(
                  onTap: () => _showAlertsSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                      color: AppColors.accent,
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

  void _showAlertsSheet(BuildContext context) {
    final isLoggedIn = SupabaseService.instance.client?.auth.currentUser != null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlertsBottomSheet(
        currentStateCode: widget.filter.stateCode,
        currentCounty: widget.filter.county,
        currentFilter: widget.filter,
        isLoggedIn: isLoggedIn,
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

// ════════════════════════════════════════════════════════════════════════════
// ALERTS BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════════════

class _AlertsBottomSheet extends ConsumerStatefulWidget {
  const _AlertsBottomSheet({
    this.currentStateCode,
    this.currentCounty,
    required this.currentFilter,
    required this.isLoggedIn,
  });

  final String? currentStateCode;
  final String? currentCounty;
  final OpeningsFilter currentFilter;
  final bool isLoggedIn;

  @override
  ConsumerState<_AlertsBottomSheet> createState() => _AlertsBottomSheetState();
}

class _AlertsBottomSheetState extends ConsumerState<_AlertsBottomSheet> {
  String? _stateCode;
  String _county = '';
  bool _availableOnly = true;
  bool _notifyPush = true;
  bool _notifyInApp = true;
  final Set<String> _game = {};
  final Set<String> _amenities = {};
  bool _isSaving = false;

  OpeningAlert? _existingAlert;
  bool _isLoadingAlert = true;

  @override
  void initState() {
    super.initState();
    _stateCode = widget.currentStateCode;
    _county = widget.currentCounty ?? '';
    _game.addAll(widget.currentFilter.game);
    _amenities.addAll(widget.currentFilter.amenities);
    _loadExistingAlert();
  }

  Future<void> _loadExistingAlert() async {
    if (!widget.isLoggedIn || _stateCode == null) {
      setState(() => _isLoadingAlert = false);
      return;
    }

    final service = ref.read(openingAlertsServiceProvider);
    final alert = await service.getAlertForLocation(_stateCode!, _county.isEmpty ? null : _county);
    
    if (mounted) {
      setState(() {
        _existingAlert = alert;
        _isLoadingAlert = false;
        if (alert != null) {
          _availableOnly = alert.availableOnly;
          _notifyPush = alert.notifyPush;
          _notifyInApp = alert.notifyInApp;
          _game.clear();
          _game.addAll(alert.game);
          _amenities.clear();
          _amenities.addAll(alert.amenities);
        }
      });
    }
  }

  Future<void> _saveAlert() async {
    if (_stateCode == null) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final service = ref.read(openingAlertsServiceProvider);
    
    bool success;
    if (_existingAlert != null) {
      success = await service.updateAlert(
        _existingAlert!.id,
        availableOnly: _availableOnly,
        game: _game.toList(),
        amenities: _amenities.toList(),
        notifyPush: _notifyPush,
        notifyInApp: _notifyInApp,
      );
    } else {
      final alert = await service.createAlert(
        stateCode: _stateCode!,
        county: _county.isEmpty ? null : _county,
        availableOnly: _availableOnly,
        game: _game.toList(),
        amenities: _amenities.toList(),
        notifyPush: _notifyPush,
        notifyInApp: _notifyInApp,
      );
      success = alert != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ref.invalidate(myOpeningAlertsProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingAlert != null ? 'Alert updated!' : 'Alert created!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlert() async {
    if (_existingAlert == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Alert?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('You will no longer receive notifications for this area.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = ref.read(openingAlertsServiceProvider);
      await service.deleteAlert(_existingAlert!.id);
      ref.invalidate(myOpeningAlertsProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Opening Alerts', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Get notified when new openings match your criteria', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border),

          // Content
          if (!widget.isLoggedIn)
            _SignInPrompt()
          else if (_isLoadingAlert)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    const Text('Location', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _stateCode,
                                hint: const Text('State *', style: TextStyle(color: AppColors.textTertiary)),
                                isExpanded: true,
                                dropdownColor: AppColors.surfaceElevated,
                                style: const TextStyle(color: AppColors.textPrimary),
                                items: USStates.all.map((s) => DropdownMenuItem(value: s.code, child: Text(s.code))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _stateCode = v;
                                    _county = '';
                                    _existingAlert = null;
                                  });
                                  _loadExistingAlert();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: _county,
                            onChanged: (v) => _county = v,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'County (optional)',
                              hintStyle: const TextStyle(color: AppColors.textTertiary),
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Available only toggle
                    _ToggleRow(
                      label: 'Available listings only',
                      value: _availableOnly,
                      onChanged: (v) => setState(() => _availableOnly = v),
                    ),
                    const SizedBox(height: 16),

                    // Game chips
                    const Text('Game (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['whitetail', 'turkey', 'duck', 'hog'].map((g) {
                        final selected = _game.contains(g);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) _game.remove(g);
                            else _game.add(g);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1 : 0.5),
                            ),
                            child: Text(
                              g[0].toUpperCase() + g.substring(1),
                              style: TextStyle(color: selected ? AppColors.accent : AppColors.textSecondary, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Amenities chips
                    const Text('Amenities (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['camp', 'electric', 'water', 'lodging'].map((a) {
                        final selected = _amenities.contains(a);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) _amenities.remove(a);
                            else _amenities.add(a);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.success.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? AppColors.success : AppColors.border, width: selected ? 1 : 0.5),
                            ),
                            child: Text(
                              a[0].toUpperCase() + a.substring(1),
                              style: TextStyle(color: selected ? AppColors.success : AppColors.textSecondary, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Notification preferences
                    const Text('Notification Settings', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      label: 'Push notifications',
                      subtitle: 'Get notified on your device',
                      value: _notifyPush,
                      onChanged: (v) => setState(() => _notifyPush = v),
                    ),
                    _ToggleRow(
                      label: 'In-app notifications',
                      subtitle: 'Show in notification center',
                      value: _notifyInApp,
                      onChanged: (v) => setState(() => _notifyInApp = v),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        if (_existingAlert != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: _deleteAlert,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),
                        if (_existingAlert != null) const SizedBox(width: 12),
                        Expanded(
                          flex: _existingAlert != null ? 2 : 1,
                          child: GestureDetector(
                            onTap: _stateCode != null && !_isSaving ? _saveAlert : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _stateCode != null ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(
                                        _existingAlert != null ? 'Save Changes' : 'Create Alert',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You will receive up to 10 notifications per day, no more than once every 30 minutes per alert.',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign in to enable alerts',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an account to receive notifications when new openings match your criteria.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).push('/auth');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

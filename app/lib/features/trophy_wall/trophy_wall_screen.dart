import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/animated_entry.dart';
import '../../shared/widgets/state_widgets.dart';

/// 🏆 PREMIUM TROPHY WALL
/// 
/// User's profile page with:
/// - Modern avatar + name/handle header
/// - Stat pills (trophies, species counts)
/// - Season cards/timeline
/// - Trophy grid
class TrophyWallScreen extends StatefulWidget {
  const TrophyWallScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  State<TrophyWallScreen> createState() => _TrophyWallScreenState();
}

class _TrophyWallScreenState extends State<TrophyWallScreen> {
  final bool _isLoading = false;
  final bool _hasError = false;
  final List<_TrophyData> _trophies = const [
    _TrophyData('🦌', 'Whitetail Deer', 'Texas • Travis County', 'Jan 15, 2026'),
    _TrophyData('🦃', 'Eastern Turkey', 'Alabama • Jefferson County', 'Jan 12, 2026'),
  ];

  bool get _isCurrentUser => widget.userId == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              _isCurrentUser ? 'My Trophy Wall' : 'Trophy Wall',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (_isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.go('/settings'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          // Profile header
          SliverToBoxAdapter(child: _ProfileHeader(isCurrentUser: _isCurrentUser)),
          // Stat pills
          SliverToBoxAdapter(child: _StatPills()),
          // Season selector
          SliverToBoxAdapter(child: _SeasonSelector()),
          // Trophy grid
          if (_isLoading)
            _buildLoadingGrid()
          else if (_hasError)
            _buildErrorState()
          else if (_trophies.isEmpty)
            _buildEmptyState()
          else
            _buildTrophyGrid(context),
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _isCurrentUser
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/post'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Trophy'),
            )
          : null,
    );
  }

  Widget _buildTrophyGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => AnimatedEntry(
            delay: Duration(milliseconds: 40 * index),
            child: _TrophyCard(data: _trophies[index]),
          ),
          childCount: _trophies.length,
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const GridCardSkeleton(),
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AnimatedEntry(
        child: ErrorState(
          title: 'Could not load Trophy Wall',
          message: 'Please check your connection and try again.',
          onRetry: () {},
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AnimatedEntry(
        child: EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'No Trophies Yet',
          message: _isCurrentUser
              ? 'Post your first trophy to start building your wall.'
              : 'This hunter hasn\'t posted any trophies yet.',
          actionLabel: _isCurrentUser ? 'Post Trophy' : null,
          onAction: _isCurrentUser ? () => context.push('/post') : null,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.isCurrentUser});
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.accent.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'Your Name' : 'Hunter Name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '@username',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Pro Hunter',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since Jan 2026',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          if (isCurrentUser)
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Edit'),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAT PILLS
// ═══════════════════════════════════════════════════════════════════════════════

class _StatPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatPill(value: '5', label: 'Trophies', color: AppColors.primary),
          _StatPill(value: '2', label: 'Deer', emoji: '🦌', color: AppColors.categoryDeer),
          _StatPill(value: '2', label: 'Turkey', emoji: '🦃', color: AppColors.categoryTurkey),
          _StatPill(value: '1', label: 'Bass', emoji: '🐟', color: AppColors.categoryBass),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
    this.emoji,
  });

  final String value;
  final String label;
  final Color color;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEASON SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

class _SeasonSelector extends StatefulWidget {
  @override
  State<_SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends State<_SeasonSelector> {
  int _selectedSeason = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Seasons',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('View Timeline'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SeasonChip(
                  label: '2025-26',
                  isSelected: _selectedSeason == 0,
                  onTap: () => setState(() => _selectedSeason = 0),
                ),
                _SeasonChip(
                  label: '2024-25',
                  isSelected: _selectedSeason == 1,
                  onTap: () => setState(() => _selectedSeason = 1),
                ),
                _SeasonChip(
                  label: '2023-24',
                  isSelected: _selectedSeason == 2,
                  onTap: () => setState(() => _selectedSeason = 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TROPHY CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _TrophyData {
  const _TrophyData(this.emoji, this.species, this.location, this.date);
  final String emoji;
  final String species;
  final String location;
  final String date;
}

class _TrophyCard extends StatefulWidget {
  const _TrophyCard({required this.data});
  final _TrophyData data;

  @override
  State<_TrophyCard> createState() => _TrophyCardState();
}

class _TrophyCardState extends State<_TrophyCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/trophy/demo'),
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppColors.primary.withOpacity(0.06),
          splashColor: AppColors.primary.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered 
                    ? AppColors.primary.withOpacity(0.3) 
                    : AppColors.border.withOpacity(0.5),
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: _isHovered ? 1.1 : 1.0,
                        child: Text(
                          widget.data.emoji,
                          style: const TextStyle(fontSize: 56),
                        ),
                      ),
                    ),
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.species,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.data.location,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.data.date,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


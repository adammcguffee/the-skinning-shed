import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/branding_assets.dart';
import '../../shared/widgets/animated_entry.dart';
import '../../shared/widgets/state_widgets.dart';

/// 📱 MODERN FEED SCREEN
/// 
/// Premium trophy feed with:
/// - Modern card design with image aspect ratio
/// - Species chip overlay
/// - Title + location + date row
/// - Action row (like/comment/share)
/// - Clean empty state with CTA
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _selectedCategory;
  final bool _isLoading = false;
  final bool _hasError = false;
  final List<_FeedItem> _items = const [
    _FeedItem(
      species: 'Whitetail Deer',
      speciesEmoji: '🦌',
      category: 'Deer',
      location: 'Texas • Travis County',
      date: 'Jan 15, 2026',
      stats: '142\" • Rifle • 8pt',
      userName: 'Hunter_TX',
      likes: 24,
      comments: 5,
      route: '/trophy/demo-1',
    ),
    _FeedItem(
      species: 'Eastern Wild Turkey',
      speciesEmoji: '🦃',
      category: 'Turkey',
      location: 'Alabama • Jefferson County',
      date: 'Jan 12, 2026',
      stats: '22 lbs • 10\" beard',
      userName: 'GobblerGetter',
      likes: 18,
      comments: 3,
      route: '/trophy/demo-2',
    ),
    _FeedItem(
      species: 'Largemouth Bass',
      speciesEmoji: '🐟',
      category: 'Bass',
      location: 'Florida • Lake County',
      date: 'Jan 10, 2026',
      stats: '8.2 lbs • 22\"',
      userName: 'BassChaser',
      likes: 31,
      comments: 8,
      route: '/trophy/demo-3',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Modern app bar
          _buildSliverAppBar(context),
          // Category filter chips
          _buildCategoryChips(),
          // Feed content
          if (_isLoading)
            _buildLoadingState()
          else if (_hasError)
            _buildErrorState()
          else if (_items.isEmpty)
            _buildEmptyState()
          else
            _buildFeedList(),
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWide)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180, maxHeight: 36),
              child: Image.asset(BrandingAssets.wordmark, fit: BoxFit.contain),
            )
          else ...[
            Image.asset(BrandingAssets.markIcon, width: 32, height: 32),
            const SizedBox(width: 10),
            Text(
              'The Skinning Shed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => _showFilters(context),
          tooltip: 'Filters',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: _selectedCategory == null,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              _CategoryChip(
                label: 'Deer',
                icon: '🦌',
                isSelected: _selectedCategory == 'deer',
                onTap: () => setState(() => _selectedCategory = 'deer'),
              ),
              _CategoryChip(
                label: 'Turkey',
                icon: '🦃',
                isSelected: _selectedCategory == 'turkey',
                onTap: () => setState(() => _selectedCategory = 'turkey'),
              ),
              _CategoryChip(
                label: 'Bass',
                icon: '🐟',
                isSelected: _selectedCategory == 'bass',
                onTap: () => setState(() => _selectedCategory = 'bass'),
              ),
              _CategoryChip(
                label: 'Other',
                isSelected: _selectedCategory == 'other',
                onTap: () => setState(() => _selectedCategory = 'other'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _items[index];
            return AnimatedEntry(
              delay: Duration(milliseconds: 50 * index),
              child: _TrophyFeedCard(
                imageUrl: item.imageUrl,
                species: item.species,
                speciesEmoji: item.speciesEmoji,
                category: item.category,
                location: item.location,
                date: item.date,
                stats: item.stats,
                userName: item.userName,
                userAvatar: item.userAvatar,
                likes: item.likes,
                comments: item.comments,
                onTap: () => context.push(item.route),
                onLike: () {},
                onComment: () {},
                onShare: () {},
              ),
            );
          },
          childCount: _items.length,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const FeedCardSkeleton(),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AnimatedEntry(
        child: ErrorState(
          title: 'Could not load feed',
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
          icon: Icons.emoji_events_rounded,
          title: 'No Trophies Yet',
          message: 'Be the first to share your harvest.',
          actionLabel: 'Post Trophy',
          onAction: () => context.push('/post'),
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODERN FEED CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _TrophyFeedCard extends StatefulWidget {
  const _TrophyFeedCard({
    required this.species,
    required this.speciesEmoji,
    required this.category,
    required this.location,
    required this.date,
    required this.stats,
    required this.userName,
    required this.likes,
    required this.comments,
    required this.onTap,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.imageUrl,
    this.userAvatar,
  });

  final String? imageUrl;
  final String species;
  final String speciesEmoji;
  final String category;
  final String location;
  final String date;
  final String stats;
  final String userName;
  final String? userAvatar;
  final int likes;
  final int comments;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  State<_TrophyFeedCard> createState() => _TrophyFeedCardState();
}

class _TrophyFeedCardState extends State<_TrophyFeedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: _isHovered ? 1.01 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.06 : 0.03),
                blurRadius: _isHovered ? 14 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              hoverColor: AppColors.primary.withOpacity(0.04),
              splashColor: AppColors.primary.withOpacity(0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserRow(context),
                        const SizedBox(height: 12),
                        Text(
                          widget.species,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stats,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.location,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.date,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildActionRow(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: widget.imageUrl != null
                ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getCategoryColor().withOpacity(0.1),
                          _getCategoryColor().withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.speciesEmoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
          ),
        ),
        // Species chip overlay
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.speciesEmoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  widget.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: widget.userAvatar != null
              ? null
              : Text(
                  widget.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.userName,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.favorite_border_rounded,
          label: widget.likes.toString(),
          onTap: widget.onLike,
        ),
        const SizedBox(width: 16),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: widget.comments.toString(),
          onTap: widget.onComment,
        ),
        const SizedBox(width: 16),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: widget.onShare,
        ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (widget.category.toLowerCase()) {
      case 'deer':
        return AppColors.categoryDeer;
      case 'turkey':
        return AppColors.categoryTurkey;
      case 'bass':
        return AppColors.categoryBass;
      default:
        return AppColors.primary;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppColors.primary.withOpacity(0.06),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem({
    required this.species,
    required this.speciesEmoji,
    required this.category,
    required this.location,
    required this.date,
    required this.stats,
    required this.userName,
    required this.likes,
    required this.comments,
    required this.route,
    this.imageUrl,
    this.userAvatar,
  });

  final String species;
  final String speciesEmoji;
  final String category;
  final String location;
  final String date;
  final String stats;
  final String userName;
  final int likes;
  final int comments;
  final String route;
  final String? imageUrl;
  final String? userAvatar;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY CHIP
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Text(icon!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
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

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _FiltersSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Filter options placeholder
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Texas', 'Alabama', 'Florida', 'Georgia']
                      .map((s) => FilterChip(
                            label: Text(s),
                            selected: false,
                            onSelected: (v) {},
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'TIME PERIOD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Today', 'This Week', 'This Month', 'This Season']
                      .map((s) => FilterChip(
                            label: Text(s),
                            selected: s == 'This Week',
                            onSelected: (v) {},
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

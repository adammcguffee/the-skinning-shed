import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/discover_service.dart';
import 'package:shed/shared/widgets/explore_category_tile.dart';

// Category map for feed filtering
const _categoryMap = {
  'Whitetail Deer': 'deer',
  'Turkey': 'turkey',
  'Largemouth Bass': 'bass',
  'Other Game': 'other',
};

/// High-quality category images (Unsplash - free to use, CC0 license).
/// These can be replaced with local assets or Supabase storage URLs.
/// 
/// Image selection criteria:
/// - Non-gory, conservation-friendly
/// - High quality, professional photography
/// - Good composition for cropping
/// - Works in both light and dark themes
const _categoryImages = {
  // Whitetail deer in forest - verified working
  'deer': 'https://images.unsplash.com/photo-1484406566174-9da000fda645?w=600&q=80',
  // Wild turkey in field
  'turkey': 'https://images.unsplash.com/photo-1574158346846-93e8aaf56b47?w=600&q=80',
  // Largemouth bass / fishing catch
  'bass': 'https://images.unsplash.com/photo-1545450660-3378a7f3a364?w=600&q=80',
  // Cottontail rabbit - small game
  'other': 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?w=600&q=80',
};

/// 🧭 EXPLORE SCREEN - 2025 CINEMATIC DARK THEME
///
/// Visual discovery gallery with:
/// - Banner logo header
/// - Visual species tiles with images
/// - Quick link cards
/// - Trending section (real data)
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return CustomScrollView(
      slivers: [
        // Banner header
        SliverToBoxAdapter(
          child: _buildHeader(context, isWide),
        ),

        // Species section - visual tiles
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Browse by Species',
            onSeeAll: () => context.go('/'), // Navigate to feed (shows all species)
          ),
        ),
        SliverToBoxAdapter(
          child: _SpeciesGrid(isWide: isWide),
        ),

        // Quick links section
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Quick Links',
            onSeeAll: null,
          ),
        ),
        SliverToBoxAdapter(
          child: _QuickLinksGrid(isWide: isWide),
        ),

        // Trending section (real data)
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Trending This Week',
            trailing: _TrendingBadge(),
            onSeeAll: () => context.go('/discover'),
          ),
        ),
        SliverToBoxAdapter(
          child: _TrendingList(),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    // Banner header is now rendered by AppScaffold
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onSeeAll,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xxl,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            'Hot',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Species/category grid with premium image-based tiles.
class _SpeciesGrid extends StatelessWidget {
  const _SpeciesGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ExploreCategoryData(
        name: 'Whitetail Deer',
        categoryKey: 'deer',
        color: AppColors.categoryDeer,
        imageUrl: _categoryImages['deer'],
        semanticLabel: 'Browse whitetail deer trophies',
      ),
      ExploreCategoryData(
        name: 'Turkey',
        categoryKey: 'turkey',
        color: AppColors.categoryTurkey,
        imageUrl: _categoryImages['turkey'],
        semanticLabel: 'Browse turkey trophies',
      ),
      ExploreCategoryData(
        name: 'Largemouth Bass',
        categoryKey: 'bass',
        color: AppColors.categoryBass,
        imageUrl: _categoryImages['bass'],
        semanticLabel: 'Browse largemouth bass catches',
      ),
      ExploreCategoryData(
        name: 'Other Game',
        categoryKey: 'other',
        color: AppColors.categoryOtherGame,
        imageUrl: _categoryImages['other'],
        semanticLabel: 'Browse other game and fish',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 4 : 2,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: isWide ? 1.0 : 0.85,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return ExploreCategoryTile(
            data: category,
            onTap: () {
              // Navigate to feed with category filter
              context.go('/?category=${category.categoryKey}');
            },
          );
        },
      ),
    );
  }
}

class _QuickLinksGrid extends StatelessWidget {
  const _QuickLinksGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final links = [
      _QuickLinkData(
        title: 'Land Listings',
        subtitle: 'Find hunting land',
        icon: Icons.landscape_rounded,
        route: '/land',
      ),
      _QuickLinkData(
        title: 'Swap Shop',
        subtitle: 'Buy & sell gear',
        icon: Icons.storefront_rounded,
        route: '/swap-shop',
      ),
      _QuickLinkData(
        title: 'Weather',
        subtitle: 'Conditions & tools',
        icon: Icons.cloud_rounded,
        route: '/weather',
      ),
      _QuickLinkData(
        title: 'Trophy Wall',
        subtitle: 'Your profile',
        icon: Icons.emoji_events_rounded,
        route: '/trophy-wall',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 4 : 2,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: isWide ? 2.2 : 1.8,
        ),
        itemCount: links.length,
        itemBuilder: (context, index) => _QuickLinkCard(data: links[index]),
      ),
    );
  }
}

class _QuickLinkData {
  const _QuickLinkData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _QuickLinkCard extends StatefulWidget {
  const _QuickLinkCard({required this.data});

  final _QuickLinkData data;

  @override
  State<_QuickLinkCard> createState() => _QuickLinkCardState();
}

class _QuickLinkCardState extends State<_QuickLinkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.data.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowCard : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _isHovered ? AppColors.accentGradient : null,
                    color: _isHovered ? null : AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    widget.data.icon,
                    color: _isHovered ? AppColors.textInverse : AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.data.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: _isHovered ? AppColors.accent : AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingPostsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: trendingAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 40,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'No trending posts this week',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Be the first to share your trophy!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: posts.take(5).map((post) => _TrendingCard(post: post)).toList(),
          );
        },
        loading: () => Column(
          children: List.generate(3, (_) => _TrendingCardSkeleton()),
        ),
        error: (e, _) => Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Text(
            'Unable to load trending posts',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends ConsumerStatefulWidget {
  const _TrendingCard({required this.post});

  final TrendingPost post;

  @override
  ConsumerState<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends ConsumerState<_TrendingCard> {
  bool _isHovered = false;

  Color get _speciesColor {
    switch (widget.post.category?.toLowerCase()) {
      case 'deer':
        return AppColors.categoryDeer;
      case 'turkey':
        return AppColors.categoryTurkey;
      case 'bass':
        return AppColors.categoryBass;
      default:
        return AppColors.categoryOtherGame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoverService = ref.read(discoverServiceProvider);
    final photoUrl = discoverService.getPhotoUrl(widget.post.coverPhotoPath);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/trophy/${widget.post.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowCard : null,
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: _speciesColor.withValues(alpha: 0.2),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => context.push('/user/${widget.post.userId}'),
                      child: Text(
                        'by ${widget.post.userName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Likes pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.likesCount.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _speciesColor.withValues(alpha: 0.3),
            AppColors.surface,
          ],
        ),
      ),
      child: Icon(
        Icons.image_rounded,
        color: _speciesColor.withValues(alpha: 0.5),
      ),
    );
  }
}

class _TrendingCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(4),
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

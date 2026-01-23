import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🧭 EXPLORE SCREEN - 2025 PREMIUM
///
/// Discovery hub with modern cards and clear hierarchy.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Explore',
            subtitle: 'Discover species, regions & more',
            onSearch: () {},
          ),

        // Content
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Mobile header
              if (!isWide)
                const SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: 'Explore',
                    subtitle: 'Discover species, regions & more',
                  ),
                ),

              // Species section
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Browse by Species',
                  onSeeAll: () {},
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

              // Trending section
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Trending This Week',
                  onSeeAll: () {},
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
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onSeeAll,
  });

  final String title;
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

class _SpeciesGrid extends StatelessWidget {
  const _SpeciesGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final species = [
      _SpeciesData(
        name: 'Whitetail Deer',
        icon: Icons.pets_rounded,
        color: AppColors.categoryDeer,
        count: 1247,
      ),
      _SpeciesData(
        name: 'Turkey',
        icon: Icons.flutter_dash_rounded,
        color: AppColors.categoryTurkey,
        count: 856,
      ),
      _SpeciesData(
        name: 'Largemouth Bass',
        icon: Icons.water_rounded,
        color: AppColors.categoryBass,
        count: 623,
      ),
      _SpeciesData(
        name: 'Other Game',
        icon: Icons.forest_rounded,
        color: AppColors.categoryOtherGame,
        count: 412,
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
          childAspectRatio: isWide ? 1.3 : 1.1,
        ),
        itemCount: species.length,
        itemBuilder: (context, index) => _SpeciesCard(data: species[index]),
      ),
    );
  }
}

class _SpeciesData {
  const _SpeciesData({
    required this.name,
    required this.icon,
    required this.color,
    required this.count,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int count;
}

class _SpeciesCard extends StatefulWidget {
  const _SpeciesCard({required this.data});

  final _SpeciesData data;

  @override
  State<_SpeciesCard> createState() => _SpeciesCardState();
}

class _SpeciesCardState extends State<_SpeciesCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? widget.data.color.withOpacity(0.3) : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.data.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    widget.data.icon,
                    color: widget.data.color,
                    size: 24,
                  ),
                ),
                const Spacer(),

                // Name
                Text(
                  widget.data.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Count
                Text(
                  '${widget.data.count} posts',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    widget.data.icon,
                    color: AppColors.primary,
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
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.data.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: _isHovered ? AppColors.textPrimary : AppColors.textTertiary,
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

class _TrendingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trending = [
      _TrendingItem(
        title: '12-Point Buck in Texas',
        subtitle: 'Posted by @hunter_joe',
        likes: 234,
      ),
      _TrendingItem(
        title: 'Opening Day Turkey',
        subtitle: 'Posted by @wild_tom',
        likes: 189,
      ),
      _TrendingItem(
        title: 'Personal Best Bass',
        subtitle: 'Posted by @bass_master',
        likes: 156,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: trending
            .map((item) => _TrendingCard(data: item))
            .toList(),
      ),
    );
  }
}

class _TrendingItem {
  const _TrendingItem({
    required this.title,
    required this.subtitle,
    required this.likes,
  });

  final String title;
  final String subtitle;
  final int likes;
}

class _TrendingCard extends StatefulWidget {
  const _TrendingCard({required this.data});

  final _TrendingItem data;

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
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
          ),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Likes
              Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.data.likes.toString(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

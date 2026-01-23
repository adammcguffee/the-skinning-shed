import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏆 TROPHY WALL SCREEN - 2025 PREMIUM
///
/// Modern profile with stats and trophy grid.
class TrophyWallScreen extends ConsumerStatefulWidget {
  const TrophyWallScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<TrophyWallScreen> createState() => _TrophyWallScreenState();
}

class _TrophyWallScreenState extends ConsumerState<TrophyWallScreen> {
  List<Map<String, dynamic>> _trophies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrophies();
  }

  Future<void> _loadTrophies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trophyService = ref.read(trophyServiceProvider);
      final userId = widget.userId ?? ref.read(supabaseClientProvider)?.auth.currentUser?.id ?? '';
      final trophies = await trophyService.fetchUserTrophies(userId);
      setState(() {
        _trophies = trophies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Trophy Wall',
            actions: [
              AppButtonSecondary(
                label: 'Edit Profile',
                icon: Icons.edit_outlined,
                onPressed: () {},
                size: AppButtonSize.small,
              ),
            ],
          ),

        // Content
        Expanded(
          child: _buildContent(context, isWide),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isWide) {
    return CustomScrollView(
      slivers: [
        // Profile header
        SliverToBoxAdapter(
          child: _ProfileHeader(isWide: isWide),
        ),

        // Stats
        SliverToBoxAdapter(
          child: _StatsSection(trophyCount: _trophies.length),
        ),

        // Season tabs
        SliverToBoxAdapter(
          child: _SeasonTabs(),
        ),

        // Content
        if (_isLoading)
          SliverToBoxAdapter(
            child: _buildLoadingState(isWide),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: AppErrorState(
              message: _error!,
              onRetry: _loadTrophies,
            ),
          )
        else if (_trophies.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No trophies yet',
              message: 'Start building your trophy wall by posting your first harvest.',
              actionLabel: 'Post Trophy',
              onAction: () => context.push('/post'),
            ),
          )
        else
          _buildTrophyGrid(context, isWide),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
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
          childAspectRatio: 1,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const AppCardSkeleton(
          aspectRatio: 1,
          hasContent: false,
        ),
      ),
    );
  }

  Widget _buildTrophyGrid(BuildContext context, bool isWide) {
    final crossAxisCount = isWide ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _TrophyGridItem(
            trophy: _trophies[index],
            onTap: () => context.push('/trophy/${_trophies[index]['id']}'),
          ),
          childCount: _trophies.length,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.screenPadding),
      child: Row(
        children: [
          // Avatar
          Container(
            width: isWide ? 100 : 80,
            height: isWide ? 100 : 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 3,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hunter Name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '@huntername',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Texas, USA',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Edit button (mobile)
          if (!isWide)
            AppIconButton(
              icon: Icons.edit_outlined,
              onPressed: () {},
              tooltip: 'Edit Profile',
            ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.trophyCount});

  final int trophyCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          _StatPill(
            label: 'Trophies',
            value: trophyCount.toString(),
            icon: Icons.emoji_events_rounded,
          ),
          const SizedBox(width: AppSpacing.sm),
          const _StatPill(
            label: 'Seasons',
            value: '3',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(width: AppSpacing.sm),
          const _StatPill(
            label: 'Followers',
            value: '124',
            icon: Icons.people_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SeasonTabs extends StatefulWidget {
  @override
  State<_SeasonTabs> createState() => _SeasonTabsState();
}

class _SeasonTabsState extends State<_SeasonTabs> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final seasons = ['All Time', '2024-25', '2023-24', '2022-23'];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            seasons.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index < seasons.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _SeasonTab(
                label: seasons[index],
                isSelected: _selectedIndex == index,
                onTap: () => setState(() => _selectedIndex = index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonTab extends StatefulWidget {
  const _SeasonTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SeasonTab> createState() => _SeasonTabState();
}

class _SeasonTabState extends State<_SeasonTab> {
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: widget.isSelected
                ? null
                : Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? AppColors.textInverse
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrophyGridItem extends StatefulWidget {
  const _TrophyGridItem({
    required this.trophy,
    required this.onTap,
  });

  final Map<String, dynamic> trophy;
  final VoidCallback onTap;

  @override
  State<_TrophyGridItem> createState() => _TrophyGridItemState();
}

class _TrophyGridItemState extends State<_TrophyGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final species = widget.trophy['species']?['name'] ?? 'Unknown';
    final imageUrl = widget.trophy['trophy_media']?.isNotEmpty == true
        ? widget.trophy['trophy_media'][0]['url']
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.03))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

              // Species chip
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    species,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
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
    return Container(
      color: AppColors.backgroundAlt,
      child: const Center(
        child: Icon(
          Icons.emoji_events_outlined,
          size: 32,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

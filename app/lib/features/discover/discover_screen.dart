import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/discover_service.dart';
import 'package:shed/services/follow_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🔍 DISCOVER SCREEN - Find and follow other hunters
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _searchQuery = query.trim());
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(searchUsersProvider(_searchQuery));
    final trendingAsync = ref.watch(trendingPostsProvider);

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Find hunters and see trending trophies',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search hunters by name...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _clearSearch,
                        color: AppColors.textTertiary,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // Users section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _searchQuery.isEmpty ? 'Suggested Hunters' : 'Search Results',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Users list
        usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: _EmptyState(
                    icon: Icons.person_search_outlined,
                    message: _searchQuery.isEmpty
                        ? 'No hunters to suggest yet'
                        : 'No hunters found for "$_searchQuery"',
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _UserCard(user: users[index]),
                  childCount: users.length,
                ),
              ),
            );
          },
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: List.generate(
                  4,
                  (index) => const _UserCardSkeleton(),
                ),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: _EmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Error loading hunters',
              ),
            ),
          ),
        ),

        // Trending section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xxl,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Text(
                  'Trending This Week',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text(
                    'Hot',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Trending posts
        trendingAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: _EmptyState(
                    icon: Icons.trending_up_rounded,
                    message: 'No trending posts this week',
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _TrendingPostCard(post: posts[index]),
                  childCount: posts.length,
                ),
              ),
            );
          },
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: List.generate(
                  3,
                  (index) => const _TrendingPostCardSkeleton(),
                ),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: _EmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Error loading trending posts',
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

/// User card in discover list.
class _UserCard extends ConsumerStatefulWidget {
  const _UserCard({required this.user});

  final DiscoverUser user;

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _isHovered = false;
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.user.isFollowing;
  }

  Future<void> _toggleFollow() async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow users')),
      );
      context.push('/auth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final followService = ref.read(followServiceProvider);
      final newState = await followService.toggleFollow(widget.user.id);
      if (mounted) {
        setState(() {
          _isFollowing = newState;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoverService = ref.read(discoverServiceProvider);
    final avatarUrl = discoverService.getAvatarUrl(widget.user.avatarPath);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/user/${widget.user.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.user.handle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.user.handle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${widget.user.followersCount} followers',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (widget.user.postCount != null) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            '${widget.user.postCount} posts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Follow button
              _FollowButton(
                isFollowing: _isFollowing,
                isLoading: _isLoading,
                onPressed: _toggleFollow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Follow/Unfollow button.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 32,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? AppColors.surface : AppColors.accent,
          foregroundColor: isFollowing ? AppColors.textPrimary : AppColors.textInverse,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            side: BorderSide(
              color: isFollowing ? AppColors.borderStrong : AppColors.accent,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.textTertiary),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Trending post card.
class _TrendingPostCard extends ConsumerStatefulWidget {
  const _TrendingPostCard({required this.post});

  final TrendingPost post;

  @override
  ConsumerState<_TrendingPostCard> createState() => _TrendingPostCardState();
}

class _TrendingPostCardState extends ConsumerState<_TrendingPostCard> {
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
    final avatarUrl = discoverService.getAvatarUrl(widget.post.userAvatarPath);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/trophy/${widget.post.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _speciesColor.withValues(alpha: 0.1),
                ),
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
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
                      const SizedBox(height: 4),

                      // User info
                      GestureDetector(
                        onTap: () => context.push('/user/${widget.post.userId}'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                              backgroundImage:
                                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(
                                      widget.post.userName.isNotEmpty
                                          ? widget.post.userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.post.userName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Likes badge
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: _speciesColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.image_rounded,
        size: 24,
        color: _speciesColor.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Empty state widget.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for user card.
class _UserCardSkeleton extends StatelessWidget {
  const _UserCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 120,
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
          Container(
            width: 80,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for trending post card.
class _TrendingPostCardSkeleton extends StatelessWidget {
  const _TrendingPostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppSpacing.radiusMd - 1),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(4),
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

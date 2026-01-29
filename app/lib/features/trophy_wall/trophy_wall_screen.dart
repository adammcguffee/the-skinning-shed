import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/follow_service.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:shed/utils/season_utils.dart';

// Season filter value - null means "All Time"
typedef SeasonYear = int?;

/// Species category filter for trophy wall.
enum SpeciesCategory {
  all,
  game,
  fish,
}

/// Trophy category enum values from database.
/// Game = deer, turkey, other_game
/// Fish = bass, other_fishing
const _gameCategories = ['deer', 'turkey', 'other_game'];
const _fishCategories = ['bass', 'other_fishing'];

/// User profile data model.
class UserProfile {
  UserProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarPath,
    this.bio,
    this.defaultState,
    this.defaultCounty,
  });
  
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  final String? bio;
  final String? defaultState;
  final String? defaultCounty;
  
  String get name => displayName ?? username ?? 'Hunter';
  String get handle => username != null ? '@$username' : '';
  String? get location {
    if (defaultState != null && defaultCounty != null) {
      return '$defaultCounty, $defaultState';
    }
    return defaultState;
  }
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      bio: json['bio'] as String?,
      defaultState: json['default_state'] as String?,
      defaultCounty: json['default_county'] as String?,
    );
  }
}

/// 🏆 TROPHY WALL SCREEN - 2025 CINEMATIC DARK THEME
///
/// Premium profile with:
/// - Dark themed profile header
/// - Stats in bold accent pills
/// - Trophy grid matching feed styling
/// - Season filter tabs
class TrophyWallScreen extends ConsumerStatefulWidget {
  const TrophyWallScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<TrophyWallScreen> createState() => _TrophyWallScreenState();
}

class _TrophyWallScreenState extends ConsumerState<TrophyWallScreen> {
  List<Map<String, dynamic>> _allTrophies = [];
  List<Map<String, dynamic>> _filteredTrophies = [];
  bool _isLoading = true;
  String? _error;
  SeasonYear _selectedSeason; // null = All Time
  SpeciesCategory _selectedCategory = SpeciesCategory.all;
  UserProfile? _profile;
  bool _isOwnProfile = false;
  String? _targetUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('Not connected');
      
      final currentUserId = client.auth.currentUser?.id;
      _targetUserId = widget.userId ?? currentUserId;
      _isOwnProfile = _targetUserId == currentUserId;
      
      if (_targetUserId == null) throw Exception('No user ID');
      
      // Load profile
      final profileResponse = await client
          .from('profiles')
          .select()
          .eq('id', _targetUserId!)
          .maybeSingle();
      
      if (profileResponse != null) {
        _profile = UserProfile.fromJson(profileResponse);
      }
      
      // Load trophies
      final trophyService = ref.read(trophyServiceProvider);
      final trophies = await trophyService.fetchUserTrophies(_targetUserId!);
      
      setState(() {
        _allTrophies = trophies;
        _filteredTrophies = _applyFilters(trophies);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  /// Apply both category and season filters.
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trophies) {
    var filtered = trophies;
    
    // Filter by species category
    // The 'category' field is directly on trophy_posts, not on species
    // Enum values: deer, turkey, bass, other_game, other_fishing
    if (_selectedCategory != SpeciesCategory.all) {
      filtered = filtered.where((t) {
        final category = t['category'] as String?;
        if (category == null) return false;
        
        if (_selectedCategory == SpeciesCategory.game) {
          return _gameCategories.contains(category);
        } else {
          return _fishCategories.contains(category);
        }
      }).toList();
    }
    
    // Filter by season
    if (_selectedSeason != null) {
      filtered = filtered.where((t) {
        final dateStr = t['harvest_date'] as String?;
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr);
          // Determine season type based on the trophy's category
          final category = t['category'] as String?;
          final isGame = _gameCategories.contains(category);
          final seasonType = isGame ? SeasonType.huntingSeason : SeasonType.calendarYear;
          final season = Season(
            type: seasonType,
            label: '',
            yearStart: _selectedSeason!,
            yearEnd: seasonType == SeasonType.huntingSeason ? _selectedSeason! + 1 : null,
          );
          return SeasonUtils.isInSeason(date, season);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    
    return filtered;
  }
  
  void _onCategoryChanged(SpeciesCategory category) {
    setState(() {
      _selectedCategory = category;
      // Reset season when category changes since season format differs
      _selectedSeason = null;
      _filteredTrophies = _applyFilters(_allTrophies);
    });
  }
  
  void _onSeasonChanged(SeasonYear season) {
    setState(() {
      _selectedSeason = season;
      _filteredTrophies = _applyFilters(_allTrophies);
    });
  }
  
  /// Get the appropriate season type for the current category filter.
  SeasonType get _currentSeasonType {
    switch (_selectedCategory) {
      case SpeciesCategory.fish:
        return SeasonType.calendarYear;
      case SpeciesCategory.game:
      case SpeciesCategory.all:
        // Default to hunting seasons for "All" since most trophies are game
        return SeasonType.huntingSeason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return CustomScrollView(
      slivers: [
        // Profile header with banner
        SliverToBoxAdapter(
          child: _ProfileHeader(
            isWide: isWide,
            trophyCount: _allTrophies.length,
            profile: _profile,
            isOwnProfile: _isOwnProfile,
            targetUserId: _targetUserId,
          ),
        ),

        // Category and season filters
        SliverToBoxAdapter(
          child: _CategoryAndSeasonFilters(
            selectedCategory: _selectedCategory,
            selectedSeason: _selectedSeason,
            seasonType: _currentSeasonType,
            onCategoryChanged: _onCategoryChanged,
            onSeasonChanged: _onSeasonChanged,
          ),
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
              onRetry: _loadData,
            ),
          )
        else if (_filteredTrophies.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: _selectedSeason == null ? 'No trophies yet' : 'No trophies this season',
              message: _selectedSeason == null
                  ? 'Start building your trophy wall by posting your first harvest.'
                  : _currentSeasonType == SeasonType.calendarYear
                      ? 'No trophies recorded for $_selectedSeason.'
                      : 'No trophies recorded for the $_selectedSeason-${(_selectedSeason! + 1).toString().substring(2)} season.',
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
            trophy: _filteredTrophies[index],
            onTap: () => context.push('/trophy/${_filteredTrophies[index]['id']}'),
          ),
          childCount: _filteredTrophies.length,
        ),
      ),
    );
  }
}

/// Premium dark profile header with banner, avatar, stats, follow button
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.isWide,
    required this.trophyCount,
    required this.profile,
    required this.isOwnProfile,
    required this.targetUserId,
  });

  final bool isWide;
  final int trophyCount;
  final UserProfile? profile;
  final bool isOwnProfile;
  final String? targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get follow state for this user
    final followState = targetUserId != null
        ? ref.watch(followStateNotifierProvider(targetUserId!))
        : null;
    
    final followerCount = followState?.counts?.followers ?? 0;
    final followingCount = followState?.counts?.following ?? 0;
    final isFollowing = followState?.isFollowing ?? false;
    
    return Column(
      children: [
        // Profile content with gradient
        Container(
          padding: EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.background,
              ],
            ),
          ),
          child: Column(
            children: [
              // Profile info row - responsive layout
              if (isWide)
                // Wide layout: Avatar + Info + Buttons in row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(context, ref),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Hunter',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (profile?.handle.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile!.handle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                          if (profile?.location != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile!.location!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isOwnProfile)
                      _EditProfileButton()
                    else if (targetUserId != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MessageButton(targetUserId: targetUserId!),
                          const SizedBox(width: AppSpacing.sm),
                          _FollowButton(
                            isFollowing: isFollowing,
                            isLoading: followState?.isLoading ?? false,
                            onTap: () {
                              ref
                                  .read(followStateNotifierProvider(targetUserId!).notifier)
                                  .toggleFollow();
                            },
                          ),
                        ],
                      ),
                  ],
                )
              else
                // Mobile layout: Avatar + Info stacked, buttons below
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(context, ref),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.name ?? 'Hunter',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (profile?.handle.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  profile!.handle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                              if (profile?.location != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        profile!.location!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Buttons below profile info on mobile
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (isOwnProfile)
                          Expanded(child: _EditProfileButton())
                        else if (targetUserId != null) ...[
                          Expanded(
                            child: _MessageButton(targetUserId: targetUserId!),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _FollowButton(
                              isFollowing: isFollowing,
                              isLoading: followState?.isLoading ?? false,
                              onTap: () {
                                ref
                                    .read(followStateNotifierProvider(targetUserId!).notifier)
                                    .toggleFollow();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),

              // Stats pills - wrap on mobile
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _StatPill(
                    label: 'Trophies',
                    value: trophyCount.toString(),
                    icon: Icons.emoji_events_rounded,
                    isAccent: true,
                  ),
                  _StatPill(
                    label: 'Followers',
                    value: followerCount.toString(),
                    icon: Icons.people_rounded,
                    onTap: targetUserId != null
                        ? () => _showFollowersList(context, ref, targetUserId!, true)
                        : null,
                  ),
                  _StatPill(
                    label: 'Following',
                    value: followingCount.toString(),
                    icon: Icons.person_add_rounded,
                    onTap: targetUserId != null
                        ? () => _showFollowersList(context, ref, targetUserId!, false)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAvatar(BuildContext context, WidgetRef ref) {
    final avatarPath = profile?.avatarPath;
    Widget avatarContent;
    
    if (avatarPath != null) {
      final followService = ref.read(followServiceProvider);
      final url = followService.getAvatarUrl(avatarPath);
      avatarContent = ClipOval(
        child: Image.network(
          url ?? '',
          fit: BoxFit.cover,
          width: isWide ? 94 : 74,
          height: isWide ? 94 : 74,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person_rounded,
            size: 40,
            color: AppColors.textSecondary,
          ),
        ),
      );
    } else {
      avatarContent = const Center(
        child: Icon(
          Icons.person_rounded,
          size: 40,
          color: AppColors.textSecondary,
        ),
      );
    }
    
    Widget avatar = Container(
      width: isWide ? 100 : 80,
      height: isWide ? 100 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: AppColors.shadowAccent,
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarContent,
      ),
    );
    
    // Make avatar clickable for own profile
    if (isOwnProfile) {
      return Stack(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.push('/profile/edit'),
              child: avatar,
            ),
          ),
          // Camera badge
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => context.push('/profile/edit'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                  boxShadow: AppColors.shadowCard,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: AppColors.textInverse,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return avatar;
  }
  
  void _showFollowersList(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool showFollowers,
  ) {
    // Use showShedCenterModal for proper full-screen barrier dismiss
    showShedCenterModal(
      context: context,
      title: showFollowers ? 'Followers' : 'Following',
      maxWidth: 480,
      maxHeight: MediaQuery.of(context).size.height * 0.7,
      child: _FollowListContent(
        userId: userId,
        showFollowers: showFollowers,
      ),
    );
  }
}

class _MessageButton extends ConsumerStatefulWidget {
  const _MessageButton({required this.targetUserId});
  
  final String targetUserId;
  
  @override
  ConsumerState<_MessageButton> createState() => _MessageButtonState();
}

class _MessageButtonState extends ConsumerState<_MessageButton> {
  bool _isHovered = false;
  bool _isLoading = false;

  Future<void> _openMessage() async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      context.push('/auth');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final messagingService = ref.read(messagingServiceProvider);
      final conversationId = await messagingService.getOrCreateDM(
        otherUserId: widget.targetUserId,
      );
      
      if (mounted) {
        context.push('/messages/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _isLoading ? null : _openMessage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.accent : AppColors.borderSubtle,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: _isHovered ? AppColors.accent : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EditProfileButton extends StatefulWidget {
  @override
  State<_EditProfileButton> createState() => _EditProfileButtonState();
}

class _EditProfileButtonState extends State<_EditProfileButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigate to profile edit screen
          context.push('/profile/edit');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Follow/Unfollow button with loading state
class _FollowButton extends StatefulWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.isFollowing;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: !isFollowing ? AppColors.accentGradient : null,
            color: isFollowing 
                ? (_isHovered ? AppColors.error.withValues(alpha: 0.1) : AppColors.surface)
                : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isFollowing 
                ? Border.all(
                    color: _isHovered ? AppColors.error : AppColors.borderSubtle,
                  )
                : null,
            boxShadow: !isFollowing ? AppColors.shadowAccent : null,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowing
                          ? (_isHovered ? Icons.person_remove_rounded : Icons.check_rounded)
                          : Icons.person_add_rounded,
                      size: 16,
                      color: isFollowing
                          ? (_isHovered ? AppColors.error : AppColors.textPrimary)
                          : AppColors.textInverse,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowing 
                          ? (_isHovered ? 'Unfollow' : 'Following')
                          : 'Follow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFollowing
                            ? (_isHovered ? AppColors.error : AppColors.textPrimary)
                            : AppColors.textInverse,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Content for followers or following list (used inside showShedCenterModal)
class _FollowListContent extends ConsumerStatefulWidget {
  const _FollowListContent({
    required this.userId,
    required this.showFollowers,
  });

  final String userId;
  final bool showFollowers;

  @override
  ConsumerState<_FollowListContent> createState() => _FollowListContentState();
}

class _FollowListContentState extends ConsumerState<_FollowListContent> {
  List<UserSummary>? _users;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final followService = ref.read(followServiceProvider);
      final users = widget.showFollowers
          ? await followService.getFollowers(widget.userId)
          : await followService.getFollowing(widget.userId);
      
      setState(() {
        _users = users;
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
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Error loading users',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_users == null || _users!.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.showFollowers ? Icons.people_outline_rounded : Icons.person_search_rounded,
                color: AppColors.textTertiary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.showFollowers
                    ? 'No followers yet'
                    : 'Not following anyone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Use Column instead of ListView for modal content (modal handles scrolling)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int index = 0; index < _users!.length; index++)
          _UserListTile(
            user: _users![index],
            onFollowToggle: () => _toggleFollow(index),
          ),
      ],
    );
  }

  Future<void> _toggleFollow(int index) async {
    final user = _users![index];
    try {
      final followService = ref.read(followServiceProvider);
      final newState = await followService.toggleFollow(user.id);
      setState(() {
        _users![index].isFollowing = newState;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

/// User list tile for followers/following lists
class _UserListTile extends StatefulWidget {
  const _UserListTile({
    required this.user,
    required this.onFollowToggle,
  });

  final UserSummary user;
  final VoidCallback onFollowToggle;

  @override
  State<_UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends State<_UserListTile> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: widget.user.avatarPath != null
            ? const Icon(Icons.person_rounded, color: AppColors.textSecondary)
            : const Icon(Icons.person_rounded, color: AppColors.textSecondary),
      ),
      title: Text(
        widget.user.name,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: widget.user.username != null
          ? Text(
              '@${widget.user.username}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          : null,
      trailing: GestureDetector(
        onTap: _isToggling
            ? null
            : () async {
                setState(() => _isToggling = true);
                widget.onFollowToggle();
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) setState(() => _isToggling = false);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: widget.user.isFollowing
                ? AppColors.surface
                : AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: widget.user.isFollowing
                ? Border.all(color: AppColors.borderSubtle)
                : null,
          ),
          child: _isToggling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.user.isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.user.isFollowing
                        ? AppColors.textPrimary
                        : Colors.white,
                  ),
                ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        context.push('/user/${widget.user.id}');
      },
    );
  }
}

/// Stat pill with bold accent styling
class _StatPill extends StatefulWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.isAccent = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isAccent;
  final VoidCallback? onTap;

  @override
  State<_StatPill> createState() => _StatPillState();
}

class _StatPillState extends State<_StatPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isTappable = widget.onTap != null;
    
    return MouseRegion(
      onEnter: isTappable ? (_) => setState(() => _isHovered = true) : null,
      onExit: isTappable ? (_) => setState(() => _isHovered = false) : null,
      cursor: isTappable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isAccent 
                ? AppColors.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: widget.isAccent 
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : _isHovered
                      ? AppColors.borderStrong
                      : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isAccent ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.isAccent ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Season filter tabs
/// Combined category and season filter widget with species-aware seasons.
class _CategoryAndSeasonFilters extends StatelessWidget {
  const _CategoryAndSeasonFilters({
    required this.selectedCategory,
    required this.selectedSeason,
    required this.seasonType,
    required this.onCategoryChanged,
    required this.onSeasonChanged,
  });
  
  final SpeciesCategory selectedCategory;
  final SeasonYear selectedSeason;
  final SeasonType seasonType;
  final ValueChanged<SpeciesCategory> onCategoryChanged;
  final ValueChanged<SeasonYear> onSeasonChanged;
  
  // Generate season options based on season type
  List<({String label, SeasonYear value})> get _seasons {
    final seasonOptions = SeasonUtils.generateSeasonOptions(
      type: seasonType,
      yearsBack: 3,
    );
    
    return [
      (label: 'All Time', value: null),
      ...seasonOptions.map((s) => (label: s.label, value: s.yearStart)),
    ];
  }
  
  static const _categoryOptions = [
    (label: 'All', value: SpeciesCategory.all, icon: Icons.grid_view_rounded),
    (label: 'Game', value: SpeciesCategory.game, icon: Icons.pets_rounded),
    (label: 'Fish', value: SpeciesCategory.fish, icon: Icons.water_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final seasons = _seasons;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter row
          Row(
            children: [
              Text(
                'Show:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ...List.generate(
                _categoryOptions.length,
                (index) {
                  final opt = _categoryOptions[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _categoryOptions.length - 1 ? AppSpacing.xs : 0,
                    ),
                    child: _FilterChip(
                      label: opt.label,
                      icon: opt.icon,
                      isSelected: selectedCategory == opt.value,
                      onTap: () => onCategoryChanged(opt.value),
                      compact: true,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Season filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  seasonType == SeasonType.calendarYear ? 'Year:' : 'Season:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ...List.generate(
                  seasons.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      right: index < seasons.length - 1 ? AppSpacing.xs : 0,
                    ),
                    child: _FilterChip(
                      label: seasons[index].label,
                      isSelected: selectedSeason == seasons[index].value,
                      onTap: () => onSeasonChanged(seasons[index].value),
                    ),
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

/// Reusable filter chip for category and season.
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isSelected || _isHovered;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.sm : AppSpacing.md,
            vertical: widget.compact ? 6 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : showHighlight
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : showHighlight
                      ? AppColors.border
                      : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.compact ? 14 : 16,
                  color: widget.isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.compact ? 12 : 13,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trophy grid item with cinematic styling
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

  Color get _speciesColor {
    // Use the category field directly from trophy_posts
    final category = (widget.trophy['category'] as String?) ?? '';
    switch (category) {
      case 'deer':
        return AppColors.categoryDeer;
      case 'turkey':
        return AppColors.categoryTurkey;
      case 'bass':
        return AppColors.categoryBass;
      case 'other_fishing':
        return AppColors.categoryBass; // Use bass color for fishing
      default:
        return AppColors.categoryOtherGame;
    }
  }
  
  String get _speciesName {
    // Get species name: prefer species.common_name, fallback to category label
    final speciesName = widget.trophy['species']?['common_name'] as String?;
    if (speciesName != null && speciesName.isNotEmpty) return speciesName;
    
    // Custom species name fallback
    final customName = widget.trophy['custom_species_name'] as String?;
    if (customName != null && customName.isNotEmpty) return customName;
    
    // Fallback to category display name
    final category = widget.trophy['category'] as String?;
    switch (category) {
      case 'deer': return 'Deer';
      case 'turkey': return 'Turkey';
      case 'bass': return 'Bass';
      case 'other_game': return 'Other Game';
      case 'other_fishing': return 'Other Fish';
      default: return 'Trophy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final species = _speciesName;
    
    // Resolve cover photo to public URL - prefer thumbnail for feed cards
    final coverThumbPath = widget.trophy['cover_thumb_path'] as String?;
    final coverPhotoPath = widget.trophy['cover_photo_path'] as String?;
    final photoPath = coverThumbPath ?? coverPhotoPath; // Prefer thumb, fall back to original
    
    String? imageUrl;
    if (photoPath != null) {
      final client = SupabaseService.instance.client;
      if (client != null) {
        imageUrl = client.storage.from('trophy_photos').getPublicUrl(photoPath);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -4.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? _speciesColor.withOpacity(0.5) : AppColors.borderSubtle,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _speciesColor.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppColors.shadowCard,
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
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.0, 0.5, 1.0],
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
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _speciesColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: _speciesColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    species,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _speciesColor.withValues(alpha: 0.25),
            AppColors.surface,
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 28,
            color: _speciesColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'No photo',
            style: TextStyle(
              fontSize: 10,
              color: _speciesColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

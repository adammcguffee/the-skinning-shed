import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/config/dev_flags.dart';
import 'package:shed/services/dev_user_service.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

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
  List<Map<String, dynamic>> _trophies = [];
  bool _isLoading = true;
  String? _error;
  String? _effectiveUserId;

  @override
  void initState() {
    super.initState();
    _loadTrophies();
  }

  /// Get the user ID to display trophies for.
  String? _getEffectiveUserId() {
    // Explicit user ID passed via route (viewing another user)
    if (widget.userId != null) return widget.userId;
    
    // Real Supabase user
    final supabaseUser = ref.read(supabaseClientProvider)?.auth.currentUser;
    if (supabaseUser != null) return supabaseUser.id;
    
    // Dev user selection (in dev bypass mode)
    if (DevFlags.isDevBypassAuthEnabled) {
      final devUser = ref.read(devUserNotifierProvider);
      return devUser.selectedUserId;
    }
    
    return null;
  }

  Future<void> _loadTrophies() async {
    final userId = _getEffectiveUserId();
    
    setState(() {
      _isLoading = true;
      _error = null;
      _effectiveUserId = userId;
    });

    // No user ID available - don't try to load
    if (userId == null || userId.isEmpty) {
      setState(() {
        _trophies = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final trophyService = ref.read(trophyServiceProvider);
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
    
    // Check if we're in dev mode without a user selected
    final authNotifier = ref.watch(authNotifierProvider);
    final isDevBypass = authNotifier.isDevBypass;
    final devUser = ref.watch(devUserNotifierProvider);
    
    // If dev bypass mode and no user selected (and not viewing a specific user via route),
    // show the user picker
    if (isDevBypass && widget.userId == null && !devUser.hasSelectedUser) {
      return _DevUserPickerView(
        onUserSelected: () => _loadTrophies(),
      );
    }

    return CustomScrollView(
      slivers: [
        // Dev mode indicator
        if (isDevBypass && devUser.hasSelectedUser)
          SliverToBoxAdapter(
            child: _DevModeUserBanner(
              username: devUser.selectedUsername ?? 'Unknown',
              onChangeUser: () {
                devUser.clearSelection();
              },
            ),
          ),
        
        // Profile header with banner
        SliverToBoxAdapter(
          child: _ProfileHeader(
            isWide: isWide,
            trophyCount: _trophies.length,
            username: devUser.selectedUsername,
            isDevMode: isDevBypass,
          ),
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
            child: _buildErrorState(),
          )
        else if (_trophies.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No trophies yet',
              message: isDevBypass 
                  ? 'This user hasn\'t posted any trophies yet.'
                  : 'Start building your trophy wall by posting your first harvest.',
              actionLabel: isDevBypass ? null : 'Post Trophy',
              onAction: isDevBypass ? null : () => context.push('/post'),
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
  
  Widget _buildErrorState() {
    // Check if it's a config/connection error
    final isConfigError = _error?.contains('ClientException') == true ||
                          _error?.contains('Failed to fetch') == true;
    
    if (isConfigError && kDebugMode) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Connection Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unable to fetch data from Supabase.\nCheck your configuration and network.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButtonSecondary(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                onPressed: _loadTrophies,
              ),
            ],
          ),
        ),
      );
    }
    
    return AppErrorState(
      message: _error!,
      onRetry: _loadTrophies,
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

/// Dev mode banner showing current user
class _DevModeUserBanner extends StatelessWidget {
  const _DevModeUserBanner({
    required this.username,
    required this.onChangeUser,
  });
  
  final String username;
  final VoidCallback onChangeUser;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Viewing as: $username (Dev Mode)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: onChangeUser,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

/// Dev user picker view
class _DevUserPickerView extends ConsumerStatefulWidget {
  const _DevUserPickerView({required this.onUserSelected});
  
  final VoidCallback onUserSelected;
  
  @override
  ConsumerState<_DevUserPickerView> createState() => _DevUserPickerViewState();
}

class _DevUserPickerViewState extends ConsumerState<_DevUserPickerView> {
  @override
  void initState() {
    super.initState();
    // Load available profiles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(devUserNotifierProvider).loadAvailableProfiles();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final devUser = ref.watch(devUserNotifierProvider);
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              boxShadow: AppColors.shadowElevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_search_rounded,
                    size: 32,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                // Title
                Text(
                  'Select a Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                
                // Subtitle
                Text(
                  'In dev mode, choose a profile to preview their Trophy Wall.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                
                // Loading or list
                if (devUser.isLoadingProfiles)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  )
                else if (devUser.availableProfiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No profiles found',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButtonSecondary(
                          label: 'Refresh',
                          icon: Icons.refresh_rounded,
                          onPressed: () => devUser.loadAvailableProfiles(),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: devUser.availableProfiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final profile = devUser.availableProfiles[index];
                        return _ProfileListTile(
                          profile: profile,
                          onTap: () async {
                            await devUser.selectUser(profile.id, profile.username);
                            widget.onUserSelected();
                          },
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Dev mode badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report_rounded, size: 12, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'DEV MODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                          letterSpacing: 0.5,
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

class _ProfileListTile extends StatefulWidget {
  const _ProfileListTile({
    required this.profile,
    required this.onTap,
  });
  
  final DevUserProfile profile;
  final VoidCallback onTap;
  
  @override
  State<_ProfileListTile> createState() => _ProfileListTileState();
}

class _ProfileListTileState extends State<_ProfileListTile> {
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
          padding: const EdgeInsets.all(AppSpacing.md),
          color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent,
                child: Text(
                  widget.profile.username[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.displayLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '@${widget.profile.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium dark profile header with banner, avatar, stats, and edit
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.isWide,
    required this.trophyCount,
    this.username,
    this.isDevMode = false,
  });

  final bool isWide;
  final int trophyCount;
  final String? username;
  final bool isDevMode;

  @override
  Widget build(BuildContext context) {
    // Banner header is now rendered by AppScaffold
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
                AppColors.primary.withOpacity(0.15),
                AppColors.background,
              ],
            ),
          ),
          child: Column(
            children: [
              // Profile info row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with accent ring
                  Container(
                    width: isWide ? 100 : 80,
                    height: isWide ? 100 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: AppColors.shadowAccent,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          username ?? 'Hunter Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Handle
                        Text(
                          '@${username?.toLowerCase() ?? 'huntername'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Texas, USA',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  _EditProfileButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Stats pills
              Row(
                children: [
                  _StatPill(
                    label: 'Trophies',
                    value: trophyCount.toString(),
                    icon: Icons.emoji_events_rounded,
                    isAccent: true,
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
            ],
          ),
        ),
      ],
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
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Edit Profile coming soon!'),
              duration: Duration(seconds: 1),
            ),
          );
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

/// Stat pill with bold accent styling
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.isAccent = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isAccent ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: isAccent ? AppColors.accent.withOpacity(0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isAccent ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isAccent ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Season filter tabs
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
            gradient: widget.isSelected ? AppColors.accentGradient : null,
            color: widget.isSelected
                ? null
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: widget.isSelected
                ? null
                : Border.all(color: AppColors.borderSubtle),
            boxShadow: widget.isSelected ? AppColors.shadowAccent : null,
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
    final species = (widget.trophy['species']?['name'] ?? '').toLowerCase();
    if (species.contains('deer')) return AppColors.categoryDeer;
    if (species.contains('turkey')) return AppColors.categoryTurkey;
    if (species.contains('bass')) return AppColors.categoryBass;
    return AppColors.categoryOtherGame;
  }

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
            _speciesColor.withOpacity(0.2),
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          size: 32,
          color: _speciesColor.withOpacity(0.4),
        ),
      ),
    );
  }
}

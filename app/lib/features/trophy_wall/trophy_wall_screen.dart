import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
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

    return CustomScrollView(
      slivers: [
        // Profile header with banner
        SliverToBoxAdapter(
          child: _ProfileHeader(
            isWide: isWide,
            trophyCount: _trophies.length,
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

/// Premium dark profile header with banner, avatar, stats, and edit
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.isWide,
    required this.trophyCount,
  });

  final bool isWide;
  final int trophyCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner at very top
        SafeArea(
          bottom: false,
          child: const BannerHeader.variantPage(),
        ),

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
                        const Text(
                          'Hunter Name',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Handle
                        const Text(
                          '@huntername',
                          style: TextStyle(
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
        onTap: () {},
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

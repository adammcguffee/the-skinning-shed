import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/data/us_counties.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏠 FEED SCREEN - 2025 CINEMATIC DARK THEME
///
/// Image-first grid feed matching the premium reference:
/// - Large banner logo at top
/// - Category filter tabs
/// - Cinematic image cards with overlays
/// - Rich depth and hover effects
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.initialCategory});
  
  /// Optional initial category filter from URL query param.
  final String? initialCategory;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  List<Map<String, dynamic>> _trophies = [];
  bool _isLoading = true;
  String? _error;
  late String _selectedCategory;
  String? _selectedState;
  String? _selectedCounty;
  String _usernameSearch = '';
  bool _showFilters = false;

  final List<_CategoryTab> _categories = const [
    _CategoryTab(id: 'all', label: 'All', icon: Icons.grid_view_rounded),
    _CategoryTab(id: 'deer', label: 'Deer', icon: Icons.nature_rounded),
    _CategoryTab(id: 'turkey', label: 'Turkey', icon: Icons.egg_rounded),
    _CategoryTab(id: 'bass', label: 'Bass', icon: Icons.water_rounded),
    _CategoryTab(id: 'other', label: 'Other', icon: Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Use initial category from URL if valid, otherwise default to 'all'
    final validCategories = ['all', 'deer', 'turkey', 'bass', 'other'];
    _selectedCategory = validCategories.contains(widget.initialCategory) 
        ? widget.initialCategory! 
        : 'all';
    _loadTrophies();
  }

  Future<void> _loadTrophies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trophyService = ref.read(trophyServiceProvider);
      // Use selected category for filtering (null for 'all')
      final categoryFilter = _selectedCategory == 'all' ? null : _selectedCategory;
      final trophies = await trophyService.fetchFeed(
        category: categoryFilter,
        state: _selectedState,
        county: _selectedCounty,
      );
      
      // Apply username filter client-side if set
      var filtered = trophies;
      if (_usernameSearch.isNotEmpty) {
        final q = _usernameSearch.toLowerCase();
        filtered = trophies.where((t) {
          final displayName = (t['profiles']?['display_name'] as String?)?.toLowerCase() ?? '';
          final username = (t['profiles']?['username'] as String?)?.toLowerCase() ?? '';
          return displayName.contains(q) || username.contains(q);
        }).toList();
      }
      
      setState(() {
        _trophies = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    _loadTrophies(); // Reload with new filter
  }
  
  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedCounty = null; // Reset county when state changes
    });
    _loadTrophies();
  }
  
  void _onCountyChanged(String? county) {
    setState(() => _selectedCounty = county);
    _loadTrophies();
  }
  
  void _onUsernameSearchChanged(String value) {
    setState(() => _usernameSearch = value);
    _loadTrophies();
  }
  
  void _clearFilters() {
    setState(() {
      _selectedCategory = 'all';
      _selectedState = null;
      _selectedCounty = null;
      _usernameSearch = '';
    });
    _loadTrophies();
  }
  
  bool get _hasActiveFilters =>
      _selectedCategory != 'all' ||
      _selectedState != null ||
      _selectedCounty != null ||
      _usernameSearch.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return CustomScrollView(
      slivers: [
        // Banner header
        SliverToBoxAdapter(
          child: _buildHeader(context, isWide),
        ),

        // Category tabs + filter toggle
        SliverToBoxAdapter(
          child: _buildCategoryTabs(),
        ),
        
        // Expanded filters panel
        if (_showFilters)
          SliverToBoxAdapter(
            child: _buildExpandedFilters(),
          ),
        
        // Active filter chips
        if (_hasActiveFilters)
          SliverToBoxAdapter(
            child: _buildActiveFilterChips(),
          ),

        // Content
        _buildContent(context, isWide),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Trophy Feed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Latest trophies from the community',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _CategoryChip(
                        category: category,
                        isSelected: _selectedCategory == category.id,
                        onTap: () => _onCategoryChanged(category.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterToggleButton(
            isActive: _showFilters || _hasActiveFilters,
            hasFilters: _hasActiveFilters,
            onTap: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location filters row
          Row(
            children: [
              Expanded(
                child: _StateDropdown(
                  value: _selectedState,
                  onChanged: _onStateChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CountyDropdown(
                  stateCode: _selectedState,
                  value: _selectedCounty,
                  onChanged: _onCountyChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Username search
          _UsernameSearchField(
            value: _usernameSearch,
            onChanged: _onUsernameSearchChanged,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          if (_selectedState != null)
            _ActiveFilterChip(
              label: _selectedState!,
              onRemove: () => _onStateChanged(null),
            ),
          if (_selectedCounty != null)
            _ActiveFilterChip(
              label: _selectedCounty!,
              onRemove: () => _onCountyChanged(null),
            ),
          if (_usernameSearch.isNotEmpty)
            _ActiveFilterChip(
              label: 'User: $_usernameSearch',
              onRemove: () => _onUsernameSearchChanged(''),
            ),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_all_rounded, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      'Clear all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
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

  Widget _buildContent(BuildContext context, bool isWide) {
    if (_isLoading) {
      return _buildLoadingState(isWide);
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: AppErrorState(
          message: _error!,
          onRetry: _loadTrophies,
        ),
      );
    }

    if (_trophies.isEmpty) {
      return SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'No trophies yet',
          message: 'Be the first to share your harvest with the community.',
          actionLabel: 'Post Trophy',
          onAction: () => context.push('/post'),
        ),
      );
    }

    return _buildGrid(context, isWide);
  }

  Widget _buildLoadingState(bool isWide) {
    final crossAxisCount = isWide ? 2 : 1;
    // Use same responsive padding as grid
    final gridPadding = isWide ? AppSpacing.screenPadding : 12.0;

    return SliverPadding(
      padding: EdgeInsets.all(gridPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _FeedCardSkeleton(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool isWide) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 380;
    final crossAxisCount = screenWidth >= AppSpacing.breakpointDesktop
        ? 3
        : screenWidth >= AppSpacing.breakpointTablet
            ? 2
            : 1;
    
    // Responsive padding: tighter on small phones
    final gridPadding = isSmallPhone ? 8.0 : (isWide ? AppSpacing.screenPadding : 12.0);
    final gridSpacing = isSmallPhone ? 10.0 : AppSpacing.gridGap;

    return SliverPadding(
      padding: EdgeInsets.all(gridPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: gridSpacing,
          crossAxisSpacing: gridSpacing,
          childAspectRatio: crossAxisCount == 1 ? 0.9 : 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _CinematicFeedCard(
            trophy: _trophies[index],
            onTap: () => context.push('/trophy/${_trophies[index]['id']}'),
          ),
          childCount: _trophies.length,
        ),
      ),
    );
  }
}

/// Category tab chip matching reference design
class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _CategoryTab category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.accent
                  : AppColors.borderSubtle,
            ),
            boxShadow: widget.isSelected ? AppColors.shadowAccent : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.category.icon,
                size: 16,
                color: widget.isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                widget.category.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? AppColors.textInverse
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cinematic feed card - image-first with overlay chips
class _CinematicFeedCard extends StatefulWidget {
  const _CinematicFeedCard({
    required this.trophy,
    required this.onTap,
  });

  final Map<String, dynamic> trophy;
  final VoidCallback onTap;

  @override
  State<_CinematicFeedCard> createState() => _CinematicFeedCardState();
}

class _CinematicFeedCardState extends State<_CinematicFeedCard> {
  bool _isHovered = false;
  bool _isLiked = false;

  void _sharePost(BuildContext context, Map<String, dynamic> trophy) {
    final trophyId = trophy['id'] as String?;
    if (trophyId == null) return;
    
    // Copy deep link to clipboard
    final link = 'https://theskinningshed.com/trophy/$trophyId';
    Clipboard.setData(ClipboardData(text: link));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Link copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _toggleSaved(BuildContext context) {
    // Toggle saved state (UI only for now - can be expanded to persist)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Trophy bookmarked',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final species = widget.trophy['species']?['common_name'] ?? 
                    widget.trophy['custom_species_name'] ?? 'Trophy';
    final state = widget.trophy['state'] ?? '';
    final county = widget.trophy['county'] ?? '';
    final location = [county, state].where((s) => s.isNotEmpty).join(', ');
    final date = widget.trophy['harvest_date'] ?? '';
    
    // Use story if available, otherwise fall back to species + location
    final story = widget.trophy['story'] as String?;
    final title = story?.isNotEmpty == true 
        ? (story!.length > 60 ? '${story.substring(0, 60)}...' : story)
        : species;
    
    // Resolve cover photo to public URL
    final coverPhotoPath = widget.trophy['cover_photo_path'] as String?;
    String? imageUrl;
    if (coverPhotoPath != null) {
      final client = SupabaseService.instance.client;
      if (client != null) {
        imageUrl = client.storage.from('trophy_photos').getPublicUrl(coverPhotoPath);
      }
    }
    
    final likes = widget.trophy['likes_count'] ?? 0;
    final comments = widget.trophy['comments_count'] ?? 0;
    final username = widget.trophy['profiles']?['display_name'] ?? 
                     widget.trophy['profiles']?['username'] ?? 'Hunter';
    final userId = widget.trophy['user_id'] as String?;
    final avatarPath = widget.trophy['profiles']?['avatar_path'] as String?;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -6.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderAccent : AppColors.borderSubtle,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image section with overlays
              Expanded(
                flex: 3,
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

                    // Top gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.cardOverlay,
                        ),
                      ),
                    ),

                    // Species chip (top left)
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: _SpeciesChip(species: species),
                    ),

                    // User info (top right)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _UserBadge(
                        username: username,
                        userId: userId,
                        avatarPath: avatarPath,
                      ),
                    ),

                    // Location chip (bottom left)
                    if (location.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.md,
                        left: AppSpacing.md,
                        child: _LocationChip(location: location),
                      ),

                    // Date (bottom right)
                    if (date.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.md,
                        right: AppSpacing.md,
                        child: _DateBadge(date: date),
                      ),
                  ],
                ),
              ),

              // Content section
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Actions row
                    Row(
                      children: [
                        _ActionButton(
                          icon: _isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                          label: likes.toString(),
                          isActive: _isLiked,
                          activeColor: AppColors.error,
                          onTap: () => setState(() => _isLiked = !_isLiked),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: comments.toString(),
                          onTap: widget.onTap,
                        ),
                        const Spacer(),
                        _ActionButton(
                          icon: Icons.share_outlined,
                          onTap: () => _sharePost(context, widget.trophy),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ActionButton(
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => _toggleSaved(context),
                        ),
                      ],
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
            AppColors.surfaceHover,
            AppColors.surface,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Species chip with color coding
class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({required this.species});

  final String species;

  Color get _backgroundColor {
    switch (species.toLowerCase()) {
      case 'whitetail deer':
      case 'deer':
        return AppColors.categoryDeer;
      case 'turkey':
        return AppColors.categoryTurkey;
      case 'bass':
      case 'largemouth bass':
        return AppColors.categoryBass;
      default:
        return AppColors.categoryOtherGame;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        boxShadow: [
          BoxShadow(
            color: _backgroundColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            species,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (species.toLowerCase()) {
      case 'whitetail deer':
      case 'deer':
        return Icons.nature_rounded;
      case 'turkey':
        return Icons.egg_rounded;
      case 'bass':
      case 'largemouth bass':
        return Icons.water_rounded;
      default:
        return Icons.pets_rounded;
    }
  }
}

/// Location chip
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            location,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// User badge - tappable to view profile
class _UserBadge extends StatelessWidget {
  const _UserBadge({
    required this.username,
    this.userId,
    this.avatarPath,
  });

  final String username;
  final String? userId;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    String? avatarUrl;
    if (avatarPath != null) {
      final client = SupabaseService.instance.client;
      if (client != null) {
        avatarUrl = client.storage.from('avatars').getPublicUrl(avatarPath!);
      }
    }

    return GestureDetector(
      onTap: userId != null ? () => context.push('/user/$userId') : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.accent,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textInverse,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              username,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date badge
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        _formatDate(date),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(parsed);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${parsed.month}/${parsed.day}';
    } catch (_) {
      return date;
    }
  }
}

/// Action button
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isActive
                    ? widget.activeColor ?? AppColors.accent
                    : _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 4),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Feed card skeleton for loading state
class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image skeleton
          Expanded(
            flex: 3,
            child: Container(
              color: AppColors.surfaceHover,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.textTertiary.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Content skeleton
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 12,
                  width: 100,
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

class _CategoryTab {
  const _CategoryTab({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Filter toggle button
class _FilterToggleButton extends StatefulWidget {
  const _FilterToggleButton({
    required this.isActive,
    required this.hasFilters,
    required this.onTap,
  });

  final bool isActive;
  final bool hasFilters;
  final VoidCallback onTap;

  @override
  State<_FilterToggleButton> createState() => _FilterToggleButtonState();
}

class _FilterToggleButtonState extends State<_FilterToggleButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive || _isHovered
                ? AppColors.accent.withOpacity(0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent.withOpacity(0.4)
                  : _isHovered
                      ? AppColors.borderStrong
                      : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 16,
                color: widget.isActive ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              if (widget.hasFilters) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// State dropdown for location filtering
class _StateDropdown extends StatelessWidget {
  const _StateDropdown({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: const Text(
            'All States',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All States'),
            ),
            ...USStates.all.map((state) => DropdownMenuItem<String?>(
              value: state.name,
              child: Text(state.name),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// County dropdown for location filtering (dependent on state)
class _CountyDropdown extends StatefulWidget {
  const _CountyDropdown({
    required this.stateCode,
    required this.value,
    required this.onChanged,
  });

  final String? stateCode;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_CountyDropdown> createState() => _CountyDropdownState();
}

class _CountyDropdownState extends State<_CountyDropdown> {
  List<String> _counties = [];

  @override
  void initState() {
    super.initState();
    _loadCounties();
  }

  @override
  void didUpdateWidget(_CountyDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stateCode != oldWidget.stateCode) {
      _loadCounties();
    }
  }

  void _loadCounties() {
    if (widget.stateCode == null) {
      setState(() => _counties = []);
      return;
    }

    // Find state code from name
    final state = USStates.all.firstWhere(
      (s) => s.name == widget.stateCode,
      orElse: () => const USState('', ''),
    );
    
    if (state.code.isEmpty) {
      setState(() => _counties = []);
      return;
    }

    // Get counties from static data
    final counties = USCounties.forState(state.code);
    setState(() => _counties = counties);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: widget.value,
          isExpanded: true,
          hint: Text(
            widget.stateCode == null
                ? 'Select state first'
                : 'All Counties',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          items: widget.stateCode == null
              ? []
              : [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Counties'),
                  ),
                  ..._counties.map((county) => DropdownMenuItem<String?>(
                    value: county,
                    child: Text(county),
                  )),
                ],
          onChanged: widget.stateCode == null ? null : widget.onChanged,
        ),
      ),
    );
  }
}

/// Username search field with debounce
class _UsernameSearchField extends StatefulWidget {
  const _UsernameSearchField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_UsernameSearchField> createState() => _UsernameSearchFieldState();
}

class _UsernameSearchFieldState extends State<_UsernameSearchField> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search by username...',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.person_search_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                color: AppColors.textTertiary,
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
      onChanged: _onChanged,
    );
  }
}

/// Active filter chip (removable)
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

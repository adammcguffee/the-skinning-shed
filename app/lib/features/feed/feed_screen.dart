import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/ad_service.dart';
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
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  List<Map<String, dynamic>> _trophies = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'all';

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
      final trophies = await trophyService.fetchFeed(category: categoryFilter);
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
  
  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    _loadTrophies(); // Reload with new filter
  }

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

        // Category tabs
        SliverToBoxAdapter(
          child: _buildCategoryTabs(),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Title
          Expanded(
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
          ),
          
          // Right side: Ad Test button (debug only)
          if (kDebugMode)
            _AdTestButton(onTap: () => _showAdDiagnostics(context)),
        ],
      ),
    );
  }
  
  void _showAdDiagnostics(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AdDiagnosticsDialog(),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.xs,
      ),
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
    );
  }

  Widget _buildContent(BuildContext context, bool isWide) {
    if (_isLoading) {
      return _buildLoadingState(isWide);
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: _buildErrorState(),
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

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
    final crossAxisCount = screenWidth >= AppSpacing.breakpointDesktop
        ? 3
        : screenWidth >= AppSpacing.breakpointTablet
            ? 2
            : 1;

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
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
  
  Widget _buildErrorState() {
    // Check if it's a config/connection error
    final isConfigError = _error?.contains('ClientException') == true ||
                          _error?.contains('Failed to fetch') == true ||
                          _error?.contains('yourproject') == true;
    
    if (isConfigError && kDebugMode) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
        ),
      );
    }
    
    return AppErrorState(
      message: _error!,
      onRetry: _loadTrophies,
    );
  }
}

/// Ad Test button - debug only
class _AdTestButton extends StatefulWidget {
  const _AdTestButton({required this.onTap});
  
  final VoidCallback onTap;
  
  @override
  State<_AdTestButton> createState() => _AdTestButtonState();
}

class _AdTestButtonState extends State<_AdTestButton> {
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
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.warning.withOpacity(0.2) 
                : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.warning.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.ads_click_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Ad Test',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ad diagnostics dialog
class _AdDiagnosticsDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdDiagnosticsDialog> createState() => _AdDiagnosticsDialogState();
}

class _AdDiagnosticsDialogState extends ConsumerState<_AdDiagnosticsDialog> {
  AdCreative? _leftAd;
  AdCreative? _rightAd;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadAds();
  }
  
  Future<void> _loadAds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final adService = ref.read(adServiceProvider);
      final results = await adService.prefetchAdsForPage(AdPages.feed);
      setState(() {
        _leftAd = results.left;
        _rightAd = results.right;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _refreshAds() {
    final adService = ref.read(adServiceProvider);
    adService.clearCache();
    _loadAds();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final breakpoint = screenWidth >= AppSpacing.breakpointDesktop
        ? 'Desktop (≥1024px)'
        : screenWidth >= AppSpacing.breakpointTablet
            ? 'Tablet (≥768px)'
            : 'Mobile (<768px)';
    
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.ads_click_rounded, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Ad Diagnostics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Breakpoint info
              _DiagRow(label: 'Screen Width', value: '${screenWidth.toInt()}px'),
              _DiagRow(label: 'Breakpoint', value: breakpoint),
              _DiagRow(label: 'ADS_BUCKET_PUBLIC', value: kAdsBucketPublic.toString()),
              _DiagRow(label: 'Page', value: 'feed'),
              
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              
              // Ad slots
              Text(
                'Ad Slots',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text('Error: $_error', style: TextStyle(color: AppColors.error))
              else ...[
                _AdSlotInfo(
                  position: 'Left',
                  ad: _leftAd,
                ),
                const SizedBox(height: AppSpacing.md),
                _AdSlotInfo(
                  position: 'Right',
                  ad: _rightAd,
                ),
              ],
              
              const SizedBox(height: AppSpacing.xl),
              
              // Refresh button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refreshAds,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Ads'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});
  
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _AdSlotInfo extends StatelessWidget {
  const _AdSlotInfo({required this.position, required this.ad});
  
  final String position;
  final AdCreative? ad;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: ad != null 
              ? AppColors.success.withOpacity(0.3) 
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ad != null ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: ad != null ? AppColors.success : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                '$position Slot',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                ad != null ? 'Active' : 'Empty',
                style: TextStyle(
                  fontSize: 12,
                  color: ad != null ? AppColors.success : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (ad != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Label: ${ad!.label ?? 'N/A'}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            Text(
              'URL: ${ad!.imageUrl.length > 50 ? '${ad!.imageUrl.substring(0, 50)}...' : ad!.imageUrl}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
            ),
            if (ad!.clickUrl != null)
              Text(
                'Click: ${ad!.clickUrl}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'No ad configured for slot: feed_${position.toLowerCase()}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
        ],
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final species = widget.trophy['species']?['name'] ?? 'Unknown';
    final title = widget.trophy['title'] ?? 'Untitled';
    final state = widget.trophy['state'] ?? '';
    final county = widget.trophy['county'] ?? '';
    final location = [county, state].where((s) => s.isNotEmpty).join(', ');
    final date = widget.trophy['harvest_date'] ?? '';
    final imageUrl = widget.trophy['trophy_media']?.isNotEmpty == true
        ? widget.trophy['trophy_media'][0]['url']
        : null;
    final likes = widget.trophy['likes_count'] ?? 0;
    final comments = widget.trophy['comments_count'] ?? 0;
    final username = widget.trophy['profiles']?['username'] ?? 'Hunter';

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
                      child: _UserBadge(username: username),
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
                          onTap: () => _showComingSoon(context, 'Share'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ActionButton(
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => _showComingSoon(context, 'Save'),
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

/// User badge
class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.username});

  final String username;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.accent,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textInverse,
              ),
            ),
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

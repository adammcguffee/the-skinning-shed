import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏠 FEED SCREEN - 2025 PREMIUM
///
/// Image-first grid feed with modern cards.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
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
      final trophies = await trophyService.fetchFeed();
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
            title: 'Feed',
            subtitle: 'Latest from the community',
            onSearch: () {},
            onFilter: () => _showFilterSheet(context),
          ),

        // Content
        Expanded(
          child: _buildContent(context, isWide),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isWide) {
    if (_isLoading) {
      return _buildLoadingState(isWide);
    }

    if (_error != null) {
      return AppErrorState(
        message: _error!,
        onRetry: _loadTrophies,
      );
    }

    if (_trophies.isEmpty) {
      return AppEmptyState(
        icon: Icons.photo_camera_outlined,
        title: 'No trophies yet',
        message: 'Be the first to share your harvest with the community.',
        actionLabel: 'Post Trophy',
        onAction: () => context.push('/post'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrophies,
      color: AppColors.primary,
      child: _buildGrid(context, isWide),
    );
  }

  Widget _buildLoadingState(bool isWide) {
    final crossAxisCount = isWide ? 3 : 1;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gridGap,
          crossAxisSpacing: AppSpacing.gridGap,
          childAspectRatio: 0.85,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const AppCardSkeleton(),
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

    return CustomScrollView(
      slivers: [
        // Mobile header
        if (!isWide)
          SliverToBoxAdapter(
            child: AppPageHeader(
              title: 'Feed',
              subtitle: 'Latest from the community',
              trailing: AppIconButton(
                icon: Icons.tune_rounded,
                onPressed: () => _showFilterSheet(context),
              ),
            ),
          ),

        // Grid
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.gridGap,
              crossAxisSpacing: AppSpacing.gridGap,
              childAspectRatio: crossAxisCount == 1 ? 0.9 : 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _FeedCard(
                trophy: _trophies[index],
                onTap: () => context.push('/trophy/${_trophies[index]['id']}'),
              ),
              childCount: _trophies.length,
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

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _FilterSheet(),
    );
  }
}

/// Modern feed card with image-first design.
class _FeedCard extends StatefulWidget {
  const _FeedCard({
    required this.trophy,
    required this.onTap,
  });

  final Map<String, dynamic> trophy;
  final VoidCallback onTap;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _isHovered = false;
  bool _isLiked = false;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -4.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
            boxShadow: _isHovered ? AppColors.shadowElevated : AppColors.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image section
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

                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 100,
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
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: AppCategoryChip(
                        category: species,
                        size: AppChipSize.small,
                      ),
                    ),

                    // Location chip
                    if (location.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.md,
                        left: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content section
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Date
                    if (date.isNotEmpty)
                      Text(
                        _formatDate(date),
                        style: Theme.of(context).textTheme.bodySmall,
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
                          onTap: () => setState(() => _isLiked = !_isLiked),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: comments.toString(),
                          onTap: widget.onTap,
                        ),
                        const Spacer(),
                        _ActionButton(
                          icon: Icons.share_outlined,
                          onTap: () {},
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
      color: AppColors.backgroundAlt,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.textTertiary,
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
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      return '${parsed.month}/${parsed.day}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.isActive = false,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final bool isActive;
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    ? AppColors.error
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

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  String? _selectedSpecies;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  Text(
                    'Filter Feed',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedSpecies = null);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Species filter
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Species',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedSpecies == null,
                        onTap: () => setState(() => _selectedSpecies = null),
                      ),
                      _FilterChip(
                        label: 'Deer',
                        isSelected: _selectedSpecies == 'deer',
                        onTap: () => setState(() => _selectedSpecies = 'deer'),
                      ),
                      _FilterChip(
                        label: 'Turkey',
                        isSelected: _selectedSpecies == 'turkey',
                        onTap: () => setState(() => _selectedSpecies = 'turkey'),
                      ),
                      _FilterChip(
                        label: 'Bass',
                        isSelected: _selectedSpecies == 'bass',
                        onTap: () => setState(() => _selectedSpecies = 'bass'),
                      ),
                      _FilterChip(
                        label: 'Other Game',
                        isSelected: _selectedSpecies == 'other_game',
                        onTap: () => setState(() => _selectedSpecies = 'other_game'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppButtonPrimary(
                label: 'Apply Filters',
                onPressed: () => Navigator.pop(context),
                isExpanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

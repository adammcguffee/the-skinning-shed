import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/social_service.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏆 TROPHY DETAIL SCREEN - 2025 PREMIUM
/// 
/// Full trophy detail with real likes, comments, share, and report.
class TrophyDetailScreen extends ConsumerStatefulWidget {
  const TrophyDetailScreen({super.key, required this.trophyId});

  final String trophyId;

  @override
  ConsumerState<TrophyDetailScreen> createState() => _TrophyDetailScreenState();
}

class _TrophyDetailScreenState extends ConsumerState<TrophyDetailScreen> {
  Map<String, dynamic>? _trophy;
  bool _isLoading = true;
  String? _error;
  
  // Social state
  bool _isLiked = false;
  int _likeCount = 0;
  List<Comment> _comments = [];
  bool _isLoadingComments = true;
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadTrophy();
    _loadLikeStatus();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTrophy() async {
    try {
      final trophyService = ref.read(trophyServiceProvider);
      final trophy = await trophyService.fetchTrophy(widget.trophyId);
      if (mounted) {
        setState(() {
          _trophy = trophy;
          _likeCount = trophy?['likes_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLikeStatus() async {
    try {
      final socialService = ref.read(socialServiceProvider);
      final liked = await socialService.hasLiked(widget.trophyId);
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final socialService = ref.read(socialServiceProvider);
      final comments = await socialService.fetchComments(widget.trophyId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    // Optimistic update
    final wasLiked = _isLiked;
    final oldCount = _likeCount;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.toggleLike(widget.trophyId);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final socialService = ref.read(socialServiceProvider);
      final comment = await socialService.addComment(widget.trophyId, body);
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
          _commentController.clear();
          _isSubmittingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.deleteComment(commentId);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == commentId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _sharePost() {
    final url = 'https://theskinningshed.com/trophy/${widget.trophyId}';
    final title = _trophy?['title'] ?? 'Trophy';
    
    if (kIsWeb) {
      // Web: copy to clipboard
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      // Mobile: use share sheet
      Share.share('Check out this trophy: $title\n$url');
    }
  }

  void _showReportModal() {
    showShedCenterModal(
      context: context,
      title: 'Report Post',
      maxWidth: 400,
      maxHeight: 500,
      child: _ReportContent(
        onReport: (reason, details) async {
          try {
            final socialService = ref.read(socialServiceProvider);
            await socialService.reportPost(
              postId: widget.trophyId,
              reason: reason,
              details: details,
            );
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report submitted. Thank you.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      );
    }

    if (_error != null || _trophy == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: AppErrorState(
          message: _error ?? 'Trophy not found',
          onRetry: _loadTrophy,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image header with carousel
          _buildImageHeader(context),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  _buildHeaderInfo(context),

                  // Actions row
                  _buildActionsRow(context),

                  const Divider(height: AppSpacing.xxxl),

                  // User info
                  _buildUserInfo(context),

                  const SizedBox(height: AppSpacing.xxl),

                  // Story/Notes
                  if (_trophy!['story'] != null && _trophy!['story'].isNotEmpty)
                    _buildStorySection(context),

                  // Weather conditions at harvest
                  if (_trophy!['weather_snapshots'] != null)
                    _buildConditionsSection(context),

                  // Comments section
                  _buildCommentsSection(context),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    final photos = _trophy!['trophy_photos'] as List? ?? [];
    final imageUrl = photos.isNotEmpty ? photos.first['storage_path'] : null;

    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: _AppBarButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => context.pop(),
      ),
      actions: [
        _AppBarButton(
          icon: Icons.share_outlined,
          onTap: _sharePost,
        ),
        _AppBarButton(
          icon: Icons.more_vert_rounded,
          onTap: _showReportModal,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundAlt,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    final species = _trophy!['species']?['common_name'] ?? 'Unknown';
    final title = _trophy!['title'] ?? 'Untitled';
    final state = _trophy!['state'] ?? '';
    final county = _trophy!['county'] ?? '';
    final location = [county, state].where((s) => s.isNotEmpty).join(', ');
    final harvestDate = _trophy!['harvest_date'];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Species chip
          AppCategoryChip(
            category: species,
            size: AppChipSize.medium,
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Location & date
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if (location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              if (harvestDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(harvestDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            label: _likeCount.toString(),
            isActive: _isLiked,
            activeColor: AppColors.error,
            onTap: _toggleLike,
          ),
          const SizedBox(width: AppSpacing.lg),
          
          // Comments button
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: _comments.length.toString(),
            onTap: () {
              // Scroll to comments
            },
          ),
          const Spacer(),
          
          // Share button
          _ActionButton(
            icon: Icons.share_outlined,
            onTap: _sharePost,
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    final profile = _trophy!['profiles'] as Map<String, dynamic>?;
    final displayName = profile?['display_name'] ?? profile?['username'] ?? 'Hunter';
    final username = profile?['username'];
    final userId = profile?['id'];
    final currentUserId = ref.read(currentUserProvider)?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: userId != null ? () => context.push('/user/$userId') : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (username != null)
                    Text(
                      '@$username',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          if (userId != null && userId != currentUserId)
            AppButtonSecondary(
              label: 'View Wall',
              onPressed: () => context.push('/user/$userId'),
              size: AppButtonSize.small,
            ),
        ],
      ),
    );
  }

  Widget _buildStorySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Story',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _trophy!['story'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildConditionsSection(BuildContext context) {
    final weather = _trophy!['weather_snapshots'] as Map<String, dynamic>?;
    final moon = _trophy!['moon_snapshots'] as Map<String, dynamic>?;
    
    if (weather == null && moon == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conditions at Harvest',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (weather?['temp_f'] != null)
                _ConditionChip(
                  icon: Icons.thermostat_outlined,
                  label: '${weather!['temp_f'].round()}°F',
                ),
              if (weather?['wind_speed'] != null)
                _ConditionChip(
                  icon: Icons.air_rounded,
                  label: '${weather!['wind_speed']} mph',
                ),
              if (weather?['pressure_hpa'] != null)
                _ConditionChip(
                  icon: Icons.speed_outlined,
                  label: '${(weather!['pressure_hpa'] * 0.02953).toStringAsFixed(2)} inHg',
                ),
              if (moon?['phase_name'] != null)
                _ConditionChip(
                  icon: Icons.dark_mode_outlined,
                  label: moon!['phase_name'],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Comments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '(${_comments.length})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Comment input
          if (isAuthenticated)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: AppColors.surface,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconButton(
                  icon: Icons.send_rounded,
                  onPressed: _isSubmittingComment ? null : _submitComment,
                  backgroundColor: AppColors.accent,
                  color: AppColors.textInverse,
                ),
              ],
            ),

          const SizedBox(height: AppSpacing.lg),

          // Comments list
          if (_isLoadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 32,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No comments yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  if (isAuthenticated)
                    Text(
                      'Be the first to comment!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            )
          else
            ...List.generate(_comments.length, (index) {
              final comment = _comments[index];
              final currentUserId = ref.read(currentUserProvider)?.id;
              final isOwn = comment.userId == currentUserId;
              
              return _CommentItem(
                comment: comment,
                isOwn: isOwn,
                onDelete: isOwn ? () => _deleteComment(comment.id) : null,
              );
            }),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        onPressed: onTap,
      ),
    );
  }
}

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: widget.isActive
                    ? (widget.activeColor ?? AppColors.accent)
                    : (_isHovered ? AppColors.textPrimary : AppColors.textSecondary),
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: widget.isActive
                        ? (widget.activeColor ?? AppColors.accent)
                        : (_isHovered ? AppColors.textPrimary : AppColors.textSecondary),
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

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

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
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.isOwn,
    this.onDelete,
  });

  final Comment comment;
  final bool isOwn;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(
              child: Text(
                comment.authorName.isNotEmpty 
                    ? comment.authorName[0].toUpperCase() 
                    : 'H',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (isOwn && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.month}/${date.day}';
  }
}

/// Report content modal
class _ReportContent extends StatefulWidget {
  const _ReportContent({required this.onReport});

  final Future<void> Function(String reason, String? details) onReport;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why are you reporting this post?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // Reason options
        ...ReportReason.values.map((reason) {
          final isSelected = _selectedReason == reason;
          return GestureDetector(
            onTap: () => setState(() => _selectedReason = reason),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.accent.withValues(alpha: 0.1) 
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected 
                        ? Icons.radio_button_checked_rounded 
                        : Icons.radio_button_off_rounded,
                    color: isSelected ? AppColors.accent : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    reason.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        
        const SizedBox(height: AppSpacing.md),
        
        // Additional details
        TextField(
          controller: _detailsController,
          decoration: InputDecoration(
            hintText: 'Additional details (optional)',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          maxLines: 3,
        ),
        
        const SizedBox(height: AppSpacing.xl),
        
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedReason == null || _isSubmitting
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    await widget.onReport(
                      _selectedReason!.value,
                      _detailsController.text.trim().isEmpty 
                          ? null 
                          : _detailsController.text.trim(),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Submit Report'),
          ),
        ),
      ],
    );
  }
}

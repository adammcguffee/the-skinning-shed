import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏆 TROPHY DETAIL SCREEN - 2025 PREMIUM
class TrophyDetailScreen extends StatelessWidget {
  const TrophyDetailScreen({super.key, required this.trophyId});

  final String trophyId;
  
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                showComingSoonModal(
                  context: context,
                  feature: 'Report Content',
                  description: 'Report inappropriate content or rule violations to our moderation team.',
                  icon: Icons.flag_rounded,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.textSecondary),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                showComingSoonModal(
                  context: context,
                  feature: 'Block User',
                  description: 'Block this user to hide their content from your feed.',
                  icon: Icons.block_rounded,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.white),
                ),
                onPressed: () => showComingSoonModal(
                  context: context,
                  feature: 'Share Trophy',
                  description: 'Share this trophy directly to social media, messaging apps, or copy a link.',
                  icon: Icons.share_rounded,
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.more_vert_rounded, color: Colors.white),
                ),
                onPressed: () => _showOptionsMenu(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.backgroundAlt,
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),

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
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Species chip
                        AppCategoryChip(
                          category: 'Whitetail Deer',
                          size: AppChipSize.medium,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Title
                        Text(
                          'Opening Day Buck',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Location & date
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hill Country, Texas',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Nov 4, 2024',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Row(
                      children: [
                        _ActionButton(
                          icon: Icons.favorite_outline_rounded,
                          label: '234',
                          onTap: () => showComingSoonModal(
                            context: context,
                            feature: 'Reactions',
                            description: 'React to trophies to show appreciation and support fellow hunters.',
                            icon: Icons.favorite_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '18',
                          onTap: () => showComingSoonModal(
                            context: context,
                            feature: 'Comments',
                            description: 'Leave comments and engage with the hunting community.',
                            icon: Icons.chat_bubble_rounded,
                          ),
                        ),
                        const Spacer(),
                        _ActionButton(
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => showComingSoonModal(
                            context: context,
                            feature: 'Save Trophy',
                            description: 'Save trophies to your personal collection for easy access later.',
                            icon: Icons.bookmark_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: AppSpacing.xxxl),

                  // User info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hunter Name',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '@huntername',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AppButtonSecondary(
                          label: 'Follow',
                          onPressed: () => showComingSoonModal(
                            context: context,
                            feature: 'Follow Users',
                            description: 'Follow hunters to see their trophies in your feed and get notified of new posts.',
                            icon: Icons.person_add_rounded,
                          ),
                          size: AppButtonSize.small,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Notes
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Opening morning of deer season. Had this buck on camera all summer and finally got a shot at him. 10-point with a 19" inside spread. Taken at 85 yards with my .308.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Comment input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              filled: true,
                              fillColor: AppColors.surface,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppIconButton(
                          icon: Icons.send_rounded,
                          onPressed: () => showComingSoonSnackbar(context, 'Comments'),
                          backgroundColor: AppColors.primary,
                          color: AppColors.textInverse,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Sample comments
                  _CommentItem(
                    username: '@hunter_joe',
                    comment: 'Congrats! That\'s a beautiful buck!',
                    time: '2h ago',
                  ),
                  _CommentItem(
                    username: '@wild_tom',
                    comment: 'Great harvest! What county?',
                    time: '4h ago',
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
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
                color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
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

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.username,
    required this.comment,
    required this.time,
  });

  final String username;
  final String comment;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
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
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppColors.textTertiary,
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
                      username,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

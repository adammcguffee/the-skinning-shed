import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme/app_colors.dart';
import '../../services/club_openings_service.dart';
import '../../services/messaging_service.dart';
import '../../services/supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// OPENING DETAIL SCREEN
// ════════════════════════════════════════════════════════════════════════════

class OpeningDetailScreen extends ConsumerStatefulWidget {
  const OpeningDetailScreen({super.key, required this.openingId});

  final String openingId;

  @override
  ConsumerState<OpeningDetailScreen> createState() => _OpeningDetailScreenState();
}

class _OpeningDetailScreenState extends ConsumerState<OpeningDetailScreen> {
  bool _phoneRevealed = false;

  @override
  Widget build(BuildContext context) {
    final openingAsync = ref.watch(openingDetailProvider(widget.openingId));
    final currentUserId = SupabaseService.instance.client?.auth.currentUser?.id;

    return openingAsync.when(
      loading: () => const _LoadingShell(),
      error: (e, _) => _ErrorShell(onRetry: () => ref.invalidate(openingDetailProvider(widget.openingId))),
      data: (opening) {
        if (opening == null) {
          return const _NotFoundShell();
        }

        final isOwner = opening.ownerId == currentUserId;
        final isLoggedIn = currentUserId != null;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Photo header
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppColors.surface,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                actions: [
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                      ),
                      color: AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) => _handleOwnerAction(v, opening),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                opening.isAvailable ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Text(opening.isAvailable ? 'Mark Unavailable' : 'Mark Available'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: opening.photoUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: opening.photoUrls.length,
                          itemBuilder: (context, index) => Image.network(
                            opening.photoUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
                          ),
                        )
                      : const _PhotoPlaceholder(),
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Availability badge
                    if (!opening.isAvailable)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text(
                              'This opening is no longer available',
                              style: TextStyle(color: AppColors.warning, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // Title
                    Text(
                      opening.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            opening.locationDisplay,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Posted
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          'Posted ${timeago.format(opening.createdAt)} by ${opening.ownerName}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Key facts
                    _KeyFactsSection(opening: opening),
                    const SizedBox(height: 24),

                    // Game & amenities
                    if (opening.game.isNotEmpty || opening.amenities.isNotEmpty) ...[
                      _TagsSection(opening: opening),
                      const SizedBox(height: 24),
                    ],

                    // Rules
                    if (opening.rules != null && opening.rules!.isNotEmpty) ...[
                      _RulesSection(rules: opening.rules!),
                      const SizedBox(height: 24),
                    ],

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      opening.description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // Contact section
                    _ContactSection(
                      opening: opening,
                      phoneRevealed: _phoneRevealed,
                      onRevealPhone: () => setState(() => _phoneRevealed = true),
                      onMessage: isLoggedIn && !isOwner ? () => _messageOwner(opening) : null,
                      isOwner: isOwner,
                      isLoggedIn: isLoggedIn,
                    ),

                    const SizedBox(height: 100), // Space for bottom bar
                  ]),
                ),
              ),
            ],
          ),

          // Bottom action bar
          bottomNavigationBar: !isOwner
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        // Price
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opening.priceFormatted,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (opening.spotsAvailable != null)
                                Text(
                                  '${opening.spotsAvailable} spot${opening.spotsAvailable == 1 ? '' : 's'} available',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),

                        // Message button
                        GestureDetector(
                          onTap: isLoggedIn
                              ? () => _messageOwner(opening)
                              : () => context.push('/auth'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isLoggedIn ? 'Message' : 'Sign in to Message',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _messageOwner(ClubOpening opening) async {
    HapticFeedback.mediumImpact();
    final service = ref.read(messagingServiceProvider);
    final threadId = await service.getOrCreateDM(otherUserId: opening.ownerId);
    if (threadId != null && mounted) {
      context.push('/messages/$threadId');
    }
  }

  Future<void> _handleOwnerAction(String action, ClubOpening opening) async {
    if (action == 'toggle') {
      final service = ref.read(clubOpeningsServiceProvider);
      await service.updateOpening(opening.id, isAvailable: !opening.isAvailable);
      ref.invalidate(openingDetailProvider(widget.openingId));
      ref.invalidate(openingsProvider);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Opening?', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'This action cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final service = ref.read(clubOpeningsServiceProvider);
        await service.deleteOpening(opening.id);
        ref.invalidate(openingsProvider);
        if (mounted) context.pop();
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SECTIONS
// ════════════════════════════════════════════════════════════════════════════

class _KeyFactsSection extends StatelessWidget {
  const _KeyFactsSection({required this.opening});

  final ClubOpening opening;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[];

    facts.add(_Fact(icon: Icons.attach_money_rounded, label: 'Price', value: opening.priceFormatted));

    if (opening.spotsAvailable != null) {
      facts.add(_Fact(icon: Icons.group_rounded, label: 'Spots', value: '${opening.spotsAvailable}'));
    }
    if (opening.acres != null) {
      facts.add(_Fact(icon: Icons.landscape_rounded, label: 'Acres', value: '${opening.acres}'));
    }
    if (opening.season != null && opening.season!.isNotEmpty) {
      facts.add(_Fact(icon: Icons.calendar_today_rounded, label: 'Season', value: opening.season!));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: facts.map((f) => SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(f.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                f.value,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _Fact {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.opening});

  final ClubOpening opening;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (opening.game.isNotEmpty) ...[
          const Text(
            'Game',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opening.game.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                g[0].toUpperCase() + g.substring(1),
                style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (opening.amenities.isNotEmpty) ...[
          const Text(
            'Amenities',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opening.amenities.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                a[0].toUpperCase() + a.substring(1),
                style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.rules});

  final String rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, size: 18, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Club Rules',
                style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rules,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.opening,
    required this.phoneRevealed,
    required this.onRevealPhone,
    required this.onMessage,
    required this.isOwner,
    required this.isLoggedIn,
  });

  final ClubOpening opening;
  final bool phoneRevealed;
  final VoidCallback onRevealPhone;
  final VoidCallback? onMessage;
  final bool isOwner;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Owner info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  opening.ownerName.isNotEmpty ? opening.ownerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opening.contactName ?? opening.ownerName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  if (opening.ownerHandle.isNotEmpty)
                    Text(
                      opening.ownerHandle,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),

          // Phone (if allowed)
          if ((opening.contactPreferred == 'phone' || opening.contactPreferred == 'both') &&
              opening.contactPhone != null &&
              opening.contactPhone!.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (phoneRevealed)
              Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    opening.contactPhone!,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: onRevealPhone,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_rounded, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        'Tap to reveal phone',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // Message button
          if (!isOwner) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onMessage ?? () => Navigator.of(context).pushNamed('/auth'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isLoggedIn ? 'Send Message' : 'Sign in to Message',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (isOwner) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'This is your listing',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHELL STATES
// ════════════════════════════════════════════════════════════════════════════

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Could not load opening', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundShell extends StatelessWidget {
  const _NotFoundShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('Opening not found', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: AppColors.textTertiary, size: 48),
      ),
    );
  }
}

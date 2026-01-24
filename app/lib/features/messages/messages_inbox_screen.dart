import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 💬 MESSAGES INBOX SCREEN - 2025 PREMIUM
///
/// Shows all DM conversations with unread indicators.
/// Uses polling for updates (30s interval) to avoid heavy realtime subscriptions.
class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  ConsumerState<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadInbox();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 30 seconds for inbox updates
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadInbox(silent: true);
      }
    });
  }

  Future<void> _loadInbox({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final service = ref.read(messagingServiceProvider);
      final conversations = await service.getInbox();

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        // Also refresh unread count
        ref.read(unreadCountProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadInbox,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            boxShadow: AppColors.shadowAccent,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.textInverse,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Messages',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _conversations.isEmpty
                                    ? 'Your conversations'
                                    : '${_conversations.length} conversation${_conversations.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _loadInbox,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              if (!isAuthenticated)
                SliverFillRemaining(
                  child: _NotAuthenticatedState(),
                )
              else if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: AppErrorState(
                    message: _error!,
                    onRetry: _loadInbox,
                  ),
                )
              else if (_conversations.isEmpty)
                SliverFillRemaining(
                  child: _EmptyInboxState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final conversation = _conversations[index];
                        return _ConversationTile(
                          conversation: conversation,
                          onTap: () {
                            context.push('/messages/${conversation.id}');
                          },
                        );
                      },
                      childCount: _conversations.length,
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotAuthenticatedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Sign In to Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create an account or sign in to send and receive messages.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButtonPrimary(
              label: 'Sign In',
              onPressed: () => context.push('/auth'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'When you contact a seller or another hunter, your conversations will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final hasUnread = conv.hasUnread;
    final contextBadge = conv.contextBadge;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surfaceHover
                : (hasUnread ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surface),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: hasUnread
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              // Avatar with optional context badge
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hasUnread
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: conv.otherUserAvatar != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            child: Image.network(
                              conv.otherUserAvatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _AvatarInitial(
                                name: conv.otherUserName,
                                hasUnread: hasUnread,
                              ),
                            ),
                          )
                        : _AvatarInitial(
                            name: conv.otherUserName,
                            hasUnread: hasUnread,
                          ),
                  ),
                  // Context type badge
                  if (contextBadge.isNotEmpty)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getContextColor(conv.subjectType),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          contextBadge,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.otherUserName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.lastMessageAt != null)
                          Text(
                            _formatTime(conv.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? AppColors.accent : AppColors.textTertiary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),

                    // Subject title (if present)
                    if (conv.subjectTitle != null && conv.subjectTitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        conv.subjectTitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Last message preview
                    if (conv.lastMessageBody != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        conv.lastMessageBody!,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Unread badge
              if (hasUnread) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    conv.unreadCount > 99 ? '99+' : conv.unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getContextColor(String? type) {
    switch (type) {
      case 'swap':
        return AppColors.warning;
      case 'land':
        return AppColors.success;
      case 'trophy':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && messageDay == today) return '${diff.inHours}h';
    
    // Yesterday
    if (messageDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    
    // This week (show day name)
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }

    // Older (show date)
    return '${date.month}/${date.day}';
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({
    required this.name,
    required this.hasUnread,
  });

  final String name;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: hasUnread ? AppColors.accent : AppColors.primary,
        ),
      ),
    );
  }
}

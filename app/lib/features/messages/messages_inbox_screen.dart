import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:shed/utils/privacy_utils.dart';

/// Messages Inbox Screen with Inbox/Sent tabs.
class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  ConsumerState<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MessageThread> _allThreads = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThreads();
    _startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadThreads(silent: true);
      }
    });
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final service = ref.read(messagingServiceProvider);
      final threads = await service.getThreads();

      if (mounted) {
        setState(() {
          _allThreads = threads;
          _isLoading = false;
        });
        ref.read(messageUnreadCountProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'Unable to load messages. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<MessageThread> get _inboxThreads {
    final currentUserId = ref.read(currentUserProvider)?.id;
    return _allThreads.where((t) => t.isInbox(currentUserId)).toList();
  }

  List<MessageThread> get _sentThreads {
    final currentUserId = ref.read(currentUserProvider)?.id;
    return _allThreads.where((t) => t.isSent(currentUserId)).toList();
  }

  void _openNewMessage() {
    showShedCenterModal(
      context: context,
      title: 'New Message',
      maxWidth: 400,
      maxHeight: 500,
      child: _UserSearchContent(
        onUserSelected: (userId, userName) async {
          Navigator.of(context, rootNavigator: true).pop();
          try {
            final service = ref.read(messagingServiceProvider);
            final threadId = await service.getOrCreateDM(otherUserId: userId);
            if (mounted) {
              context.push('/messages/$threadId');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final inboxCount = _inboxThreads.where((t) => t.hasUnread(currentUserId)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header
            SafeArea(
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
                            _allThreads.isEmpty
                                ? 'Your conversations'
                                : '${_allThreads.length} conversation${_allThreads.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _NewMessageButton(onNewMessage: _openNewMessage),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadThreads,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // Tab bar
            if (isAuthenticated && !_isLoading && _error == null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.textInverse,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Inbox'),
                          if (inboxCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                inboxCount > 99 ? '99+' : inboxCount.toString(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Sent'),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),

            // Content
            Expanded(
              child: !isAuthenticated
                  ? _NotAuthenticatedState()
                  : _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        )
                      : _error != null
                          ? AppErrorState(
                              message: _error!,
                              onRetry: _loadThreads,
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _ThreadListView(
                                  threads: _inboxThreads,
                                  emptyTitle: 'No Messages Yet',
                                  emptySubtitle: 'When someone messages you, it will appear here.',
                                  onRefresh: _loadThreads,
                                ),
                                _ThreadListView(
                                  threads: _sentThreads,
                                  emptyTitle: 'No Sent Messages',
                                  emptySubtitle: 'Messages you send will appear here.',
                                  onRefresh: _loadThreads,
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListView extends ConsumerWidget {
  const _ThreadListView({
    required this.threads,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
  });

  final List<MessageThread> threads;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (threads.isEmpty) {
      return _EmptyState(title: emptyTitle, subtitle: emptySubtitle);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: threads.length,
        itemBuilder: (context, index) {
          final thread = threads[index];
          return _ThreadTile(
            thread: thread,
            onTap: () => context.push('/messages/${thread.id}'),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({
    required this.thread,
    required this.onTap,
  });

  final MessageThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final hasUnread = thread.hasUnread(currentUserId);
    final isClub = thread.type == ThreadType.club;

    return _HoverContainer(
      hasUnread: hasUnread,
      onTap: onTap,
      child: Row(
        children: [
          // Avatar
          _ThreadAvatar(thread: thread, hasUnread: hasUnread),
          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and time
                Row(
                  children: [
                    // Thread type badge
                    if (isClub)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CLUB',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        thread.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (thread.lastMessageAt != null)
                      Text(
                        _formatTime(thread.lastMessageAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.accent : AppColors.textTertiary,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                  ],
                ),

                // Username for DMs
                if (!isClub && thread.handle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${thread.handle}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Message preview
                if (thread.lastMessageBody != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    thread.lastMessageBody!,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
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

          // Unread indicator
          if (hasUnread) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && messageDay == today) return '${diff.inHours}h';

    if (messageDay == today.subtract(const Duration(days: 1))) return 'Yesterday';

    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }

    return '${date.month}/${date.day}';
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({
    required this.thread,
    required this.hasUnread,
  });

  final MessageThread thread;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final isClub = thread.type == ThreadType.club;
    final avatarPath = isClub ? thread.clubLogoPath : thread.otherAvatarPath;
    final initial = thread.displayName.isNotEmpty ? thread.displayName[0].toUpperCase() : 'U';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: hasUnread
            ? AppColors.accent.withValues(alpha: 0.15)
            : (isClub ? AppColors.info.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(isClub ? AppSpacing.radiusMd : AppSpacing.radiusFull),
      ),
      child: avatarPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(isClub ? AppSpacing.radiusMd : AppSpacing.radiusFull),
              child: Image.network(
                avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarInitial(initial: initial, hasUnread: hasUnread, isClub: isClub),
              ),
            )
          : _AvatarInitial(initial: initial, hasUnread: hasUnread, isClub: isClub),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({
    required this.initial,
    required this.hasUnread,
    required this.isClub,
  });

  final String initial;
  final bool hasUnread;
  final bool isClub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isClub
          ? Icon(
              Icons.groups_rounded,
              size: 24,
              color: hasUnread ? AppColors.accent : AppColors.info,
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: hasUnread ? AppColors.accent : AppColors.primary,
              ),
            ),
    );
  }
}

class _HoverContainer extends StatefulWidget {
  const _HoverContainer({
    required this.child,
    required this.hasUnread,
    required this.onTap,
  });

  final Widget child;
  final bool hasUnread;
  final VoidCallback onTap;

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
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
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surfaceHover
                : (widget.hasUnread ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surface),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: widget.hasUnread
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
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

class _NewMessageButton extends StatefulWidget {
  const _NewMessageButton({required this.onNewMessage});

  final VoidCallback onNewMessage;

  @override
  State<_NewMessageButton> createState() => _NewMessageButtonState();
}

class _NewMessageButtonState extends State<_NewMessageButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onNewMessage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: _isHovered ? AppColors.accentGradient : null,
            color: _isHovered ? null : AppColors.accent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: _isHovered ? AppColors.shadowAccent : null,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'New',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// User search content for new message modal.
class _UserSearchContent extends ConsumerStatefulWidget {
  const _UserSearchContent({required this.onUserSelected});

  final void Function(String userId, String userName) onUserSelected;

  @override
  ConsumerState<_UserSearchContent> createState() => _UserSearchContentState();
}

class _UserSearchContentState extends ConsumerState<_UserSearchContent> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('Not connected');

      final currentUserId = client.auth.currentUser?.id;

      final response = await client
          .from('profiles')
          .select('id, username, display_name, avatar_path')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', currentUserId ?? '')
          .limit(10);

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by @username or name...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
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
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
          onChanged: (value) => _search(value.trim()),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('Error: $_error', style: TextStyle(color: AppColors.error)),
          )
        else if (_results.isEmpty && _searchController.text.length >= 2)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(Icons.person_search_rounded, size: 40, color: AppColors.textTertiary),
                const SizedBox(height: AppSpacing.sm),
                Text('No users found', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('Type to search for users', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...List.generate(_results.length, (index) {
            final user = _results[index];
            final name = getSafeDisplayName(
              displayName: user['display_name'] as String?,
              username: user['username'] as String?,
            );
            final safeUsername = sanitizeDisplayValue(user['username'] as String?);

            return _UserResultTile(
              name: name,
              username: safeUsername,
              onTap: () => widget.onUserSelected(user['id'], name),
            );
          }),
      ],
    );
  }
}

class _UserResultTile extends StatefulWidget {
  const _UserResultTile({
    required this.name,
    required this.username,
    required this.onTap,
  });

  final String name;
  final String? username;
  final VoidCallback onTap;

  @override
  State<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
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
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.username != null)
                      Text(
                        '@${widget.username}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: _isHovered ? AppColors.accent : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

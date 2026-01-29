import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/utils/navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thread/Conversation Screen - Real-time chat view.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<ThreadMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = false;
  bool _isSending = false;
  String? _error;

  MessageThread? _thread;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    _subscribeToMessages();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels < 100 &&
        !_isLoadingMore &&
        _hasMoreMessages &&
        _messages.isNotEmpty) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(messagingServiceProvider);
      final page = await service.getMessages(widget.conversationId, limit: 50);

      // Get thread info
      final thread = await service.getThread(widget.conversationId);

      if (mounted) {
        setState(() {
          _messages = page.messages;
          _hasMoreMessages = page.hasMore;
          _thread = thread;
          _isLoading = false;
        });
        _scrollToBottom();
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

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final service = ref.read(messagingServiceProvider);
      final oldestMessage = _messages.first;
      final page = await service.getMessages(
        widget.conversationId,
        limit: 30,
        beforeId: oldestMessage.id,
      );

      if (mounted) {
        final oldScrollPosition = _scrollController.position.pixels;
        final oldMaxScroll = _scrollController.position.maxScrollExtent;

        setState(() {
          _messages = [...page.messages, ..._messages];
          _hasMoreMessages = page.hasMore;
          _isLoadingMore = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxScroll = _scrollController.position.maxScrollExtent;
            final scrollDelta = newMaxScroll - oldMaxScroll;
            _scrollController.jumpTo(oldScrollPosition + scrollDelta);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _markAsRead() async {
    try {
      final service = ref.read(messagingServiceProvider);
      await service.markThreadRead(widget.conversationId);
      ref.read(messageUnreadCountProvider.notifier).refresh();
    } catch (_) {}
  }

  void _subscribeToMessages() {
    try {
      final service = ref.read(messagingServiceProvider);
      _channel = service.subscribeToThread(
        widget.conversationId,
        (message) {
          if (mounted) {
            final currentUserId = ref.read(currentUserProvider)?.id;
            if (message.senderId != currentUserId) {
              setState(() {
                _messages.add(message);
              });
              _scrollToBottom();
              _markAsRead();
            }
          }
        },
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final service = ref.read(messagingServiceProvider);
      final message = await service.sendMessage(
        threadId: widget.conversationId,
        body: body,
      );

      if (mounted) {
        setState(() {
          _messages.add(message);
          _messageController.clear();
          _isSending = false;
        });
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!kIsWeb) return KeyEventResult.ignored;

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _sendMessage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final hasText = _messageController.text.trim().isNotEmpty;
    final isClub = _thread?.type == ThreadType.club;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: _thread == null
            ? const Text('Loading...')
            : Row(
                children: [
                  // Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isClub
                          ? AppColors.info.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(isClub ? 8 : 18),
                    ),
                    child: Center(
                      child: isClub
                          ? const Icon(Icons.groups_rounded, size: 18, color: AppColors.info)
                          : Text(
                              _thread!.displayName.isNotEmpty
                                  ? _thread!.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _thread!.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isClub && _thread!.handle != null)
                          Text(
                            '@${_thread!.handle}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          )
                        else if (isClub)
                          Text(
                            'Club Chat',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => goHome(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderSubtle),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error loading messages',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: _loadMessages,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? const _EmptyConversationState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingMore && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final messageIndex = _isLoadingMore ? index - 1 : index;
                              final message = _messages[messageIndex];
                              final isMine = message.isMine(currentUserId);
                              final showSender = isClub &&
                                  !isMine &&
                                  (messageIndex == 0 ||
                                      _messages[messageIndex - 1].senderId != message.senderId);

                              return _MessageBubble(
                                message: message,
                                isMine: isMine,
                                showSender: showSender,
                                isClubChat: isClub,
                              );
                            },
                          ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              bottom: bottomPadding + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Focus(
                        onKeyEvent: _handleKeyEvent,
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: AppColors.textTertiary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: kIsWeb ? TextInputAction.none : TextInputAction.send,
                          onSubmitted: kIsWeb ? null : (_) => _sendMessage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SendButton(
                    isSending: _isSending,
                    isEnabled: hasText && !_isSending,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Icon(Icons.waving_hand_rounded, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Say hello!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Start the conversation with a friendly message.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.isClubChat,
  });

  final ThreadMessage message;
  final bool isMine;
  final bool showSender;
  final bool isClubChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? AppSpacing.md : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name for club chat
          if (showSender && isClubChat)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar (for received messages)
              if (!isMine) ...[
                if (showSender || !isClubChat)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        message.senderName.isNotEmpty
                            ? message.senderName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 32),
                const SizedBox(width: AppSpacing.sm),
              ],

              // Message bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.radiusLg),
                      topRight: const Radius.circular(AppSpacing.radiusLg),
                      bottomLeft: Radius.circular(isMine ? AppSpacing.radiusLg : 4),
                      bottomRight: Radius.circular(isMine ? 4 : AppSpacing.radiusLg),
                    ),
                    border: isMine ? null : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.body,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMine ? Colors.white : AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isMine) const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.isSending,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isSending;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.isEnabled || widget.isSending;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.surface
                : (_isHovered ? AppColors.accentMuted : AppColors.accent),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isDisabled ? Border.all(color: AppColors.borderSubtle) : null,
            boxShadow: (!isDisabled && _isHovered) ? AppColors.shadowAccent : null,
          ),
          child: widget.isSending
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  color: isDisabled ? AppColors.textTertiary : Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

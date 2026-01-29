import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

// ============================================
// MODELS
// ============================================

/// Thread type enum.
enum ThreadType { dm, club }

/// A message thread (DM or club chat).
class MessageThread {
  MessageThread({
    required this.id,
    required this.type,
    this.clubId,
    this.clubName,
    this.clubLogoPath,
    this.otherUserId,
    this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarPath,
    this.lastMessageId,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.lastReadAt,
    this.archived = false,
    this.muted = false,
    required this.updatedAt,
  });

  final String id;
  final ThreadType type;
  final String? clubId;
  final String? clubName;
  final String? clubLogoPath;
  final String? otherUserId;
  final String? otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarPath;
  final String? lastMessageId;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime? lastReadAt;
  final bool archived;
  final bool muted;
  final DateTime updatedAt;

  /// Display name for the thread.
  String get displayName {
    if (type == ThreadType.club) {
      return clubName ?? 'Club Chat';
    }
    return otherDisplayName ?? otherUsername ?? 'User';
  }

  /// Username (@handle) for DM threads.
  String? get handle => type == ThreadType.dm ? otherUsername : null;

  /// Check if thread has unread messages.
  bool hasUnread(String? currentUserId) {
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId == currentUserId) return false;
    if (lastReadAt == null) return true;
    return lastMessageAt!.isAfter(lastReadAt!);
  }

  /// Check if this is an "Inbox" thread (last message from someone else).
  bool isInbox(String? currentUserId) {
    if (lastMessageSenderId == null) return true; // No messages yet
    return lastMessageSenderId != currentUserId;
  }

  /// Check if this is a "Sent" thread (last message from current user).
  bool isSent(String? currentUserId) {
    if (lastMessageSenderId == null) return false;
    return lastMessageSenderId == currentUserId;
  }

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: json['thread_id'] as String,
      type: json['thread_type'] == 'club' ? ThreadType.club : ThreadType.dm,
      clubId: json['club_id'] as String?,
      clubName: json['club_name'] as String?,
      clubLogoPath: json['club_logo_path'] as String?,
      otherUserId: json['other_user_id'] as String?,
      otherUsername: json['other_username'] as String?,
      otherDisplayName: json['other_display_name'] as String?,
      otherAvatarPath: json['other_avatar_path'] as String?,
      lastMessageId: json['last_message_id'] as String?,
      lastMessageBody: json['last_message_body'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : null,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String).toLocal()
          : null,
      archived: json['archived'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      updatedAt: json['thread_updated_at'] != null
          ? DateTime.parse(json['thread_updated_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}

/// A single message in a thread.
class ThreadMessage {
  ThreadMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatarPath,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatarPath;

  String get senderName => senderDisplayName ?? senderUsername ?? 'User';

  bool isMine(String? currentUserId) => senderId == currentUserId;

  factory ThreadMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ThreadMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      senderUsername: sender?['username'] as String?,
      senderDisplayName: sender?['display_name'] as String?,
      senderAvatarPath: sender?['avatar_path'] as String?,
    );
  }
}

/// Paginated messages result.
class MessagesPage {
  MessagesPage({
    required this.messages,
    required this.hasMore,
  });

  final List<ThreadMessage> messages;
  final bool hasMore;
}

// ============================================
// SERVICE
// ============================================

/// Messaging service for DMs and club chats.
class MessagingService {
  MessagingService(this._client);

  final SupabaseClient? _client;

  // ============ THREADS ============

  /// Get all threads (inbox view).
  Future<List<MessageThread>> getThreads() async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc('get_inbox_threads');
      if (response == null) return [];

      return (response as List)
          .map((row) => MessageThread.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MessagingService] Error fetching threads: $e');
      }
      rethrow;
    }
  }

  /// Get or create a DM thread with another user.
  /// Subject parameters are legacy and not used in the new thread system.
  Future<String> getOrCreateDM({
    required String otherUserId,
    String? subjectType,
    String? subjectId,
    String? subjectTitle,
    String? initialMessage,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final response = await _client.rpc(
      'get_or_create_dm_thread',
      params: {'p_other_user_id': otherUserId},
    );

    if (response == null) throw Exception('Failed to create DM thread');
    return response as String;
  }

  /// Get or create a club chat thread.
  Future<String> getOrCreateClubThread(String clubId) async {
    if (_client == null) throw Exception('Not connected');

    final response = await _client.rpc(
      'get_or_create_club_thread',
      params: {'p_club_id': clubId},
    );

    if (response == null) throw Exception('Failed to create club thread');
    return response as String;
  }

  /// Sync club thread participants when membership changes.
  Future<void> syncClubThreadParticipants(String clubId) async {
    if (_client == null) return;

    await _client.rpc(
      'sync_club_thread_participants',
      params: {'p_club_id': clubId},
    );
  }

  // ============ MESSAGES ============

  /// Get messages for a thread (paginated, newest first -> reversed for display).
  Future<MessagesPage> getMessages(
    String threadId, {
    int limit = 50,
    String? beforeId,
  }) async {
    if (_client == null) return MessagesPage(messages: [], hasMore: false);

    var query = _client
        .from('messages_v2')
        .select('''
          id,
          thread_id,
          sender_id,
          body,
          created_at,
          sender:profiles!messages_v2_sender_profiles_fkey (
            id,
            username,
            display_name,
            avatar_path
          )
        ''')
        .eq('thread_id', threadId);

    // For pagination: get messages before cursor
    if (beforeId != null) {
      final cursorMsg = await _client
          .from('messages_v2')
          .select('created_at')
          .eq('id', beforeId)
          .single();
      final cursorTime = cursorMsg['created_at'] as String;
      query = query.lt('created_at', cursorTime);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit + 1);

    final allRows = (response as List)
        .map((row) => ThreadMessage.fromJson(row as Map<String, dynamic>))
        .toList();

    final hasMore = allRows.length > limit;
    final messages = hasMore ? allRows.sublist(0, limit) : allRows;

    // Return oldest first for display
    return MessagesPage(
      messages: messages.reversed.toList(),
      hasMore: hasMore,
    );
  }

  /// Send a message to a thread.
  Future<ThreadMessage> sendMessage({
    required String threadId,
    required String body,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('messages_v2')
        .insert({
          'thread_id': threadId,
          'sender_id': userId,
          'body': body.trim(),
        })
        .select('''
          id,
          thread_id,
          sender_id,
          body,
          created_at,
          sender:profiles!messages_v2_sender_profiles_fkey (
            id,
            username,
            display_name,
            avatar_path
          )
        ''')
        .single();

    final message = ThreadMessage.fromJson(response);

    // Trigger push notification via edge function (fire and forget)
    _notifyNewMessage(threadId: threadId, message: message);

    return message;
  }

  /// Trigger push notification for new message.
  Future<void> _notifyNewMessage({
    required String threadId,
    required ThreadMessage message,
  }) async {
    try {
      // Call edge function for push notification
      await _client?.functions.invoke(
        'notify-message',
        body: {
          'threadId': threadId,
          'senderId': message.senderId,
          'messagePreview': message.body.length > 100
              ? '${message.body.substring(0, 100)}...'
              : message.body,
        },
      );
    } catch (e) {
      // Don't fail send if notification fails
      if (kDebugMode) {
        debugPrint('[MessagingService] Push notification error: $e');
      }
    }
    
    // Create in-app notification for other thread participants
    try {
      // Get thread participants
      final participants = await _client
          ?.from('thread_participants')
          .select('user_id')
          .eq('thread_id', threadId)
          .neq('user_id', message.senderId);
      
      if (participants != null) {
        final senderName = message.senderDisplayName ?? message.senderUsername ?? 'Someone';
        final preview = message.body.length > 50 
            ? '${message.body.substring(0, 50)}...' 
            : message.body;
        
        for (final p in participants) {
          final recipientId = p['user_id'] as String?;
          if (recipientId != null) {
            await _client?.from('notifications').insert({
              'user_id': recipientId,
              'type': 'message',
              'title': 'New Message',
              'body': '$senderName: $preview',
              'data': {
                'route': '/messages/$threadId',
                'thread_id': threadId,
                'sender_id': message.senderId,
              },
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MessagingService] In-app notification error: $e');
      }
    }
  }

  // ============ READ STATUS ============

  /// Mark a thread as read.
  Future<void> markThreadRead(String threadId) async {
    if (_client == null) return;

    await _client.rpc('mark_thread_read', params: {'p_thread_id': threadId});
  }

  /// Get total unread thread count.
  Future<int> getUnreadCount() async {
    if (_client == null) return 0;

    try {
      final response = await _client.rpc('get_unread_message_count');
      return response as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ============ REALTIME ============

  /// Subscribe to new messages in a thread.
  RealtimeChannel subscribeToThread(
    String threadId,
    void Function(ThreadMessage) onMessage,
  ) {
    if (_client == null) throw Exception('Not connected');

    return _client
        .channel('messages_v2:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages_v2',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              // Fetch full message with sender info
              try {
                final msg = await _client
                    .from('messages_v2')
                    .select('''
                      id,
                      thread_id,
                      sender_id,
                      body,
                      created_at,
                      sender:profiles!messages_v2_sender_profiles_fkey (
                        id,
                        username,
                        display_name,
                        avatar_path
                      )
                    ''')
                    .eq('id', newRecord['id'])
                    .single();
                onMessage(ThreadMessage.fromJson(msg));
              } catch (e) {
                // Fallback to basic message without sender info
                onMessage(ThreadMessage.fromJson(newRecord));
              }
            }
          },
        )
        .subscribe();
  }

  /// Subscribe to thread updates (for inbox refresh).
  RealtimeChannel subscribeToThreadUpdates(void Function() onUpdate) {
    if (_client == null) throw Exception('Not connected');

    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    return _client
        .channel('thread_updates:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_threads',
          callback: (payload) {
            onUpdate();
          },
        )
        .subscribe();
  }

  // ============ THREAD INFO ============

  /// Get thread info by ID.
  Future<MessageThread?> getThread(String threadId) async {
    if (_client == null) return null;

    final threads = await getThreads();
    return threads.where((t) => t.id == threadId).firstOrNull;
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Provider for messaging service.
final messagingServiceProvider = Provider<MessagingService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MessagingService(client);
});

/// Provider for all threads.
final threadsProvider = FutureProvider<List<MessageThread>>((ref) async {
  final service = ref.watch(messagingServiceProvider);
  return service.getThreads();
});

/// Provider for unread count.
final messageUnreadCountProvider =
    StateNotifierProvider<MessageUnreadCountNotifier, int>((ref) {
  final service = ref.watch(messagingServiceProvider);
  return MessageUnreadCountNotifier(service);
});

class MessageUnreadCountNotifier extends StateNotifier<int> {
  MessageUnreadCountNotifier(this._service) : super(0) {
    refresh();
  }

  final MessagingService _service;

  Future<void> refresh() async {
    state = await _service.getUnreadCount();
  }

  void decrement(int count) {
    state = (state - count).clamp(0, 9999);
  }
}

// ============================================
// LEGACY COMPATIBILITY (for existing code)
// ============================================

/// Legacy Conversation model mapped to MessageThread.
class Conversation {
  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessageBody,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.subjectType,
    this.subjectTitle,
    this.unreadCount = 0,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? subjectType;
  final String? subjectTitle;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  String get contextBadge {
    if (subjectType == null) return '';
    switch (subjectType) {
      case 'swap':
        return 'Swap';
      case 'land':
        return 'Land';
      case 'trophy':
        return 'Trophy';
      default:
        return '';
    }
  }

  String get subjectLabel {
    if (subjectType == null || subjectTitle == null) return '';
    switch (subjectType) {
      case 'swap':
        return 'Swap: $subjectTitle';
      case 'land':
        return 'Land: $subjectTitle';
      case 'trophy':
        return 'Trophy: $subjectTitle';
      default:
        return subjectTitle ?? '';
    }
  }

  /// Create from MessageThread for compatibility.
  factory Conversation.fromThread(MessageThread thread, String? currentUserId) {
    return Conversation(
      id: thread.id,
      otherUserId: thread.otherUserId ?? '',
      otherUserName: thread.displayName,
      otherUserAvatar: thread.otherAvatarPath,
      lastMessageBody: thread.lastMessageBody,
      lastMessageAt: thread.lastMessageAt,
      lastMessageSenderId: thread.lastMessageSenderId,
      unreadCount: thread.hasUnread(currentUserId) ? 1 : 0,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['conversation_id'] as String,
      otherUserId: json['other_user_id'] as String,
      otherUserName: json['other_user_name'] as String? ?? 'User',
      otherUserAvatar: json['other_user_avatar'] as String?,
      lastMessageBody: json['last_message_body'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      subjectType: json['subject_type'] as String?,
      subjectTitle: json['subject_title'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Legacy Message model - alias to ThreadMessage.
class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.subjectType,
    this.subjectTitle,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? subjectType;
  final String? subjectTitle;

  bool isMine(String? currentUserId) => senderId == currentUserId;

  factory Message.fromThreadMessage(ThreadMessage m) {
    return Message(
      id: m.id,
      conversationId: m.threadId,
      senderId: m.senderId,
      body: m.body,
      createdAt: m.createdAt,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      subjectType: json['subject_type'] as String?,
      subjectTitle: json['subject_title'] as String?,
    );
  }
}

/// Legacy inbox provider.
final inboxProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.watch(messagingServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  final currentUserId = client?.auth.currentUser?.id;
  
  final threads = await service.getThreads();
  return threads
      .where((t) => t.type == ThreadType.dm)
      .map((t) => Conversation.fromThread(t, currentUserId))
      .toList();
});

/// Legacy unread count provider (alias).
final unreadCountProvider = messageUnreadCountProvider;

class UnreadCountNotifier extends MessageUnreadCountNotifier {
  UnreadCountNotifier(super.service);
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Conversation model for inbox display.
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

  bool get hasUnread => unreadCount > 0;

  /// Short context label for inbox (e.g., "Swap", "Land", "Trophy")
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

  /// Full subject label with title
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
}

/// Message model.
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

  bool isMine(String? currentUserId) => senderId == currentUserId;
}

/// Result for paginated messages.
class MessagesPage {
  MessagesPage({
    required this.messages,
    required this.hasMore,
  });

  final List<Message> messages;
  final bool hasMore;
}

/// Messaging service for DMs.
class MessagingService {
  MessagingService(this._client);

  final SupabaseClient? _client;

  /// Get or create a DM conversation with another user.
  /// Returns the conversation_id.
  Future<String> getOrCreateDM({
    required String otherUserId,
    String? subjectType,
    String? subjectId,
    String? subjectTitle,
    String? initialMessage,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final response = await _client.rpc('get_or_create_dm', params: {
      'other_user_id': otherUserId,
      'p_subject_type': subjectType,
      'p_subject_id': subjectId,
      'p_subject_title': subjectTitle,
      'initial_message': initialMessage,
    });

    if (response == null) throw Exception('Failed to create conversation');

    final data = response as Map<String, dynamic>;
    return data['conversation_id'] as String;
  }

  /// Get inbox (all conversations with last message and unread count).
  Future<List<Conversation>> getInbox() async {
    if (_client == null) return [];

    final response = await _client.rpc('get_inbox');

    if (response == null) return [];

    return (response as List)
        .map((row) => Conversation.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Get messages for a conversation (paginated).
  /// Returns newest messages first, reversed to oldest-first for display.
  /// Use [beforeId] to load older messages (pagination).
  Future<MessagesPage> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeId,
  }) async {
    if (_client == null) return MessagesPage(messages: [], hasMore: false);

    var query = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);

    // If loading older messages, get messages created before the cursor message
    if (beforeId != null) {
      // First get the timestamp of the cursor message
      final cursorMsg = await _client
          .from('messages')
          .select('created_at')
          .eq('id', beforeId)
          .single();
      final cursorTime = cursorMsg['created_at'] as String;
      query = query.lt('created_at', cursorTime);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit + 1); // Fetch one extra to check if there's more

    final allRows = (response as List)
        .map((row) => Message.fromJson(row as Map<String, dynamic>))
        .toList();

    final hasMore = allRows.length > limit;
    final messages = hasMore ? allRows.sublist(0, limit) : allRows;

    // Return oldest first for display
    return MessagesPage(
      messages: messages.reversed.toList(),
      hasMore: hasMore,
    );
  }

  /// Get initial messages (convenience wrapper).
  Future<List<Message>> getInitialMessages(String conversationId, {int limit = 50}) async {
    final page = await getMessages(conversationId, limit: limit);
    return page.messages;
  }

  /// Send a message to a conversation.
  Future<Message> sendMessage({
    required String conversationId,
    required String body,
    String? subjectType,
    String? subjectId,
    String? subjectTitle,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'body': body.trim(),
      'subject_type': subjectType,
      'subject_id': subjectId,
      'subject_title': subjectTitle,
    }).select().single();

    return Message.fromJson(response);
  }

  /// Mark conversation as read.
  Future<void> markConversationRead(String conversationId) async {
    if (_client == null) return;

    await _client.rpc('mark_conversation_read', params: {
      'p_conversation_id': conversationId,
    });
  }

  /// Get total unread count.
  Future<int> getUnreadCount() async {
    if (_client == null) return 0;

    try {
      final response = await _client.rpc('get_unread_count');
      return response as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Subscribe to new messages in a conversation.
  RealtimeChannel subscribeToConversation(
    String conversationId,
    void Function(Message) onMessage,
  ) {
    if (_client == null) throw Exception('Not connected');

    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onMessage(Message.fromJson(newRecord));
            }
          },
        )
        .subscribe();
  }

  /// Subscribe to conversation updates (when conversations are updated).
  /// This is more efficient than subscribing to all messages.
  RealtimeChannel subscribeToConversationUpdates(void Function() onUpdate) {
    if (_client == null) throw Exception('Not connected');

    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    return _client
        .channel('conversation_updates:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            onUpdate();
          },
        )
        .subscribe();
  }
}

/// Provider for messaging service.
final messagingServiceProvider = Provider<MessagingService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MessagingService(client);
});

/// Provider for inbox data.
final inboxProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.watch(messagingServiceProvider);
  return service.getInbox();
});

/// Provider for unread count.
final unreadCountProvider = StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  final service = ref.watch(messagingServiceProvider);
  return UnreadCountNotifier(service);
});

class UnreadCountNotifier extends StateNotifier<int> {
  UnreadCountNotifier(this._service) : super(0) {
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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/privacy_utils.dart';
import 'supabase_service.dart';

/// Social interactions service for likes, comments, and reports.
class SocialService {
  SocialService(this._client);
  
  final SupabaseClient? _client;
  
  // ============ LIKES ============
  
  /// Check if current user has liked a post.
  Future<bool> hasLiked(String postId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    final response = await _client
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    
    return response != null;
  }
  
  /// Toggle like on a post. Returns new liked state.
  Future<bool> toggleLike(String postId) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    // Check if already liked
    final existing = await _client
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    
    if (existing != null) {
      // Unlike
      await _client
          .from('post_likes')
          .delete()
          .eq('id', existing['id']);
      return false;
    } else {
      // Like
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      
      // Create notification for post owner (if not liking own post)
      try {
        final post = await _client
            .from('trophy_posts')
            .select('user_id')
            .eq('id', postId)
            .maybeSingle();
        
        final postOwnerId = post?['user_id'] as String?;
        if (postOwnerId != null && postOwnerId != userId) {
          // Get liker's username
          final profile = await _client
              .from('profiles')
              .select('username, display_name')
              .eq('id', userId)
              .maybeSingle();
          
          final likerName = getSafeDisplayName(
            displayName: profile?['display_name'] as String?,
            username: profile?['username'] as String?,
            defaultName: 'Someone',
          );
          
          await _client.from('notifications').insert({
            'user_id': postOwnerId,
            'type': 'like',
            'title': 'New Like',
            'body': '$likerName liked your trophy post',
            'data': {
              'route': '/trophy/$postId',
              'post_id': postId,
              'liker_id': userId,
            },
          });
        }
      } catch (e) {
        // Don't fail the like if notification fails
        if (kDebugMode) {
          debugPrint('[SocialService] Error creating like notification: $e');
        }
      }
      
      return true;
    }
  }
  
  /// Get like count for a post.
  Future<int> getLikeCount(String postId) async {
    if (_client == null) return 0;
    
    final response = await _client
        .from('trophy_posts')
        .select('likes_count')
        .eq('id', postId)
        .single();
    
    return response['likes_count'] ?? 0;
  }
  
  // ============ COMMENTS ============
  
  /// Fetch comments for a post.
  Future<List<Comment>> fetchComments(String postId) async {
    if (_client == null) return [];
    
    final response = await _client
        .from('post_comments')
        .select('''
          id,
          body,
          created_at,
          user_id,
          profiles:user_id (
            id,
            username,
            display_name,
            avatar_path
          )
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((row) => Comment.fromJson(row))
        .toList();
  }
  
  /// Add a comment to a post.
  Future<Comment> addComment(String postId, String body) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    final response = await _client
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'body': body.trim(),
        })
        .select('''
          id,
          body,
          created_at,
          user_id,
          profiles:user_id (
            id,
            username,
            display_name,
            avatar_path
          )
        ''')
        .single();
    
    // Create notification for post owner (if not commenting on own post)
    try {
      final post = await _client
          .from('trophy_posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      
      final postOwnerId = post?['user_id'] as String?;
      if (postOwnerId != null && postOwnerId != userId) {
        // Get commenter's username
        final profile = await _client
            .from('profiles')
            .select('username, display_name')
            .eq('id', userId)
            .maybeSingle();
        
        final commenterName = getSafeDisplayName(
          displayName: profile?['display_name'] as String?,
          username: profile?['username'] as String?,
          defaultName: 'Someone',
        );
        final truncatedBody = body.length > 50 ? '${body.substring(0, 50)}...' : body;
        
        await _client.from('notifications').insert({
          'user_id': postOwnerId,
          'type': 'comment',
          'title': 'New Comment',
          'body': '$commenterName commented: "$truncatedBody"',
          'data': {
            'route': '/trophy/$postId',
            'post_id': postId,
            'commenter_id': userId,
          },
        });
      }
    } catch (e) {
      // Don't fail the comment if notification fails
      if (kDebugMode) {
        debugPrint('[SocialService] Error creating comment notification: $e');
      }
    }
    
    return Comment.fromJson(response);
  }
  
  /// Delete a comment (own only).
  Future<void> deleteComment(String commentId) async {
    if (_client == null) throw Exception('Not connected');
    
    await _client
        .from('post_comments')
        .delete()
        .eq('id', commentId);
  }
  
  // ============ REPORTS ============
  
  /// Report a post.
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    await _client.from('content_reports').insert({
      'reporter_id': userId,
      'post_id': postId,
      'reason': reason,
      'details': details,
    });
  }
  
  /// Report a comment.
  Future<void> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    await _client.from('content_reports').insert({
      'reporter_id': userId,
      'comment_id': commentId,
      'reason': reason,
      'details': details,
    });
  }
  
  /// Report a swap shop listing.
  Future<void> reportSwapShopListing({
    required String listingId,
    required String reason,
    String? details,
  }) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    await _client.from('content_reports').insert({
      'reporter_id': userId,
      'swap_shop_listing_id': listingId,
      'reason': reason,
      'details': details,
    });
  }
}

/// Comment model.
class Comment {
  Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.userId,
    this.username,
    this.displayName,
    this.avatarPath,
  });
  
  final String id;
  final String body;
  final DateTime createdAt;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  String get authorName => getSafeDisplayName(
    displayName: displayName,
    username: username,
    defaultName: 'Hunter',
  );
  
  factory Comment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return Comment(
      id: json['id'],
      body: json['body'],
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
      username: profile?['username'],
      displayName: profile?['display_name'],
      avatarPath: profile?['avatar_path'],
    );
  }
}

/// Provider for social service.
final socialServiceProvider = Provider<SocialService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SocialService(client);
});

/// Provider for checking if user has liked a post.
final hasLikedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final service = ref.watch(socialServiceProvider);
  return service.hasLiked(postId);
});

/// Provider for comments on a post.
final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, postId) async {
  final service = ref.watch(socialServiceProvider);
  return service.fetchComments(postId);
});

/// Report reason options.
enum ReportReason {
  spam('spam', 'Spam or scam'),
  harassment('harassment', 'Harassment or bullying'),
  inappropriate('inappropriate', 'Inappropriate content'),
  misinformation('misinformation', 'False information'),
  other('other', 'Other');
  
  const ReportReason(this.value, this.label);
  final String value;
  final String label;
}

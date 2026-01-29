import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Service for admin moderation features (reports, actions).
class ModerationService {
  ModerationService(this._client);
  
  final SupabaseClient? _client;
  
  // ============ REPORTS ============
  
  /// Fetch all content reports with reporter and target info.
  /// Only admins can access this.
  Future<List<ContentReport>> fetchReports({
    String? statusFilter, // 'pending', 'reviewed', 'resolved', 'dismissed', null = all
    int limit = 50,
  }) async {
    if (_client == null) return [];
    
    var query = _client
        .from('content_reports')
        .select('''
          id,
          reporter_id,
          post_id,
          comment_id,
          reason,
          details,
          created_at,
          reviewed_at,
          reviewed_by,
          resolution,
          reporter:reporter_id (
            id,
            username,
            display_name
          ),
          post:post_id (
            id,
            story,
            cover_photo_path,
            user_id,
            owner:user_id (
              id,
              username,
              display_name
            )
          ),
          comment:comment_id (
            id,
            body,
            user_id,
            owner:user_id (
              id,
              username,
              display_name
            )
          )
        ''')
        .order('created_at', ascending: false)
        .limit(limit);
    
    // Filter by status if provided
    if (statusFilter != null) {
      if (statusFilter == 'pending') {
        query = query.isFilter('reviewed_at', null);
      } else {
        query = query.not('reviewed_at', 'is', null);
      }
    }
    
    final response = await query;
    
    return (response as List)
        .map((row) => ContentReport.fromJson(row))
        .toList();
  }
  
  /// Mark a report as reviewed with a resolution.
  Future<void> resolveReport({
    required String reportId,
    required String resolution, // 'no_action', 'warning', 'removed', 'dismissed'
  }) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    await _client
        .from('content_reports')
        .update({
          'reviewed_at': DateTime.now().toIso8601String(),
          'reviewed_by': userId,
          'resolution': resolution,
        })
        .eq('id', reportId);
  }
  
  /// Get count of pending reports.
  Future<int> getPendingReportCount() async {
    if (_client == null) return 0;
    
    final response = await _client
        .from('content_reports')
        .select('id')
        .isFilter('reviewed_at', null);
    
    return (response as List).length;
  }
  
  // ============ MODERATION ACTIONS LOG ============
  
  /// Fetch moderation actions (admin deletions, etc.).
  Future<List<ModerationAction>> fetchModerationActions({int limit = 50}) async {
    if (_client == null) return [];
    
    final response = await _client
        .from('moderation_actions')
        .select('''
          id,
          admin_id,
          target_type,
          target_id,
          target_owner_id,
          action,
          reason,
          created_at,
          admin:admin_id (
            id,
            username,
            display_name
          )
        ''')
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List)
        .map((row) => ModerationAction.fromJson(row))
        .toList();
  }
}

/// Content report model.
class ContentReport {
  ContentReport({
    required this.id,
    required this.reporterId,
    this.postId,
    this.commentId,
    required this.reason,
    this.details,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolution,
    this.reporterName,
    this.postStory,
    this.postCoverPhotoPath,
    this.postOwnerId,
    this.postOwnerName,
    this.commentBody,
    this.commentOwnerId,
    this.commentOwnerName,
  });
  
  final String id;
  final String reporterId;
  final String? postId;
  final String? commentId;
  final String reason;
  final String? details;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? resolution;
  final String? reporterName;
  final String? postStory;
  final String? postCoverPhotoPath;
  final String? postOwnerId;
  final String? postOwnerName;
  final String? commentBody;
  final String? commentOwnerId;
  final String? commentOwnerName;
  
  bool get isPending => reviewedAt == null;
  bool get isPostReport => postId != null;
  bool get isCommentReport => commentId != null;
  
  String get targetType => isPostReport ? 'Post' : 'Comment';
  String get targetPreview {
    if (isPostReport) {
      return postStory?.substring(0, postStory!.length > 100 ? 100 : postStory!.length) ?? 'No story';
    } else if (isCommentReport) {
      return commentBody?.substring(0, commentBody!.length > 100 ? 100 : commentBody!.length) ?? 'No body';
    }
    return 'Unknown';
  }
  
  String get reasonLabel {
    switch (reason) {
      case 'spam': return 'Spam or scam';
      case 'harassment': return 'Harassment';
      case 'inappropriate': return 'Inappropriate';
      case 'misinformation': return 'Misinformation';
      case 'other': return 'Other';
      default: return reason;
    }
  }
  
  factory ContentReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>?;
    final post = json['post'] as Map<String, dynamic>?;
    final postOwner = post?['owner'] as Map<String, dynamic>?;
    final comment = json['comment'] as Map<String, dynamic>?;
    final commentOwner = comment?['owner'] as Map<String, dynamic>?;
    
    return ContentReport(
      id: json['id'],
      reporterId: json['reporter_id'],
      postId: json['post_id'],
      commentId: json['comment_id'],
      reason: json['reason'],
      details: json['details'],
      createdAt: DateTime.parse(json['created_at']),
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
      reviewedBy: json['reviewed_by'],
      resolution: json['resolution'],
      reporterName: reporter?['display_name'] ?? reporter?['username'],
      postStory: post?['story'],
      postCoverPhotoPath: post?['cover_photo_path'],
      postOwnerId: post?['user_id'],
      postOwnerName: postOwner?['display_name'] ?? postOwner?['username'],
      commentBody: comment?['body'],
      commentOwnerId: comment?['user_id'],
      commentOwnerName: commentOwner?['display_name'] ?? commentOwner?['username'],
    );
  }
}

/// Moderation action model.
class ModerationAction {
  ModerationAction({
    required this.id,
    required this.adminId,
    required this.targetType,
    required this.targetId,
    this.targetOwnerId,
    required this.action,
    this.reason,
    required this.createdAt,
    this.adminName,
  });
  
  final String id;
  final String adminId;
  final String targetType;
  final String targetId;
  final String? targetOwnerId;
  final String action;
  final String? reason;
  final DateTime createdAt;
  final String? adminName;
  
  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;
    
    return ModerationAction(
      id: json['id'],
      adminId: json['admin_id'],
      targetType: json['target_type'],
      targetId: json['target_id'],
      targetOwnerId: json['target_owner_id'],
      action: json['action'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
      adminName: admin?['display_name'] ?? admin?['username'],
    );
  }
}

/// Provider for moderation service.
final moderationServiceProvider = Provider<ModerationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ModerationService(client);
});

/// Provider for pending report count.
final pendingReportCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(moderationServiceProvider);
  return service.getPendingReportCount();
});

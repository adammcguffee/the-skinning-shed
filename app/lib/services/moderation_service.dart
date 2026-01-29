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
    String? statusFilter, // 'pending', 'resolved', null = all
    int limit = 50,
  }) async {
    if (_client == null) return [];
    
    final selectQuery = '''
          id,
          reporter_id,
          post_id,
          comment_id,
          swap_shop_listing_id,
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
          ),
          swap_shop_listing:swap_shop_listing_id (
            id,
            title,
            description,
            user_id,
            owner:user_id (
              id,
              username,
              display_name
            )
          )
        ''';
    
    List<dynamic> response;
    
    // Filter by status if provided
    if (statusFilter == 'pending') {
      response = await _client
          .from('content_reports')
          .select(selectQuery)
          .isFilter('reviewed_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
    } else if (statusFilter == 'resolved') {
      response = await _client
          .from('content_reports')
          .select(selectQuery)
          .neq('reviewed_at', '')
          .order('created_at', ascending: false)
          .limit(limit);
    } else {
      response = await _client
          .from('content_reports')
          .select(selectQuery)
          .order('created_at', ascending: false)
          .limit(limit);
    }
    
    // For resolved filter, we fetch all and filter in Dart since neq doesn't handle null well
    if (statusFilter == 'resolved') {
      response = response.where((r) => r['reviewed_at'] != null).toList();
    }
    
    return response
        .map((row) => ContentReport.fromJson(row as Map<String, dynamic>))
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
    this.swapShopListingId,
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
    this.swapShopTitle,
    this.swapShopDescription,
    this.swapShopOwnerId,
    this.swapShopOwnerName,
  });
  
  final String id;
  final String reporterId;
  final String? postId;
  final String? commentId;
  final String? swapShopListingId;
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
  final String? swapShopTitle;
  final String? swapShopDescription;
  final String? swapShopOwnerId;
  final String? swapShopOwnerName;
  
  bool get isPending => reviewedAt == null;
  bool get isPostReport => postId != null;
  bool get isCommentReport => commentId != null;
  bool get isSwapShopReport => swapShopListingId != null;
  
  String get targetType {
    if (isPostReport) return 'Trophy Post';
    if (isSwapShopReport) return 'Swap Shop';
    if (isCommentReport) return 'Comment';
    return 'Unknown';
  }
  
  String get targetPreview {
    if (isPostReport) {
      return postStory?.substring(0, postStory!.length > 100 ? 100 : postStory!.length) ?? 'No story';
    } else if (isSwapShopReport) {
      return swapShopTitle ?? swapShopDescription?.substring(0, swapShopDescription!.length > 100 ? 100 : swapShopDescription!.length) ?? 'No title';
    } else if (isCommentReport) {
      return commentBody?.substring(0, commentBody!.length > 100 ? 100 : commentBody!.length) ?? 'No body';
    }
    return 'Unknown';
  }
  
  String? get targetOwnerId {
    if (isPostReport) return postOwnerId;
    if (isSwapShopReport) return swapShopOwnerId;
    if (isCommentReport) return commentOwnerId;
    return null;
  }
  
  String? get targetOwnerName {
    if (isPostReport) return postOwnerName;
    if (isSwapShopReport) return swapShopOwnerName;
    if (isCommentReport) return commentOwnerName;
    return null;
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
    final swapShop = json['swap_shop_listing'] as Map<String, dynamic>?;
    final swapShopOwner = swapShop?['owner'] as Map<String, dynamic>?;
    
    return ContentReport(
      id: json['id'],
      reporterId: json['reporter_id'],
      postId: json['post_id'],
      commentId: json['comment_id'],
      swapShopListingId: json['swap_shop_listing_id'],
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
      swapShopTitle: swapShop?['title'],
      swapShopDescription: swapShop?['description'],
      swapShopOwnerId: swapShop?['user_id'],
      swapShopOwnerName: swapShopOwner?['display_name'] ?? swapShopOwner?['username'],
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

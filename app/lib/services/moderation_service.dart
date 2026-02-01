import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/privacy_utils.dart';
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
    
    // PostgREST relationship hints: 
    // - reporter uses FK content_reports_reporter_id_profiles_fkey -> profiles
    // - trophy_posts uses FK content_reports_post_id_fkey -> trophy_posts
    // - post_comments uses FK content_reports_comment_id_fkey -> post_comments
    // - swap_shop_listings uses FK content_reports_swap_shop_listing_id_fkey
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
          reporter:profiles!content_reports_reporter_id_profiles_fkey (
            id,
            username,
            display_name
          ),
          trophy_posts!content_reports_post_id_fkey (
            id,
            story,
            cover_photo_path,
            user_id,
            profiles!trophy_posts_user_id_fkey (
              id,
              username,
              display_name
            )
          ),
          post_comments!content_reports_comment_id_fkey (
            id,
            body,
            user_id,
            profiles!post_comments_user_id_fkey (
              id,
              username,
              display_name
            )
          ),
          swap_shop_listings!content_reports_swap_shop_listing_id_fkey (
            id,
            title,
            description,
            user_id
          )
        ''';
    
    try {
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
        // Fetch all and filter in Dart since neq doesn't handle null well for timestamps
        response = await _client
            .from('content_reports')
            .select(selectQuery)
            .not('reviewed_at', 'is', null)
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        response = await _client
            .from('content_reports')
            .select(selectQuery)
            .order('created_at', ascending: false)
            .limit(limit);
      }
      
      return response
          .map((row) => ContentReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] PostgrestException fetching reports:');
        debugPrint('  code: ${e.code}');
        debugPrint('  message: ${e.message}');
        debugPrint('  details: ${e.details}');
        debugPrint('  hint: ${e.hint}');
      }
      rethrow;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Error fetching reports: $e');
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }
  
  /// Mark a report as reviewed with a resolution.
  Future<void> resolveReport({
    required String reportId,
    required String resolution, // 'no_action', 'warning', 'removed', 'dismissed'
  }) async {
    if (_client == null) throw Exception('Not connected');
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    try {
      await _client
          .from('content_reports')
          .update({
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': userId,
            'resolution': resolution,
          })
          .eq('id', reportId);
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] PostgrestException resolving report:');
        debugPrint('  code: ${e.code}');
        debugPrint('  message: ${e.message}');
        debugPrint('  details: ${e.details}');
        debugPrint('  hint: ${e.hint}');
      }
      rethrow;
    }
  }
  
  /// Get count of pending reports.
  Future<int> getPendingReportCount() async {
    if (_client == null) return 0;
    
    try {
      final response = await _client
          .from('content_reports')
          .select('id')
          .isFilter('reviewed_at', null);
      
      return (response as List).length;
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] PostgrestException getting report count:');
        debugPrint('  code: ${e.code}');
        debugPrint('  message: ${e.message}');
      }
      return 0;
    }
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
    // Handle relationship names from PostgREST query
    final reporter = json['reporter'] as Map<String, dynamic>?;
    
    // trophy_posts relationship (was 'post')
    final post = json['trophy_posts'] as Map<String, dynamic>?;
    final postOwner = post?['profiles'] as Map<String, dynamic>?;
    
    // post_comments relationship (was 'comment')
    final comment = json['post_comments'] as Map<String, dynamic>?;
    final commentOwner = comment?['profiles'] as Map<String, dynamic>?;
    
    // swap_shop_listings relationship
    final swapShop = json['swap_shop_listings'] as Map<String, dynamic>?;
    
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
      reporterName: getSafeDisplayName(
        displayName: reporter?['display_name'] as String?,
        username: reporter?['username'] as String?,
      ),
      postStory: post?['story'],
      postCoverPhotoPath: post?['cover_photo_path'],
      postOwnerId: post?['user_id'],
      postOwnerName: getSafeDisplayName(
        displayName: postOwner?['display_name'] as String?,
        username: postOwner?['username'] as String?,
      ),
      commentBody: comment?['body'],
      commentOwnerId: comment?['user_id'],
      commentOwnerName: getSafeDisplayName(
        displayName: commentOwner?['display_name'] as String?,
        username: commentOwner?['username'] as String?,
      ),
      swapShopTitle: swapShop?['title'],
      swapShopDescription: swapShop?['description'],
      swapShopOwnerId: swapShop?['user_id'],
      swapShopOwnerName: null, // Swap shop owner fetched separately if needed
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
      adminName: getSafeDisplayName(
        displayName: admin?['display_name'] as String?,
        username: admin?['username'] as String?,
        defaultName: 'Admin',
      ),
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

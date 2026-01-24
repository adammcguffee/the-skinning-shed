import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User profile summary for follower/following lists.
class UserSummary {
  UserSummary({
    required this.id,
    this.username,
    this.displayName,
    this.avatarPath,
    this.isFollowing = false,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  bool isFollowing;

  factory UserSummary.fromJson(Map<String, dynamic> json, {bool isFollowing = false}) {
    return UserSummary(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      isFollowing: isFollowing,
    );
  }

  String get name => displayName ?? username ?? 'User';
}

/// Follow counts for a user profile.
class FollowCounts {
  FollowCounts({
    required this.followers,
    required this.following,
  });

  final int followers;
  final int following;
}

/// Service for managing follow relationships.
class FollowService {
  FollowService(this._supabaseService);

  final SupabaseService _supabaseService;

  SupabaseClient get _client {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Supabase not initialized');
    return client;
  }

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Check if current user is following the target user.
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return response != null;
  }

  /// Follow a user.
  Future<void> follow(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    await _client.from('follows').insert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
  }

  /// Unfollow a user.
  Future<void> unfollow(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
  }

  /// Toggle follow status.
  Future<bool> toggleFollow(String targetUserId) async {
    final isCurrentlyFollowing = await isFollowing(targetUserId);

    if (isCurrentlyFollowing) {
      await unfollow(targetUserId);
      return false;
    } else {
      await follow(targetUserId);
      return true;
    }
  }

  /// Get follow counts for a user.
  Future<FollowCounts> getFollowCounts(String userId) async {
    // Count followers (people following this user)
    final followersResponse = await _client
        .from('follows')
        .select()
        .eq('following_id', userId)
        .count(CountOption.exact);

    // Count following (people this user follows)
    final followingResponse = await _client
        .from('follows')
        .select()
        .eq('follower_id', userId)
        .count(CountOption.exact);

    return FollowCounts(
      followers: followersResponse.count,
      following: followingResponse.count,
    );
  }

  /// Get list of followers for a user.
  Future<List<UserSummary>> getFollowers(String userId) async {
    final currentUserId = _currentUserId;

    // Get followers with their profile info
    final response = await _client
        .from('follows')
        .select('''
          follower_id,
          profiles!follows_follower_id_fkey(id, username, display_name, avatar_path)
        ''')
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    // If we have a current user, check which ones we're following
    final Set<String> followingIds = {};
    if (currentUserId != null) {
      final myFollowing = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      for (final row in myFollowing) {
        followingIds.add(row['following_id'] as String);
      }
    }

    return (response as List<dynamic>).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>;
      final followerId = row['follower_id'] as String;
      return UserSummary.fromJson(
        profile,
        isFollowing: followingIds.contains(followerId),
      );
    }).toList();
  }

  /// Get list of users that a user is following.
  Future<List<UserSummary>> getFollowing(String userId) async {
    final currentUserId = _currentUserId;

    // Get following with their profile info
    final response = await _client
        .from('follows')
        .select('''
          following_id,
          profiles!follows_following_id_fkey(id, username, display_name, avatar_path)
        ''')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    // If we have a current user, check which ones we're following
    final Set<String> followingIds = {};
    if (currentUserId != null) {
      final myFollowing = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      for (final row in myFollowing) {
        followingIds.add(row['following_id'] as String);
      }
    }

    return (response as List<dynamic>).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>;
      final followingId = row['following_id'] as String;
      return UserSummary.fromJson(
        profile,
        isFollowing: followingIds.contains(followingId),
      );
    }).toList();
  }

  /// Get avatar URL.
  String? getAvatarUrl(String? path) {
    if (path == null) return null;
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}

/// Provider for follow service.
final followServiceProvider = Provider<FollowService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return FollowService(supabaseService);
});

/// State for a follow relationship.
class FollowState {
  FollowState({
    this.isFollowing = false,
    this.isLoading = false,
    this.counts,
  });

  final bool isFollowing;
  final bool isLoading;
  final FollowCounts? counts;

  FollowState copyWith({
    bool? isFollowing,
    bool? isLoading,
    FollowCounts? counts,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isLoading: isLoading ?? this.isLoading,
      counts: counts ?? this.counts,
    );
  }
}

/// Notifier for follow state of a specific user.
class FollowStateNotifier extends StateNotifier<FollowState> {
  FollowStateNotifier(this._service, this.targetUserId) : super(FollowState()) {
    _loadInitialState();
  }

  final FollowService _service;
  final String targetUserId;

  Future<void> _loadInitialState() async {
    state = state.copyWith(isLoading: true);

    try {
      final isFollowing = await _service.isFollowing(targetUserId);
      final counts = await _service.getFollowCounts(targetUserId);
      state = state.copyWith(
        isFollowing: isFollowing,
        counts: counts,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FollowStateNotifier] Error: $e');
      }
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleFollow() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final newFollowState = await _service.toggleFollow(targetUserId);
      final counts = await _service.getFollowCounts(targetUserId);
      state = state.copyWith(
        isFollowing: newFollowState,
        counts: counts,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FollowStateNotifier] Toggle error: $e');
      }
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await _loadInitialState();
  }
}

/// Family provider for follow state per user.
final followStateNotifierProvider =
    StateNotifierProvider.family<FollowStateNotifier, FollowState, String>(
  (ref, targetUserId) {
    final service = ref.watch(followServiceProvider);
    return FollowStateNotifier(service, targetUserId);
  },
);

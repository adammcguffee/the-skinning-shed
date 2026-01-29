import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// User profile for discover/search results.
class DiscoverUser {
  DiscoverUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarPath,
    this.bio,
    this.defaultState,
    required this.followersCount,
    required this.followingCount,
    this.postCount,
    required this.isFollowing,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  final String? bio;
  final String? defaultState;
  final int followersCount;
  final int followingCount;
  final int? postCount;
  bool isFollowing;

  String get name => displayName ?? username ?? 'User';
  String get handle => username != null ? '@$username' : '';

  factory DiscoverUser.fromJson(Map<String, dynamic> json) {
    return DiscoverUser(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      bio: json['bio'] as String?,
      defaultState: json['default_state'] as String?,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      postCount: (json['post_count'] as num?)?.toInt(),
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }
}

/// Trending post data.
class TrendingPost {
  TrendingPost({
    required this.id,
    required this.userId,
    this.category,
    this.customSpeciesName,
    this.state,
    this.county,
    this.harvestDate,
    this.story,
    this.coverPhotoPath,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    this.speciesName,
    this.userDisplayName,
    this.userUsername,
    this.userAvatarPath,
  });

  final String id;
  final String userId;
  final String? category;
  final String? customSpeciesName;
  final String? state;
  final String? county;
  final String? harvestDate;
  final String? story;
  final String? coverPhotoPath;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final String? speciesName;
  final String? userDisplayName;
  final String? userUsername;
  final String? userAvatarPath;

  String get species => speciesName ?? customSpeciesName ?? 'Trophy';
  String get userName => userDisplayName ?? userUsername ?? 'Hunter';
  String get userHandle => userUsername != null ? '@$userUsername' : '';
  String get location {
    final parts = [county, state].where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }
  
  String get title {
    if (story != null && story!.isNotEmpty) {
      return story!.length > 60 ? '${story!.substring(0, 60)}...' : story!;
    }
    return species;
  }

  factory TrendingPost.fromJson(Map<String, dynamic> json) {
    return TrendingPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String?,
      customSpeciesName: json['custom_species_name'] as String?,
      state: json['state'] as String?,
      county: json['county'] as String?,
      harvestDate: json['harvest_date'] as String?,
      story: json['story'] as String?,
      coverPhotoPath: json['cover_photo_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      speciesName: json['species_name'] as String?,
      userDisplayName: json['user_display_name'] as String?,
      userUsername: json['user_username'] as String?,
      userAvatarPath: json['user_avatar_path'] as String?,
    );
  }
}

/// Service for discovering users and trending content.
class DiscoverService {
  DiscoverService(this._client);

  final SupabaseClient? _client;

  String? get _currentUserId => _client?.auth.currentUser?.id;

  /// Search users by name or username.
  Future<List<DiscoverUser>> searchUsers(String query, {int limit = 20}) async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc(
        'search_users',
        params: {
          'search_query': query,
          'current_user_id': _currentUserId,
          'limit_count': limit,
        },
      );

      return (response as List<dynamic>)
          .map((json) => DiscoverUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DiscoverService] searchUsers error: $e');
      }
      return [];
    }
  }

  /// Get suggested users (most active/followed).
  Future<List<DiscoverUser>> getSuggestedUsers({int limit = 10}) async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc(
        'get_suggested_users',
        params: {
          'current_user_id': _currentUserId,
          'limit_count': limit,
        },
      );

      return (response as List<dynamic>)
          .map((json) => DiscoverUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DiscoverService] getSuggestedUsers error: $e');
      }
      return [];
    }
  }

  /// Get trending posts from last N days.
  Future<List<TrendingPost>> getTrendingPosts({
    int daysBack = 7,
    int limit = 20,
  }) async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc(
        'get_trending_posts',
        params: {
          'days_back': daysBack,
          'limit_count': limit,
        },
      );

      return (response as List<dynamic>)
          .map((json) => TrendingPost.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DiscoverService] getTrendingPosts error: $e');
      }
      return [];
    }
  }

  /// Get public URL for avatar.
  String? getAvatarUrl(String? path) {
    if (_client == null || path == null) return null;
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  /// Get public URL for trophy photo.
  String? getPhotoUrl(String? path) {
    if (_client == null || path == null) return null;
    return _client.storage.from('trophy_photos').getPublicUrl(path);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for discover service.
final discoverServiceProvider = Provider<DiscoverService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DiscoverService(client);
});

/// Provider for suggested users.
final suggestedUsersProvider = FutureProvider<List<DiscoverUser>>((ref) async {
  final service = ref.watch(discoverServiceProvider);
  return service.getSuggestedUsers(limit: 15);
});

/// Provider for searching users (family).
final searchUsersProvider =
    FutureProvider.family<List<DiscoverUser>, String>((ref, query) async {
  final service = ref.watch(discoverServiceProvider);
  if (query.isEmpty) {
    return service.getSuggestedUsers(limit: 15);
  }
  return service.searchUsers(query);
});

/// Provider for trending posts.
final trendingPostsProvider = FutureProvider<List<TrendingPost>>((ref) async {
  final service = ref.watch(discoverServiceProvider);
  return service.getTrendingPosts(daysBack: 7, limit: 10);
});

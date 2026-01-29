import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Club model
class Club {
  const Club({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.description,
    required this.isDiscoverable,
    required this.requireApproval,
    this.logoPath,
    this.bannerPath,
    required this.settings,
    required this.createdAt,
    this.memberCount,
    this.stateCode,
    this.county,
  });
  
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? description;
  final bool isDiscoverable;
  final bool requireApproval;
  final String? logoPath;
  final String? bannerPath;
  final ClubSettings settings;
  final DateTime createdAt;
  final int? memberCount;
  final String? stateCode;
  final String? county;
  
  /// Display location string (e.g., "Madison County, AL")
  String? get locationDisplay {
    if (county != null && stateCode != null) {
      return '$county, $stateCode';
    }
    return stateCode;
  }
  
  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      isDiscoverable: json['is_discoverable'] as bool? ?? false,
      requireApproval: json['require_approval'] as bool? ?? true,
      logoPath: json['logo_path'] as String?,
      bannerPath: json['banner_path'] as String?,
      settings: ClubSettings.fromJson(json['settings'] as Map<String, dynamic>? ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: json['member_count'] as int?,
      stateCode: json['state_code'] as String?,
      county: json['county'] as String?,
    );
  }
}

/// Club settings
class ClubSettings {
  const ClubSettings({
    this.signInTtlHours = 6,
    this.allowMultiSigninPerStand = false,
    this.allowMembersCreateStands = false,
  });
  
  final int signInTtlHours;
  final bool allowMultiSigninPerStand;
  final bool allowMembersCreateStands;
  
  factory ClubSettings.fromJson(Map<String, dynamic> json) {
    return ClubSettings(
      signInTtlHours: json['sign_in_ttl_hours'] as int? ?? 6,
      allowMultiSigninPerStand: json['allow_multi_signin_per_stand'] as bool? ?? false,
      allowMembersCreateStands: json['allow_members_create_stands'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'sign_in_ttl_hours': signInTtlHours,
    'allow_multi_signin_per_stand': allowMultiSigninPerStand,
    'allow_members_create_stands': allowMembersCreateStands,
  };
}

/// Club member model
class ClubMember {
  const ClubMember({
    required this.clubId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.username,
    this.displayName,
    this.avatarPath,
  });
  
  final String clubId;
  final String userId;
  final String role;
  final String status;
  final DateTime joinedAt;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  String get name => displayName ?? username ?? 'Unknown';
  String get handle => username != null ? '@$username' : '';
  
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get isActive => status == 'active';
  
  factory ClubMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubMember(
      clubId: json['club_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      avatarPath: profile?['avatar_path'] as String?,
    );
  }
}

/// Join request model
class ClubJoinRequest {
  const ClubJoinRequest({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.username,
    this.displayName,
    this.avatarPath,
  });
  
  final String id;
  final String clubId;
  final String userId;
  final String status;
  final DateTime createdAt;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  String get name => displayName ?? username ?? 'Unknown';
  
  factory ClubJoinRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubJoinRequest(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      avatarPath: profile?['avatar_path'] as String?,
    );
  }
}

/// Club post model
class ClubPost {
  const ClubPost({
    required this.id,
    required this.clubId,
    this.authorId,
    required this.content,
    this.photoPath,
    required this.pinned,
    required this.createdAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarPath,
  });
  
  final String id;
  final String clubId;
  final String? authorId;
  final String content;
  final String? photoPath;
  final bool pinned;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarPath;
  
  String get authorName => authorDisplayName ?? authorUsername ?? 'Unknown';
  
  factory ClubPost.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubPost(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      authorId: json['author_id'] as String?,
      content: json['content'] as String,
      photoPath: json['photo_path'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorUsername: profile?['username'] as String?,
      authorDisplayName: profile?['display_name'] as String?,
      authorAvatarPath: profile?['avatar_path'] as String?,
    );
  }
}

/// Invite info model (for join page)
class InviteInfo {
  const InviteInfo({
    required this.valid,
    this.error,
    this.clubId,
    this.clubName,
    this.clubDescription,
  });
  
  final bool valid;
  final String? error;
  final String? clubId;
  final String? clubName;
  final String? clubDescription;
  
  factory InviteInfo.fromJson(Map<String, dynamic> json) {
    return InviteInfo(
      valid: json['valid'] as bool? ?? false,
      error: json['error'] as String?,
      clubId: json['club_id'] as String?,
      clubName: json['club_name'] as String?,
      clubDescription: json['club_description'] as String?,
    );
  }
}

/// Clubs service
class ClubsService {
  ClubsService(this._client);
  
  final SupabaseClient? _client;
  
  /// Get clubs where current user is an active member
  Future<List<Club>> getMyClubs() async {
    if (_client == null) return [];
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    
    try {
      final response = await _client
          .from('club_members')
          .select('club_id, clubs(*)')
          .eq('user_id', userId)
          .eq('status', 'active');
      
      return (response as List)
          .map((row) => Club.fromJson(row['clubs'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting my clubs: $e');
      }
      return [];
    }
  }
  
  /// Get discoverable clubs (for discovery page)
  Future<List<Club>> getDiscoverableClubs() async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('clubs')
          .select()
          .eq('is_discoverable', true)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((row) => Club.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting discoverable clubs: $e');
      }
      return [];
    }
  }
  
  /// Search discoverable clubs with optional filters
  Future<List<Club>> searchClubs({
    String? query,
    String? stateCode,
    String? county,
  }) async {
    if (_client == null) return [];
    
    try {
      var request = _client
          .from('clubs')
          .select()
          .eq('is_discoverable', true);
      
      // Filter by state if provided
      if (stateCode != null && stateCode.isNotEmpty) {
        request = request.eq('state_code', stateCode);
      }
      
      // Filter by county if provided
      if (county != null && county.isNotEmpty) {
        request = request.eq('county', county);
      }
      
      // Search by name if query provided
      if (query != null && query.isNotEmpty) {
        request = request.ilike('name', '%$query%');
      }
      
      final response = await request.order('name');
      
      return (response as List)
          .map((row) => Club.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error searching clubs: $e');
      }
      return [];
    }
  }
  
  /// Get list of states that have discoverable clubs
  Future<List<String>> getClubStates() async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('clubs')
          .select('state_code')
          .eq('is_discoverable', true)
          .not('state_code', 'is', null);
      
      final states = (response as List)
          .map((row) => row['state_code'] as String)
          .toSet()
          .toList();
      states.sort();
      return states;
    } catch (e) {
      return [];
    }
  }
  
  /// Get list of counties for a state that have discoverable clubs
  Future<List<String>> getClubCounties(String stateCode) async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('clubs')
          .select('county')
          .eq('is_discoverable', true)
          .eq('state_code', stateCode)
          .not('county', 'is', null);
      
      final counties = (response as List)
          .map((row) => row['county'] as String)
          .toSet()
          .toList();
      counties.sort();
      return counties;
    } catch (e) {
      return [];
    }
  }
  
  /// Get club by ID
  Future<Club?> getClub(String clubId) async {
    if (_client == null) return null;
    
    try {
      final response = await _client
          .from('clubs')
          .select()
          .eq('id', clubId)
          .maybeSingle();
      
      if (response != null) {
        return Club.fromJson(response);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting club: $e');
      }
      return null;
    }
  }
  
  /// Create a new club
  Future<String?> createClub({
    required String name,
    String? description,
    bool isDiscoverable = false,
    bool requireApproval = true,
    ClubSettings? settings,
    String? stateCode,
    String? county,
  }) async {
    if (_client == null) return null;
    
    try {
      // Generate slug from name
      final slug = _generateSlug(name);
      
      final result = await _client.rpc('create_club', params: {
        'p_name': name,
        'p_slug': slug,
        'p_description': description,
        'p_is_discoverable': isDiscoverable,
        'p_require_approval': requireApproval,
        'p_settings': (settings ?? const ClubSettings()).toJson(),
      });
      
      final clubId = result as String?;
      
      // Update with location if provided
      if (clubId != null && (stateCode != null || county != null)) {
        await _client.from('clubs').update({
          if (stateCode != null) 'state_code': stateCode,
          if (county != null) 'county': county,
        }).eq('id', clubId);
      }
      
      return clubId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error creating club: $e');
      }
      return null;
    }
  }
  
  /// Generate slug from name
  String _generateSlug(String name) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    // Add random suffix to avoid conflicts
    final suffix = Random().nextInt(9999).toString().padLeft(4, '0');
    return '$base-$suffix';
  }
  
  /// Update club
  Future<bool> updateClub(String clubId, {
    String? name,
    String? description,
    bool? isDiscoverable,
    bool? requireApproval,
    ClubSettings? settings,
    String? stateCode,
    String? county,
  }) async {
    if (_client == null) return false;
    
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (isDiscoverable != null) data['is_discoverable'] = isDiscoverable;
      if (requireApproval != null) data['require_approval'] = requireApproval;
      if (settings != null) data['settings'] = settings.toJson();
      if (stateCode != null) data['state_code'] = stateCode;
      if (county != null) data['county'] = county;
      
      await _client
          .from('clubs')
          .update(data)
          .eq('id', clubId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error updating club: $e');
      }
      return false;
    }
  }
  
  /// Check if current user is a member of a club
  Future<bool> isMember(String clubId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final response = await _client
          .from('club_members')
          .select('user_id')
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Get current user's membership in a club (only returns active memberships)
  Future<ClubMember?> getMyMembership(String clubId) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      final response = await _client
          .from('club_members')
          .select('*, profiles:profiles!club_members_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active') // Only return active memberships
          .maybeSingle();
      
      if (response != null) {
        return ClubMember.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get club members
  Future<List<ClubMember>> getMembers(String clubId) async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('club_members')
          .select('*, profiles:profiles!club_members_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .order('joined_at');
      
      return (response as List)
          .map((row) => ClubMember.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting members: $e');
      }
      return [];
    }
  }
  
  /// Request to join a discoverable club
  Future<bool> requestToJoin(String clubId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client.from('club_join_requests').insert({
        'club_id': clubId,
        'user_id': userId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error requesting to join: $e');
      }
      return false;
    }
  }
  
  /// Get pending join requests for a club (admin only)
  Future<List<ClubJoinRequest>> getJoinRequests(String clubId) async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('club_join_requests')
          .select('*, profiles:profiles!club_join_requests_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('status', 'pending')
          .order('created_at');
      
      return (response as List)
          .map((row) => ClubJoinRequest.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting join requests: $e');
      }
      return [];
    }
  }
  
  /// Check if user has a pending request for a club
  Future<bool> hasPendingRequest(String clubId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final response = await _client
          .from('club_join_requests')
          .select('id')
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'pending')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Approve a join request (admin only)
  Future<bool> approveRequest(String requestId) async {
    if (_client == null) return false;
    
    try {
      final result = await _client.rpc('approve_join_request', params: {
        'p_request_id': requestId,
      });
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error approving request: $e');
      }
      return false;
    }
  }
  
  /// Reject a join request (admin only)
  Future<bool> rejectRequest(String requestId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_join_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error rejecting request: $e');
      }
      return false;
    }
  }
  
  /// Create an invite link
  Future<String?> createInviteLink(String clubId, {int maxUses = 5, int expiresInDays = 7}) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      // Generate token
      final tokenResult = await _client.rpc('generate_invite_token');
      final token = tokenResult as String;
      
      await _client.from('club_invites').insert({
        'club_id': clubId,
        'invited_by': userId,
        'invite_type': 'link',
        'token': token,
        'expires_at': DateTime.now().add(Duration(days: expiresInDays)).toIso8601String(),
        'max_uses': maxUses,
      });
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error creating invite: $e');
      }
      return null;
    }
  }
  
  /// Get invite info (for join page)
  Future<InviteInfo> getInviteInfo(String token) async {
    if (_client == null) {
      return const InviteInfo(valid: false, error: 'Not connected');
    }
    
    try {
      final result = await _client.rpc('get_invite_info', params: {
        'p_token': token,
      });
      return InviteInfo.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return InviteInfo(valid: false, error: e.toString());
    }
  }
  
  /// Accept an invite
  Future<({bool success, String? clubId, String? error})> acceptInvite(String token) async {
    if (_client == null) {
      return (success: false, clubId: null, error: 'Not connected');
    }
    
    try {
      final result = await _client.rpc('accept_club_invite', params: {
        'p_token': token,
      });
      
      final json = result as Map<String, dynamic>;
      return (
        success: json['success'] == true,
        clubId: json['club_id'] as String?,
        error: json['error'] as String?,
      );
    } catch (e) {
      return (success: false, clubId: null, error: e.toString());
    }
  }
  
  /// Update member role (admin only)
  Future<bool> updateMemberRole(String clubId, String userId, String role) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_members')
          .update({'role': role})
          .eq('club_id', clubId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error updating member role: $e');
      }
      return false;
    }
  }
  
  /// Remove member (admin only)
  Future<bool> removeMember(String clubId, String userId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_members')
          .delete()
          .eq('club_id', clubId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error removing member: $e');
      }
      return false;
    }
  }
  
  /// Leave club
  Future<bool> leaveClub(String clubId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client
          .from('club_members')
          .delete()
          .eq('club_id', clubId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error leaving club: $e');
      }
      return false;
    }
  }
  
  /// Update club settings (convenience wrapper)
  Future<bool> updateClubSettings(
    String clubId, {
    bool? isDiscoverable,
    bool? requireApproval,
    ClubSettings? settings,
  }) {
    return updateClub(
      clubId,
      isDiscoverable: isDiscoverable,
      requireApproval: requireApproval,
      settings: settings,
    );
  }
  
  /// Delete club (owner only)
  Future<bool> deleteClub(String clubId) async {
    if (_client == null) return false;
    
    try {
      // Delete club - cascades should handle members, posts, etc.
      await _client
          .from('clubs')
          .delete()
          .eq('id', clubId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error deleting club: $e');
      }
      return false;
    }
  }
  
  // =====================
  // POSTS
  // =====================
  
  /// Get club posts
  Future<List<ClubPost>> getPosts(String clubId) async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('club_posts')
          .select('*, profiles:profiles!club_posts_author_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((row) => ClubPost.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error getting posts: $e');
      }
      return [];
    }
  }
  
  /// Create a post
  Future<bool> createPost(String clubId, String content, {String? photoPath}) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      // Insert the post
      final response = await _client.from('club_posts').insert({
        'club_id': clubId,
        'author_id': userId,
        'content': content,
        'photo_path': photoPath,
      }).select('id').single();
      
      // Trigger notification (fire and forget)
      _notifyClubEvent(
        type: 'club_post',
        clubId: clubId,
        actorId: userId,
        postId: response['id'] as String,
        postPreview: content,
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error creating post: $e');
      }
      return false;
    }
  }
  
  /// Notify club members of an event (fire and forget)
  Future<void> _notifyClubEvent({
    required String type,
    required String clubId,
    required String actorId,
    String? postId,
    String? postPreview,
    String? standId,
    String? standName,
  }) async {
    if (_client == null) return;
    
    try {
      await _client.functions.invoke(
        'notify-club-event',
        body: {
          'type': type,
          'clubId': clubId,
          'actorId': actorId,
          if (postId != null) 'postId': postId,
          if (postPreview != null) 'postPreview': postPreview,
          if (standId != null) 'standId': standId,
          if (standName != null) 'standName': standName,
        },
      );
    } catch (e) {
      // Don't fail the main operation if notification fails
      if (kDebugMode) {
        debugPrint('[ClubsService] Notification error (non-fatal): $e');
      }
    }
  }
  
  /// Update a post
  Future<bool> updatePost(String postId, String content) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_posts')
          .update({'content': content})
          .eq('id', postId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error updating post: $e');
      }
      return false;
    }
  }
  
  /// Delete a post
  Future<bool> deletePost(String postId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_posts')
          .delete()
          .eq('id', postId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error deleting post: $e');
      }
      return false;
    }
  }
  
  /// Toggle pin on a post (admin only)
  Future<bool> togglePinPost(String postId, bool pinned) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_posts')
          .update({'pinned': pinned})
          .eq('id', postId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClubsService] Error pinning post: $e');
      }
      return false;
    }
  }
}

// =====================
// PROVIDERS
// =====================

final clubsServiceProvider = Provider<ClubsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ClubsService(client);
});

final myClubsProvider = FutureProvider<List<Club>>((ref) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getMyClubs();
});

final discoverableClubsProvider = FutureProvider<List<Club>>((ref) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getDiscoverableClubs();
});

final clubProvider = FutureProvider.family<Club?, String>((ref, clubId) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getClub(clubId);
});

final clubMembersProvider = FutureProvider.family<List<ClubMember>, String>((ref, clubId) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getMembers(clubId);
});

final clubPostsProvider = FutureProvider.family<List<ClubPost>, String>((ref, clubId) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getPosts(clubId);
});

final clubJoinRequestsProvider = FutureProvider.family<List<ClubJoinRequest>, String>((ref, clubId) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getJoinRequests(clubId);
});

final myClubMembershipProvider = FutureProvider.family<ClubMember?, String>((ref, clubId) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getMyMembership(clubId);
});

final inviteInfoProvider = FutureProvider.family<InviteInfo, String>((ref, token) async {
  final service = ref.watch(clubsServiceProvider);
  return service.getInviteInfo(token);
});

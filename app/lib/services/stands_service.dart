import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Stand model
class ClubStand {
  const ClubStand({
    required this.id,
    required this.clubId,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.createdAt,
    this.activeSignin,
  });
  
  final String id;
  final String clubId;
  final String name;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final StandSignin? activeSignin;
  
  bool get isOccupied => activeSignin != null && activeSignin!.isActive;
  
  factory ClubStand.fromJson(Map<String, dynamic> json, {StandSignin? activeSignin}) {
    return ClubStand(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      activeSignin: activeSignin,
    );
  }
  
  ClubStand copyWith({StandSignin? activeSignin}) {
    return ClubStand(
      id: id,
      clubId: clubId,
      name: name,
      description: description,
      sortOrder: sortOrder,
      createdAt: createdAt,
      activeSignin: activeSignin ?? this.activeSignin,
    );
  }
}

/// Hunt details stored in sign-in
class HuntDetails {
  const HuntDetails({
    this.parkedAt,
    this.entryRoute,
    this.wind,
    this.weapon,
    this.extra,
  });
  
  final String? parkedAt;
  final String? entryRoute;
  final String? wind;
  final String? weapon;
  final String? extra;
  
  factory HuntDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HuntDetails();
    return HuntDetails(
      parkedAt: json['parked_at'] as String?,
      entryRoute: json['entry_route'] as String?,
      wind: json['wind'] as String?,
      weapon: json['weapon'] as String?,
      extra: json['extra'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    if (parkedAt != null && parkedAt!.isNotEmpty) 'parked_at': parkedAt,
    if (entryRoute != null && entryRoute!.isNotEmpty) 'entry_route': entryRoute,
    if (wind != null && wind!.isNotEmpty) 'wind': wind,
    if (weapon != null && weapon!.isNotEmpty) 'weapon': weapon,
    if (extra != null && extra!.isNotEmpty) 'extra': extra,
  };
  
  bool get isEmpty => parkedAt == null && entryRoute == null && wind == null && weapon == null && extra == null;
}

/// Stand sign-in model
class StandSignin {
  const StandSignin({
    required this.id,
    required this.clubId,
    required this.standId,
    required this.userId,
    required this.status,
    required this.signedInAt,
    this.signedOutAt,
    required this.expiresAt,
    this.note,
    this.details,
    this.username,
    this.displayName,
    this.avatarPath,
    this.activityPromptDismissed = false,
  });
  
  final String id;
  final String clubId;
  final String standId;
  final String userId;
  final String status;
  final DateTime signedInAt;
  final DateTime? signedOutAt;
  final DateTime expiresAt;
  final String? note;
  final HuntDetails? details;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  final bool activityPromptDismissed;
  
  String get userName => displayName ?? username ?? 'Unknown';
  String get handle => username != null ? '@$username' : '';
  
  /// Whether this sign-in is currently active (status=active and not expired)
  /// Uses UTC for comparison since DB stores timestamps in UTC
  bool get isActive => status == 'active' && expiresAt.toUtc().isAfter(DateTime.now().toUtc());
  
  /// Whether this signin is expired (past expires_at, regardless of status)
  bool get isExpired => expiresAt.toUtc().isBefore(DateTime.now().toUtc());
  
  /// How this session ended (for display purposes)
  /// Returns: 'active', 'manual', or 'auto_expired'
  String get endReason {
    if (isActive) return 'active';
    if (status == 'signed_out') return 'manual';
    // status is 'active' but expired, or status is 'expired'
    return 'auto_expired';
  }
  
  /// Human-readable end reason for display
  String get endReasonDisplay {
    switch (endReason) {
      case 'manual': return 'Signed out';
      case 'auto_expired': return 'Auto-expired';
      default: return 'Active';
    }
  }
  
  /// Formatted sign-in time (e.g., "6:12 AM") in local time
  String get signedInAtFormatted {
    final local = signedInAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }
  
  /// Time since sign-in (e.g., "12m ago")
  String get signedInAgo {
    final now = DateTime.now().toUtc();
    final diff = now.difference(signedInAt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return '${diff.inDays}d ago';
  }
  
  /// Time remaining until expiration
  Duration get timeRemaining {
    final now = DateTime.now().toUtc();
    final expUtc = expiresAt.toUtc();
    if (expUtc.isBefore(now)) return Duration.zero;
    return expUtc.difference(now);
  }
  
  /// Formatted time remaining (e.g., "2h 30m")
  String get timeRemainingFormatted {
    final remaining = timeRemaining;
    if (remaining == Duration.zero) return 'Expired';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
  
  /// Formatted expiration time (e.g., "3:42 PM") in local time
  String get expiresAtFormatted {
    final local = expiresAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }
  
  factory StandSignin.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return StandSignin(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      standId: json['stand_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      signedInAt: DateTime.parse(json['signed_in_at'] as String),
      signedOutAt: json['signed_out_at'] != null 
          ? DateTime.parse(json['signed_out_at'] as String) 
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      note: json['note'] as String?,
      details: HuntDetails.fromJson(json['details'] as Map<String, dynamic>?),
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      avatarPath: profile?['avatar_path'] as String?,
      activityPromptDismissed: json['activity_prompt_dismissed'] as bool? ?? false,
    );
  }
}

/// Stand activity entry model
class StandActivity {
  const StandActivity({
    required this.id,
    required this.clubId,
    required this.standId,
    required this.userId,
    this.signinId,
    required this.body,
    required this.createdAt,
    this.username,
    this.displayName,
    this.avatarPath,
  });
  
  final String id;
  final String clubId;
  final String standId;
  final String userId;
  final String? signinId;
  final String body;
  final DateTime createdAt;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  String get userName => displayName ?? username ?? 'User';
  String get handle => username != null ? '@$username' : '';
  
  factory StandActivity.fromJson(Map<String, dynamic> json) {
    return StandActivity(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      standId: json['stand_id'] as String,
      userId: json['user_id'] as String,
      signinId: json['signin_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
    );
  }
}

/// Pending activity prompt model
class PendingActivityPrompt {
  const PendingActivityPrompt({
    required this.signinId,
    required this.standId,
    required this.standName,
    required this.signedInAt,
    required this.expiresAt,
  });
  
  final String signinId;
  final String standId;
  final String standName;
  final DateTime signedInAt;
  final DateTime expiresAt;
  
  factory PendingActivityPrompt.fromJson(Map<String, dynamic> json) {
    return PendingActivityPrompt(
      signinId: json['signin_id'] as String,
      standId: json['stand_id'] as String,
      standName: json['stand_name'] as String,
      signedInAt: DateTime.parse(json['signed_in_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Result of a sign-in attempt
enum SignInResultType { success, standTaken, error }

class SignInResult {
  const SignInResult._(this.type, [this.error]);
  
  factory SignInResult.success() => const SignInResult._(SignInResultType.success);
  factory SignInResult.standTaken() => const SignInResult._(SignInResultType.standTaken);
  factory SignInResult.error(String message) => SignInResult._(SignInResultType.error, message);
  
  final SignInResultType type;
  final String? error;
  
  bool get isSuccess => type == SignInResultType.success;
  bool get isStandTaken => type == SignInResultType.standTaken;
  bool get isError => type == SignInResultType.error;
}

/// Stands service
class StandsService {
  StandsService(this._client);
  
  final SupabaseClient? _client;
  
  /// Get stands with active sign-ins for a club (excludes soft-deleted)
  Future<List<ClubStand>> getStandsWithSignins(String clubId) async {
    if (_client == null) return [];
    
    try {
      // Get all non-deleted stands
      final standsResponse = await _client
          .from('club_stands')
          .select()
          .eq('club_id', clubId)
          .eq('is_deleted', false)
          .order('sort_order');
      
      // Get active sign-ins (not expired) - use UTC for comparison
      final signinsResponse = await _client
          .from('stand_signins')
          .select('*, profiles:profiles!stand_signins_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      
      // Map sign-ins by stand ID
      final signInsByStand = <String, StandSignin>{};
      for (final row in signinsResponse as List) {
        final signin = StandSignin.fromJson(row as Map<String, dynamic>);
        signInsByStand[signin.standId] = signin;
      }
      
      // Combine stands with sign-ins
      return (standsResponse as List).map((row) {
        final stand = ClubStand.fromJson(row as Map<String, dynamic>);
        return stand.copyWith(activeSignin: signInsByStand[stand.id]);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error getting stands: $e');
      }
      return [];
    }
  }
  
  /// Create a new stand (admin only)
  Future<bool> createStand(String clubId, String name, {String? description}) async {
    if (_client == null) return false;
    
    try {
      // Get max sort order
      final maxOrderResult = await _client
          .from('club_stands')
          .select('sort_order')
          .eq('club_id', clubId)
          .order('sort_order', ascending: false)
          .limit(1);
      
      final maxOrder = (maxOrderResult as List).isNotEmpty 
          ? (maxOrderResult[0]['sort_order'] as int? ?? 0) + 1 
          : 0;
      
      await _client.from('club_stands').insert({
        'club_id': clubId,
        'name': name,
        'description': description,
        'sort_order': maxOrder,
      });
      
      return true;
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error creating stand: ${e.code} - ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error creating stand: $e');
      }
      return false;
    }
  }
  
  /// Update a stand
  Future<bool> updateStand(String standId, {String? name, String? description}) async {
    if (_client == null) return false;
    
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      
      await _client
          .from('club_stands')
          .update(data)
          .eq('id', standId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error updating stand: $e');
      }
      return false;
    }
  }
  
  /// Soft delete a stand (admin only - ends active signins first)
  Future<bool> deleteStand(String standId) async {
    if (_client == null) return false;
    
    try {
      final result = await _client.rpc('soft_delete_stand', params: {
        'p_stand_id': standId,
      });
      
      final json = result as Map<String, dynamic>;
      return json['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error deleting stand: $e');
      }
      return false;
    }
  }
  
  /// Update stand name/description via RPC (admin only)
  Future<bool> updateStandViaRpc(String standId, String name, {String? description}) async {
    if (_client == null) return false;
    
    try {
      final result = await _client.rpc('update_stand', params: {
        'p_stand_id': standId,
        'p_name': name,
        'p_description': description,
      });
      
      final json = result as Map<String, dynamic>;
      return json['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error updating stand: $e');
      }
      return false;
    }
  }
  
  /// Update sign-in details (note + hunt details)
  Future<bool> updateSigninDetails(String signinId, {String? note, HuntDetails? details}) async {
    if (_client == null) return false;
    
    try {
      final data = <String, dynamic>{};
      if (note != null) data['note'] = note;
      if (details != null) data['details'] = details.toJson();
      
      await _client
          .from('stand_signins')
          .update(data)
          .eq('id', signinId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error updating signin details: $e');
      }
      return false;
    }
  }
  
  /// Sign in to a stand with optional hunt details
  Future<SignInResult> signIn(
    String clubId, 
    String standId, 
    int ttlHours, {
    String? note, 
    String? standName,
    HuntDetails? details,
  }) async {
    if (_client == null) {
      return SignInResult.error('Not connected');
    }
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return SignInResult.error('Not authenticated');
    }
    
    try {
      // First sign out from any active sign-ins in this club
      final now = DateTime.now().toUtc();
      await _client
          .from('stand_signins')
          .update({
            'status': 'signed_out',
            'signed_out_at': now.toIso8601String(),
            'ended_reason': 'new_signin',
          })
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active');
      
      // Create new sign-in with UTC timestamps
      final expiresAt = now.add(Duration(hours: ttlHours));
      
      await _client.from('stand_signins').insert({
        'club_id': clubId,
        'stand_id': standId,
        'user_id': userId,
        'status': 'active',
        'expires_at': expiresAt.toIso8601String(),
        'note': note,
        if (details != null && !details.isEmpty) 'details': details.toJson(),
      });
      
      // Trigger notification (fire and forget)
      _notifyStandEvent(
        type: 'stand_signin',
        clubId: clubId,
        actorId: userId,
        standId: standId,
        standName: standName,
      );
      
      return SignInResult.success();
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Postgrest error signing in: ${e.code} - ${e.message}');
      }
      
      // Check for unique constraint violation (stand already taken)
      if (e.code == '23505') {
        return SignInResult.standTaken();
      }
      
      return SignInResult.error(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error signing in: $e');
      }
      return SignInResult.error(e.toString());
    }
  }
  
  /// Sign out from a stand
  Future<bool> signOut(String signinId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('stand_signins')
          .update({
            'status': 'signed_out',
            'signed_out_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', signinId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error signing out: $e');
      }
      return false;
    }
  }
  
  /// Sign out from any active sign-in in a club (by current user)
  Future<bool> signOutAll(String clubId) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client
          .from('stand_signins')
          .update({
            'status': 'signed_out',
            'signed_out_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active');
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error signing out all: $e');
      }
      return false;
    }
  }
  
  /// Get current user's active sign-in in a club
  Future<StandSignin?> getMyActiveSignin(String clubId) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      final response = await _client
          .from('stand_signins')
          .select('*, profiles:profiles!stand_signins_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();
      
      if (response != null) {
        return StandSignin.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Notify club members of stand event (fire and forget)
  Future<void> _notifyStandEvent({
    required String type,
    required String clubId,
    required String actorId,
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
          if (standId != null) 'standId': standId,
          if (standName != null) 'standName': standName,
        },
      );
    } catch (e) {
      // Don't fail the main operation if notification fails
      if (kDebugMode) {
        debugPrint('[StandsService] Notification error (non-fatal): $e');
      }
    }
  }
  
  // =====================
  // STAND ACTIVITY
  // =====================
  
  /// Get recent activity for a stand
  Future<List<StandActivity>> getStandActivity(String standId, {int limit = 20}) async {
    if (_client == null) return [];
    
    try {
      final result = await _client.rpc('get_stand_activity', params: {
        'p_stand_id': standId,
        'p_limit': limit,
      });
      
      return (result as List).map((row) {
        final json = row as Map<String, dynamic>;
        return StandActivity.fromJson(json);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error getting stand activity: $e');
      }
      return [];
    }
  }
  
  /// Add activity entry to a stand
  Future<bool> addStandActivity(String clubId, String standId, String body, {String? signinId}) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client.from('stand_activity').insert({
        'club_id': clubId,
        'stand_id': standId,
        'user_id': userId,
        'body': body,
        if (signinId != null) 'signin_id': signinId,
      });
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error adding stand activity: $e');
      }
      return false;
    }
  }
  
  /// Edit an activity entry
  Future<bool> editStandActivity(String activityId, String body) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('stand_activity')
          .update({
            'body': body,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', activityId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error editing stand activity: $e');
      }
      return false;
    }
  }
  
  /// Delete an activity entry
  Future<bool> deleteStandActivity(String activityId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('stand_activity')
          .delete()
          .eq('id', activityId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error deleting stand activity: $e');
      }
      return false;
    }
  }
  
  /// Get pending activity prompt for current user in a club
  Future<PendingActivityPrompt?> getPendingActivityPrompt(String clubId) async {
    if (_client == null) return null;
    
    try {
      final result = await _client.rpc('get_pending_activity_prompts', params: {
        'p_club_id': clubId,
      });
      
      final list = result as List;
      if (list.isEmpty) return null;
      
      return PendingActivityPrompt.fromJson(list.first as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error getting pending activity prompt: $e');
      }
      return null;
    }
  }
  
  /// Dismiss activity prompt for a signin
  Future<bool> dismissActivityPrompt(String signinId) async {
    if (_client == null) return false;
    
    try {
      await _client.rpc('dismiss_activity_prompt', params: {
        'p_signin_id': signinId,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error dismissing activity prompt: $e');
      }
      return false;
    }
  }
  
  /// Sign out and return the signin for activity prompt
  Future<StandSignin?> signOutWithPrompt(String signinId) async {
    if (_client == null) return null;
    
    try {
      // First get the signin details
      final signinResponse = await _client
          .from('stand_signins')
          .select('*, profiles:profiles!stand_signins_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('id', signinId)
          .single();
      
      final signin = StandSignin.fromJson(signinResponse);
      
      // Then sign out
      await _client
          .from('stand_signins')
          .update({
            'status': 'signed_out',
            'signed_out_at': DateTime.now().toUtc().toIso8601String(),
            'ended_reason': 'manual',
          })
          .eq('id', signinId);
      
      return signin;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error signing out with prompt: $e');
      }
      return null;
    }
  }
}

// =====================
// PROVIDERS
// =====================

final standsServiceProvider = Provider<StandsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StandsService(client);
});

/// Provider for stands with active sign-ins
/// Uses autoDispose to clean up when not in use
final clubStandsProvider = FutureProvider.autoDispose.family<List<ClubStand>, String>((ref, clubId) async {
  final service = ref.watch(standsServiceProvider);
  return service.getStandsWithSignins(clubId);
});

/// Provider for current user's active sign-in
final myActiveSigninProvider = FutureProvider.autoDispose.family<StandSignin?, String>((ref, clubId) async {
  final service = ref.watch(standsServiceProvider);
  return service.getMyActiveSignin(clubId);
});

/// Provider for stand activity
final standActivityProvider = FutureProvider.autoDispose.family<List<StandActivity>, String>((ref, standId) async {
  final service = ref.watch(standsServiceProvider);
  return service.getStandActivity(standId);
});

/// Provider for pending activity prompts
final pendingActivityPromptProvider = FutureProvider.autoDispose.family<PendingActivityPrompt?, String>((ref, clubId) async {
  final service = ref.watch(standsServiceProvider);
  return service.getPendingActivityPrompt(clubId);
});

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
    this.username,
    this.displayName,
    this.avatarPath,
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
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  String get userName => displayName ?? username ?? 'Unknown';
  String get handle => username != null ? '@$username' : '';
  
  /// Whether this sign-in is currently active (status=active and not expired)
  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());
  
  /// Formatted sign-in time (e.g., "6:12 AM")
  String get signedInAtFormatted {
    final hour = signedInAt.hour;
    final minute = signedInAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }
  
  /// Time remaining until expiration
  Duration get timeRemaining {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return Duration.zero;
    return expiresAt.difference(now);
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
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      avatarPath: profile?['avatar_path'] as String?,
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
  
  /// Get stands with active sign-ins for a club
  Future<List<ClubStand>> getStandsWithSignins(String clubId) async {
    if (_client == null) return [];
    
    try {
      // Get all stands
      final standsResponse = await _client
          .from('club_stands')
          .select()
          .eq('club_id', clubId)
          .order('sort_order');
      
      // Get active sign-ins (not expired)
      final signinsResponse = await _client
          .from('stand_signins')
          .select('*, profiles:profiles!stand_signins_user_profiles_fkey(username, display_name, avatar_path)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String());
      
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
  
  /// Delete a stand
  Future<bool> deleteStand(String standId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('club_stands')
          .delete()
          .eq('id', standId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StandsService] Error deleting stand: $e');
      }
      return false;
    }
  }
  
  /// Sign in to a stand
  Future<SignInResult> signIn(String clubId, String standId, int ttlHours, {String? note, String? standName}) async {
    if (_client == null) {
      return SignInResult.error('Not connected');
    }
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return SignInResult.error('Not authenticated');
    }
    
    try {
      // First sign out from any active sign-ins in this club
      await _client
          .from('stand_signins')
          .update({
            'status': 'signed_out',
            'signed_out_at': DateTime.now().toIso8601String(),
          })
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'active');
      
      // Create new sign-in
      final expiresAt = DateTime.now().add(Duration(hours: ttlHours));
      
      await _client.from('stand_signins').insert({
        'club_id': clubId,
        'stand_id': standId,
        'user_id': userId,
        'status': 'active',
        'expires_at': expiresAt.toIso8601String(),
        'note': note,
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
            'signed_out_at': DateTime.now().toIso8601String(),
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
            'signed_out_at': DateTime.now().toIso8601String(),
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
          .gt('expires_at', DateTime.now().toIso8601String())
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

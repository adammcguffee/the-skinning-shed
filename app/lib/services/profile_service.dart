import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// User profile model for editing.
class ProfileData {
  ProfileData({
    required this.id,
    this.username,
    this.displayName,
    this.avatarPath,
    this.bio,
    this.defaultState,
    this.defaultCounty,
    this.favoriteSpecies,
    this.coverPath,
  });
  
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarPath;
  final String? bio;
  final String? defaultState;
  final String? defaultCounty;
  final List<String>? favoriteSpecies;
  final String? coverPath;
  
  factory ProfileData.fromJson(Map<String, dynamic> json) {
    List<String>? species;
    if (json['favorite_species'] != null) {
      species = List<String>.from(json['favorite_species']);
    }
    return ProfileData(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      bio: json['bio'] as String?,
      defaultState: json['default_state'] as String?,
      defaultCounty: json['default_county'] as String?,
      favoriteSpecies: species,
      coverPath: json['cover_path'] as String?,
    );
  }
  
  ProfileData copyWith({
    String? displayName,
    String? bio,
    String? defaultState,
    String? defaultCounty,
    List<String>? favoriteSpecies,
    String? avatarPath,
    String? coverPath,
  }) {
    return ProfileData(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      bio: bio ?? this.bio,
      defaultState: defaultState ?? this.defaultState,
      defaultCounty: defaultCounty ?? this.defaultCounty,
      favoriteSpecies: favoriteSpecies ?? this.favoriteSpecies,
      coverPath: coverPath ?? this.coverPath,
    );
  }
}

/// Service for profile operations.
class ProfileService {
  ProfileService(this._client);
  
  final SupabaseClient? _client;
  
  /// Get current user's profile.
  Future<ProfileData?> getCurrentProfile() async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        return ProfileData.fromJson(response);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileService] Error loading profile: $e');
      }
      return null;
    }
  }
  
  /// Update profile data.
  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? defaultState,
    String? defaultCounty,
    List<String>? favoriteSpecies,
  }) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (displayName != null) data['display_name'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (defaultState != null) data['default_state'] = defaultState;
      if (defaultCounty != null) data['default_county'] = defaultCounty;
      if (favoriteSpecies != null) data['favorite_species'] = favoriteSpecies;
      
      await _client
          .from('profiles')
          .update(data)
          .eq('id', userId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileService] Error updating profile: $e');
      }
      return false;
    }
  }
  
  /// Upload avatar photo.
  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    try {
      // Determine extension from filename
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 
                          ext == 'webp' ? 'image/webp' : 'image/jpeg';
      
      final storagePath = '$userId/avatar.$ext';
      
      // Upload to avatars bucket
      await _client.storage
          .from('avatars')
          .uploadBinary(
            storagePath, 
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true, // Allow overwriting existing avatar
            ),
          );
      
      // Update profile with new avatar path
      await _client
          .from('profiles')
          .update({
            'avatar_path': storagePath,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      return storagePath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileService] Error uploading avatar: $e');
      }
      return null;
    }
  }
  
  /// Remove avatar photo.
  Future<bool> removeAvatar() async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      // Get current avatar path
      final profile = await getCurrentProfile();
      if (profile?.avatarPath != null) {
        // Delete from storage
        await _client.storage
            .from('avatars')
            .remove([profile!.avatarPath!]);
      }
      
      // Update profile to remove avatar path
      await _client
          .from('profiles')
          .update({
            'avatar_path': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileService] Error removing avatar: $e');
      }
      return false;
    }
  }
  
  /// Get avatar public URL.
  String? getAvatarUrl(String? avatarPath) {
    if (_client == null || avatarPath == null) return null;
    return _client.storage.from('avatars').getPublicUrl(avatarPath);
  }
}

/// Provider for profile service.
final profileServiceProvider = Provider<ProfileService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileService(client);
});

/// Provider for current user's profile.
final currentProfileProvider = FutureProvider<ProfileData?>((ref) async {
  final service = ref.watch(profileServiceProvider);
  return service.getCurrentProfile();
});

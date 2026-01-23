import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Service for trophy-related operations.
class TrophyService {
  TrophyService(this._client);
  
  final SupabaseClient? _client;
  
  /// Fetch latest public trophies for the feed.
  Future<List<Map<String, dynamic>>> fetchFeed({
    int limit = 20,
    int offset = 0,
    String? category,
    String? state,
    String? county,
  }) async {
    if (_client == null) return [];
    
    var query = _client
        .from('trophy_posts')
        .select('''
          *,
          profiles:user_id (
            id,
            username,
            display_name,
            avatar_path
          ),
          species:species_id (
            common_name,
            scientific_name
          )
        ''')
        .eq('visibility', 'public')
        .order('posted_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    if (category != null) {
      query = query.eq('category', category);
    }
    if (state != null) {
      query = query.eq('state', state);
    }
    if (county != null) {
      query = query.eq('county', county);
    }
    
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Fetch a single trophy by ID.
  Future<Map<String, dynamic>?> fetchTrophy(String id) async {
    if (_client == null) return null;
    
    final response = await _client
        .from('trophy_posts')
        .select('''
          *,
          profiles:user_id (
            id,
            username,
            display_name,
            avatar_path
          ),
          species:species_id (
            common_name,
            scientific_name
          ),
          trophy_photos (
            id,
            storage_path,
            sort_order
          ),
          weather_snapshots (
            temp_f,
            wind_speed,
            wind_dir_deg,
            pressure_hpa,
            humidity_pct,
            condition_text
          ),
          moon_snapshots (
            phase_name,
            illumination_pct
          )
        ''')
        .eq('id', id)
        .single();
    
    return response;
  }
  
  /// Fetch trophies for a specific user (Trophy Wall).
  Future<List<Map<String, dynamic>>> fetchUserTrophies(String userId) async {
    if (_client == null) return [];
    
    final response = await _client
        .from('trophy_posts')
        .select('''
          *,
          species:species_id (
            common_name
          )
        ''')
        .eq('user_id', userId)
        .order('harvest_date', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Create a new trophy post.
  Future<String?> createTrophy({
    required String category,
    required String state,
    required String county,
    required DateTime harvestDate,
    String? harvestTime,
    String? harvestTimeBucket,
    String? speciesId,
    String? customSpeciesName,
    String? story,
    String? privateNotes,
    Map<String, dynamic>? stats,
    String visibility = 'public',
  }) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    final data = {
      'user_id': userId,
      'category': category,
      'state': state,
      'county': county,
      'harvest_date': harvestDate.toIso8601String().split('T')[0],
      'visibility': visibility,
      if (harvestTime != null) 'harvest_time': harvestTime,
      if (harvestTimeBucket != null) 'harvest_time_bucket': harvestTimeBucket,
      if (speciesId != null) 'species_id': speciesId,
      if (customSpeciesName != null) 'custom_species_name': customSpeciesName,
      if (story != null) 'story': story,
      if (privateNotes != null) 'private_notes': privateNotes,
      if (stats != null) 'stats_json': stats,
    };
    
    final response = await _client
        .from('trophy_posts')
        .insert(data)
        .select('id')
        .single();
    
    return response['id'] as String?;
  }
  
  /// Upload a trophy photo.
  Future<String?> uploadPhoto({
    required String trophyId,
    required String filePath,
    required String fileName,
  }) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    final storagePath = '$userId/$trophyId/$fileName';
    
    await _client.storage
        .from('trophy_photos')
        .upload(storagePath, File(filePath));
    
    // Add photo record
    await _client.from('trophy_photos').insert({
      'post_id': trophyId,
      'storage_path': storagePath,
    });
    
    // Update cover photo if this is the first
    await _client
        .from('trophy_posts')
        .update({'cover_photo_path': storagePath})
        .eq('id', trophyId)
        .is_('cover_photo_path', null);
    
    return storagePath;
  }
  
  /// Get public URL for a photo.
  String? getPhotoUrl(String storagePath) {
    if (_client == null) return null;
    return _client.storage.from('trophy_photos').getPublicUrl(storagePath);
  }
  
  /// Delete a trophy post.
  Future<bool> deleteTrophy(String id) async {
    if (_client == null) return false;
    
    try {
      await _client.from('trophy_posts').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Add a reaction to a trophy.
  Future<bool> addReaction(String postId, String type) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client.from('reactions').insert({
        'post_id': postId,
        'user_id': userId,
        'type': type,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Remove a reaction from a trophy.
  Future<bool> removeReaction(String postId, String type) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .eq('type', type);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for trophy service.
final trophyServiceProvider = Provider<TrophyService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TrophyService(client);
});

/// Provider for feed trophies.
final feedTrophiesProvider = FutureProvider.family<List<Map<String, dynamic>>, FeedFilter>((ref, filter) async {
  final service = ref.watch(trophyServiceProvider);
  return service.fetchFeed(
    category: filter.category,
    state: filter.state,
    county: filter.county,
  );
});

/// Filter parameters for feed.
class FeedFilter {
  const FeedFilter({
    this.category,
    this.state,
    this.county,
  });
  
  final String? category;
  final String? state;
  final String? county;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedFilter &&
          category == other.category &&
          state == other.state &&
          county == other.county;
  
  @override
  int get hashCode => Object.hash(category, state, county);
}

/// Provider for a single trophy.
final trophyProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final service = ref.watch(trophyServiceProvider);
  return service.fetchTrophy(id);
});

/// Provider for user's trophies (Trophy Wall).
final userTrophiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final service = ref.watch(trophyServiceProvider);
  return service.fetchUserTrophies(userId);
});

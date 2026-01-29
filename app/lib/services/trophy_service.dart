import 'dart:io';
import 'dart:typed_data';

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
    
    // Build filter query first, then apply transforms
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
        .eq('visibility', 'public');
    
    // Apply filters before transforms
    if (category != null) {
      // Handle "other" category specially - maps to both other_game and other_fishing
      if (category == 'other') {
        query = query.inFilter('category', ['other_game', 'other_fishing']);
      } else {
        query = query.eq('category', category);
      }
    }
    if (state != null) {
      query = query.eq('state', state);
    }
    if (county != null) {
      query = query.eq('county', county);
    }
    
    // Apply transforms last
    final response = await query
        .order('posted_at', ascending: false)
        .range(offset, offset + limit - 1);
    
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
  
  /// Create a new trophy post with optional weather/moon data.
  Future<String?> createTrophy({
    required String category,
    required String state,
    required String county,
    required DateTime harvestDate,
    String? stateCode,
    String? countyFips,
    String? harvestTime,
    String? harvestTimeBucket,
    String? speciesId,
    String? customSpeciesName,
    String? story,
    String? privateNotes,
    Map<String, dynamic>? stats,
    String visibility = 'public',
    Map<String, dynamic>? weatherSnapshot,
    Map<String, dynamic>? moonSnapshot,
    String weatherSource = 'auto',
    bool weatherEdited = false,
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
      'weather_source': weatherSource,
      'weather_edited': weatherEdited,
      if (stateCode != null) 'state_code': stateCode,
      if (countyFips != null) 'county_fips': countyFips,
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
    
    final trophyId = response['id'] as String?;
    
    if (trophyId != null) {
      // Save weather snapshot if provided
      if (weatherSnapshot != null) {
        await _client.from('weather_snapshots').insert({
          'post_id': trophyId,
          ...weatherSnapshot,
        });
      }
      
      // Save moon snapshot if provided
      if (moonSnapshot != null) {
        await _client.from('moon_snapshots').insert({
          'post_id': trophyId,
          ...moonSnapshot,
        });
      }
      
      // Create analytics bucket for research queries
      await _createAnalyticsBucket(
        postId: trophyId,
        category: category,
        state: state,
        county: county,
        countyFips: countyFips,
        harvestDate: harvestDate,
        harvestTime: harvestTime,
        weatherSnapshot: weatherSnapshot,
        moonSnapshot: moonSnapshot,
      );
    }
    
    return trophyId;
  }
  
  /// Create analytics bucket for aggregation queries.
  Future<void> _createAnalyticsBucket({
    required String postId,
    required String category,
    required String state,
    required String county,
    String? countyFips,
    required DateTime harvestDate,
    String? harvestTime,
    Map<String, dynamic>? weatherSnapshot,
    Map<String, dynamic>? moonSnapshot,
  }) async {
    if (_client == null) return;
    
    // Determine time of day bucket
    String? todBucket;
    if (harvestTime != null) {
      final parts = harvestTime.split(':');
      if (parts.isNotEmpty) {
        final hour = int.tryParse(parts[0]) ?? 0;
        if (hour >= 5 && hour < 10) todBucket = 'morning';
        else if (hour >= 10 && hour < 14) todBucket = 'midday';
        else if (hour >= 14 && hour < 19) todBucket = 'evening';
        else todBucket = 'night';
      }
    }
    
    // Determine pressure bucket (0.5 inHg bins)
    String? pressureBucket;
    if (weatherSnapshot != null && weatherSnapshot['pressure_inhg'] != null) {
      final pressure = (weatherSnapshot['pressure_inhg'] as num).toDouble();
      final bucket = (pressure * 2).round() / 2; // Round to nearest 0.5
      pressureBucket = bucket.toStringAsFixed(1);
    }
    
    // Determine temp bucket (5°F bins)
    String? tempBucket;
    if (weatherSnapshot != null && weatherSnapshot['temp_f'] != null) {
      final temp = (weatherSnapshot['temp_f'] as num).toDouble();
      final bucket = ((temp / 5).round() * 5);
      tempBucket = '$bucket';
    }
    
    // Determine moon phase bucket
    String? moonPhaseBucket;
    if (moonSnapshot != null && moonSnapshot['phase_name'] != null) {
      moonPhaseBucket = moonSnapshot['phase_name'] as String;
    }
    
    // Determine wind direction bucket
    String? windDirBucket;
    if (weatherSnapshot != null && weatherSnapshot['wind_dir_text'] != null) {
      windDirBucket = weatherSnapshot['wind_dir_text'] as String;
      if (!['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'].contains(windDirBucket)) {
        windDirBucket = 'VAR';
      }
    }
    
    await _client.from('analytics_buckets').insert({
      'post_id': postId,
      'category': category,
      'state': state,
      'county': county,
      'season_year': harvestDate.year,
      'dow': harvestDate.weekday,
      if (countyFips != null) 'county_fips': countyFips,
      if (todBucket != null) 'tod_bucket': todBucket,
      if (tempBucket != null) 'temp_bucket': tempBucket,
      if (pressureBucket != null) 'pressure_bucket': pressureBucket,
      if (moonPhaseBucket != null) 'moon_phase_bucket': moonPhaseBucket,
      if (windDirBucket != null) 'wind_dir_bucket': windDirBucket,
    });
  }
  
  /// Upload a trophy photo.
  /// Works cross-platform by accepting bytes.
  Future<String?> uploadPhoto({
    required String trophyId,
    required String filePath,
    required String fileName,
  }) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    final storagePath = '$userId/$trophyId/$fileName';
    
    try {
      // Read file and upload as bytes (cross-platform)
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      await _client.storage
          .from('trophy_photos')
          .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
          ));
      
      // Add photo record
      final photoResponse = await _client.from('trophy_photos').insert({
        'post_id': trophyId,
        'storage_path': storagePath,
      }).select('id').single();
      
      final photoId = photoResponse['id'] as String;
      
      // Update cover photo if this is the first
      await _client
          .from('trophy_posts')
          .update({'cover_photo_path': storagePath})
          .eq('id', trophyId)
          .isFilter('cover_photo_path', null);
      
      // Trigger thumbnail generation (fire-and-forget)
      _generateTrophyThumbnails(
        trophyId: trophyId,
        photoId: photoId,
        storagePath: storagePath,
      );
      
      return storagePath;
    } catch (e) {
      print('Photo upload error: $e');
      return null;
    }
  }
  
  /// Upload a trophy photo from bytes (for web support).
  Future<String?> uploadPhotoBytes({
    required String trophyId,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (_client == null) return null;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    
    final storagePath = '$userId/$trophyId/$fileName';
    
    try {
      final data = Uint8List.fromList(bytes);
      await _client.storage
          .from('trophy_photos')
          .uploadBinary(storagePath, data, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
          ));
      
      // Add photo record
      final photoResponse = await _client.from('trophy_photos').insert({
        'post_id': trophyId,
        'storage_path': storagePath,
      }).select('id').single();
      
      final photoId = photoResponse['id'] as String;
      
      // Update cover photo if this is the first
      await _client
          .from('trophy_posts')
          .update({'cover_photo_path': storagePath})
          .eq('id', trophyId)
          .isFilter('cover_photo_path', null);
      
      // Trigger thumbnail generation (fire-and-forget)
      _generateTrophyThumbnails(
        trophyId: trophyId,
        photoId: photoId,
        storagePath: storagePath,
      );
      
      return storagePath;
    } catch (e) {
      print('Photo upload error: $e');
      return null;
    }
  }
  
  /// Generate thumbnail variants for a trophy photo (fire-and-forget)
  void _generateTrophyThumbnails({
    required String trophyId,
    required String photoId,
    required String storagePath,
  }) {
    if (_client == null) return;
    
    // Fire-and-forget: don't await, don't block the upload
    Future.microtask(() async {
      try {
        // Generate for trophy_photos table
        await _client.functions.invoke(
          'image-variants',
          body: {
            'bucket': 'trophy_photos',
            'path': storagePath,
            'recordType': 'trophy_photos',
            'recordId': photoId,
          },
        );
        
        // Also update trophy_posts cover if this is the cover photo
        await _client.functions.invoke(
          'image-variants',
          body: {
            'bucket': 'trophy_photos',
            'path': storagePath,
            'recordType': 'trophy_posts',
            'recordId': trophyId,
          },
        );
        
        print('[TrophyService] Thumbnail generation triggered for $photoId');
      } catch (e) {
        // Don't fail - thumbnails are optional enhancement
        print('[TrophyService] Thumbnail generation error (non-fatal): $e');
      }
    });
  }
  
  /// Get public URL for a photo.
  String? getPhotoUrl(String storagePath) {
    if (_client == null) return null;
    return _client.storage.from('trophy_photos').getPublicUrl(storagePath);
  }
  
  /// Update a trophy post.
  Future<bool> updateTrophy({
    required String trophyId,
    String? category,
    String? state,
    String? county,
    DateTime? harvestDate,
    String? harvestTime,
    String? harvestTimeBucket,
    String? story,
    String? privateNotes,
    String? visibility,
    String? coverPhotoPath,
  }) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (category != null) data['category'] = category;
      if (state != null) data['state'] = state;
      if (county != null) data['county'] = county;
      if (harvestDate != null) data['harvest_date'] = harvestDate.toIso8601String().split('T')[0];
      if (harvestTime != null) data['harvest_time'] = harvestTime;
      if (harvestTimeBucket != null) data['harvest_time_bucket'] = harvestTimeBucket;
      if (story != null) data['story'] = story;
      if (privateNotes != null) data['private_notes'] = privateNotes;
      if (visibility != null) data['visibility'] = visibility;
      if (coverPhotoPath != null) data['cover_photo_path'] = coverPhotoPath;
      
      await _client
          .from('trophy_posts')
          .update(data)
          .eq('id', trophyId)
          .eq('user_id', userId); // RLS enforced, but be explicit
      
      return true;
    } catch (e) {
      print('Error updating trophy: $e');
      return false;
    }
  }

  /// Delete a trophy post with full cleanup (photos from storage, related records).
  /// 
  /// If [asAdmin] is true, logs a moderation action and skips owner check.
  /// The RLS policy will enforce admin permission at the database level.
  Future<bool> deleteTrophy(String trophyId, {bool asAdmin = false, String? reason}) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      // Fetch trophy info for audit (if admin) and photo paths
      final trophyResponse = await _client
          .from('trophy_posts')
          .select('user_id')
          .eq('id', trophyId)
          .maybeSingle();
      
      final ownerId = trophyResponse?['user_id'] as String?;
      
      // 1. Fetch photo paths before deletion
      final photosResponse = await _client
          .from('trophy_photos')
          .select('storage_path')
          .eq('post_id', trophyId);
      
      final photoPaths = (photosResponse as List)
          .map((p) => p['storage_path'] as String)
          .toList();
      
      // 2. Delete photos from storage
      if (photoPaths.isNotEmpty) {
        try {
          await _client.storage.from('trophy_photos').remove(photoPaths);
        } catch (e) {
          print('Warning: Failed to delete some storage files: $e');
          // Continue with DB deletion even if storage fails
        }
      }
      
      // 3. Delete related records (cascade should handle most, but be explicit)
      await _client.from('trophy_photos').delete().eq('post_id', trophyId);
      await _client.from('weather_snapshots').delete().eq('post_id', trophyId);
      await _client.from('moon_snapshots').delete().eq('post_id', trophyId);
      await _client.from('analytics_buckets').delete().eq('post_id', trophyId);
      
      // 4. Log moderation action if admin deletion
      if (asAdmin && ownerId != null && ownerId != userId) {
        await _client.from('moderation_actions').insert({
          'admin_id': userId,
          'target_type': 'trophy',
          'target_id': trophyId,
          'target_owner_id': ownerId,
          'action': 'delete',
          'reason': reason,
        });
      }
      
      // 5. Delete the trophy post itself (RLS handles permission check)
      await _client
          .from('trophy_posts')
          .delete()
          .eq('id', trophyId);
      
      return true;
    } catch (e) {
      print('Error deleting trophy: $e');
      return false;
    }
  }
  
  /// Delete a single photo from a trophy post.
  Future<bool> deletePhoto({
    required String trophyId,
    required String photoId,
    required String storagePath,
  }) async {
    if (_client == null) return false;
    
    try {
      // Delete from storage
      await _client.storage.from('trophy_photos').remove([storagePath]);
      
      // Delete DB record
      await _client.from('trophy_photos').delete().eq('id', photoId);
      
      // Update cover photo if this was the cover
      final trophy = await _client
          .from('trophy_posts')
          .select('cover_photo_path')
          .eq('id', trophyId)
          .single();
      
      if (trophy['cover_photo_path'] == storagePath) {
        // Find another photo to be the cover
        final remainingPhotos = await _client
            .from('trophy_photos')
            .select('storage_path')
            .eq('post_id', trophyId)
            .order('sort_order')
            .limit(1);
        
        final newCover = (remainingPhotos as List).isNotEmpty 
            ? remainingPhotos.first['storage_path'] 
            : null;
        
        await _client
            .from('trophy_posts')
            .update({'cover_photo_path': newCover})
            .eq('id', trophyId);
      }
      
      return true;
    } catch (e) {
      print('Error deleting photo: $e');
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

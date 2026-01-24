import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';
import 'supabase_service.dart';

/// Weather favorite location stored in Supabase.
class WeatherFavoriteLocation {
  const WeatherFavoriteLocation({
    required this.id,
    required this.stateCode,
    required this.countyName,
    this.countyFips,
    required this.label,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });
  
  final String id;
  final String stateCode;
  final String countyName;
  final String? countyFips;
  final String label;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  factory WeatherFavoriteLocation.fromJson(Map<String, dynamic> json) {
    return WeatherFavoriteLocation(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      countyName: json['county_name'] as String,
      countyFips: json['county_fips'] as String?,
      label: json['label'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'state_code': stateCode,
    'county_name': countyName,
    'county_fips': countyFips,
    'label': label,
    'sort_order': sortOrder,
  };
  
  /// Convert to CountySelection for weather loading.
  CountySelection toSelection(String stateName) {
    return CountySelection(
      stateCode: stateCode,
      stateName: stateName,
      countyName: countyName,
      countyFips: countyFips,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherFavoriteLocation && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// Service for managing weather favorite locations in Supabase.
/// 
/// Favorites are user-scoped via RLS (auth.uid() = user_id).
/// Syncs across web + mobile for the same user.
/// 
/// Privacy-safe: Only stores county identifiers, not coordinates.
class WeatherFavoritesService {
  WeatherFavoritesService._();
  
  static WeatherFavoritesService? _instance;
  static WeatherFavoritesService get instance =>
      _instance ??= WeatherFavoritesService._();
  
  static const _tableName = 'weather_favorite_locations';
  
  SupabaseClient? get _client => SupabaseService.instance.client;
  String? get _userId => SupabaseService.instance.currentUser?.id;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Fetch all favorites for current user.
  /// Returns empty list if not authenticated or on error.
  Future<List<WeatherFavoriteLocation>> fetchFavorites() async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) {
      debugPrint('WeatherFavoritesService: Not authenticated');
      return [];
    }
    
    try {
      final response = await client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      
      return (response as List)
          .map((json) => WeatherFavoriteLocation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      return [];
    }
  }
  
  /// Check if a selection is already favorited.
  Future<bool> isFavorite(CountySelection selection) async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) return false;
    
    try {
      // Check by FIPS first (more reliable)
      if (selection.countyFips != null) {
        final response = await client
            .from(_tableName)
            .select('id')
            .eq('user_id', userId)
            .eq('county_fips', selection.countyFips!)
            .maybeSingle();
        if (response != null) return true;
      }
      
      // Fall back to state + county name
      final response = await client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('state_code', selection.stateCode)
          .eq('county_name', selection.countyName)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }
  
  /// Find existing favorite by selection.
  Future<WeatherFavoriteLocation?> findBySelection(
    CountySelection selection,
  ) async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) return null;
    
    try {
      // Check by FIPS first
      if (selection.countyFips != null) {
        final response = await client
            .from(_tableName)
            .select()
            .eq('user_id', userId)
            .eq('county_fips', selection.countyFips!)
            .maybeSingle();
        if (response != null) {
          return WeatherFavoriteLocation.fromJson(response);
        }
      }
      
      // Fall back to state + county name
      final response = await client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('state_code', selection.stateCode)
          .eq('county_name', selection.countyName)
          .maybeSingle();
      
      if (response != null) {
        return WeatherFavoriteLocation.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error finding favorite: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Add a new favorite location.
  /// 
  /// Returns the created favorite, or null on error.
  /// Handles unique violations gracefully (treats as already favorited).
  Future<WeatherFavoriteLocation?> addFavorite({
    required CountySelection selection,
  }) async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) {
      debugPrint('WeatherFavoritesService: Not authenticated');
      return null;
    }
    
    try {
      // Get current max sort_order to append at end
      final maxOrderResponse = await client
          .from(_tableName)
          .select('sort_order')
          .eq('user_id', userId)
          .order('sort_order', ascending: false)
          .limit(1)
          .maybeSingle();
      
      final maxOrder = maxOrderResponse != null
          ? (maxOrderResponse['sort_order'] as int? ?? 0)
          : 0;
      
      final response = await client
          .from(_tableName)
          .insert({
            'user_id': userId,
            'state_code': selection.stateCode,
            'county_name': selection.countyName,
            'county_fips': selection.countyFips,
            'label': selection.label,
            'sort_order': maxOrder + 1,
          })
          .select()
          .single();
      
      return WeatherFavoriteLocation.fromJson(response);
    } on PostgrestException catch (e) {
      // Handle unique constraint violations gracefully
      if (e.code == '23505') {
        debugPrint('Favorite already exists: ${selection.label}');
        // Return existing favorite
        return findBySelection(selection);
      }
      debugPrint('Error adding favorite: $e');
      return null;
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Remove a favorite by its ID.
  Future<bool> removeFavorite({required String favoriteId}) async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) return false;
    
    try {
      await client
          .from(_tableName)
          .delete()
          .eq('id', favoriteId)
          .eq('user_id', userId); // RLS backup
      
      return true;
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return false;
    }
  }
  
  /// Remove a favorite by selection (FIPS or state+county match).
  Future<bool> removeFavoriteBySelection({
    required CountySelection selection,
  }) async {
    final favorite = await findBySelection(selection);
    if (favorite == null) return false;
    return removeFavorite(favoriteId: favorite.id);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // UPDATE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Reorder favorites based on new list order.
  /// 
  /// Updates sort_order for each favorite sequentially.
  Future<bool> reorderFavorites(List<WeatherFavoriteLocation> ordered) async {
    final client = _client;
    final userId = _userId;
    
    if (client == null || userId == null) return false;
    
    try {
      // Update each favorite's sort_order
      for (var i = 0; i < ordered.length; i++) {
        await client
            .from(_tableName)
            .update({'sort_order': i})
            .eq('id', ordered[i].id)
            .eq('user_id', userId);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error reordering favorites: $e');
      return false;
    }
  }
}

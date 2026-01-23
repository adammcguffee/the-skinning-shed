import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Page identifiers for ad targeting.
/// Must match values stored in ad_slots.page column.
abstract final class AdPages {
  static const String feed = 'feed';
  static const String explore = 'explore';
  static const String trophyWall = 'trophy_wall';
  static const String weather = 'weather';
  static const String land = 'land';
  static const String swapShop = 'swap_shop';
  static const String settings = 'settings';
  static const String research = 'research';
}

/// Ad position within the header.
abstract final class AdPosition {
  static const String left = 'left';
  static const String right = 'right';
}

/// Represents a loaded ad creative with URL and metadata.
class AdCreative {
  const AdCreative({
    required this.imageUrl,
    required this.page,
    required this.position,
    this.clickUrl,
    this.label,
    this.trackingTag,
  });

  /// Signed URL or public URL for the ad image.
  final String imageUrl;
  
  /// Page this ad is targeting.
  final String page;
  
  /// Position (left/right).
  final String position;
  
  /// Optional click-through URL.
  final String? clickUrl;
  
  /// Internal label for the ad.
  final String? label;
  
  /// Optional tracking tag.
  final String? trackingTag;
}

/// Service for fetching and caching ad creatives.
/// 
/// Uses Supabase ad_slots table for metadata and ad_share bucket for images.
/// Implements in-memory caching to minimize database queries.
class AdService {
  AdService(this._client);

  final SupabaseClient? _client;
  
  /// Storage bucket name for ad creatives.
  static const String _bucketName = 'ad_share';
  
  /// Cache duration in minutes.
  static const int _cacheDurationMinutes = 10;
  
  /// In-memory cache: key = "page:position", value = AdCreative or null
  final Map<String, _CacheEntry> _cache = {};
  
  /// Fetch an ad for a specific page and position.
  /// Returns null if no active ad exists.
  Future<AdCreative?> fetchAdSlot({
    required String page,
    required String position,
  }) async {
    if (_client == null) return null;
    
    final cacheKey = '$page:$position';
    
    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.creative;
    }
    
    try {
      // Query ad_slots table
      // RLS policies handle enabled + date filtering
      final response = await _client
          .from('ad_slots')
          .select('storage_path, click_url, label, tracking_tag')
          .eq('page', page)
          .eq('position', position)
          .order('priority', ascending: true)
          .limit(1)
          .maybeSingle();
      
      if (response == null) {
        // Cache the null result to avoid repeated queries
        _cache[cacheKey] = _CacheEntry(null, DateTime.now());
        return null;
      }
      
      final storagePath = response['storage_path'] as String;
      
      // Generate signed URL for the image (1 hour expiry)
      // Using public URL if bucket is public, signed URL if private
      String? imageUrl;
      try {
        // Try to get public URL first (works for public buckets)
        imageUrl = _client.storage.from(_bucketName).getPublicUrl(storagePath);
      } catch (e) {
        // Fallback: try signed URL for private buckets
        try {
          final signedUrl = await _client.storage
              .from(_bucketName)
              .createSignedUrl(storagePath, 3600); // 1 hour
          imageUrl = signedUrl;
        } catch (e2) {
          print('AdService: Failed to get URL for $storagePath: $e2');
          _cache[cacheKey] = _CacheEntry(null, DateTime.now());
          return null;
        }
      }
      
      final creative = AdCreative(
        imageUrl: imageUrl,
        page: page,
        position: position,
        clickUrl: response['click_url'] as String?,
        label: response['label'] as String?,
        trackingTag: response['tracking_tag'] as String?,
      );
      
      // Cache the result
      _cache[cacheKey] = _CacheEntry(creative, DateTime.now());
      
      return creative;
    } catch (e) {
      print('AdService: Error fetching ad slot: $e');
      // Cache null to avoid repeated failed queries
      _cache[cacheKey] = _CacheEntry(null, DateTime.now());
      return null;
    }
  }
  
  /// Quick check if an ad exists for a slot (uses cache).
  /// Returns true if an ad is available, false otherwise.
  /// Does NOT fetch from server if not cached - returns false.
  bool hasAdCached({required String page, required String position}) {
    final cacheKey = '$page:$position';
    final cached = _cache[cacheKey];
    if (cached == null || cached.isExpired) return false;
    return cached.creative != null;
  }
  
  /// Pre-fetch ads for a page (both left and right).
  /// Useful for header to know which slots have ads.
  Future<({AdCreative? left, AdCreative? right})> prefetchAdsForPage(String page) async {
    final results = await Future.wait([
      fetchAdSlot(page: page, position: AdPosition.left),
      fetchAdSlot(page: page, position: AdPosition.right),
    ]);
    return (left: results[0], right: results[1]);
  }
  
  /// Clear the cache (useful for admin refresh).
  void clearCache() {
    _cache.clear();
  }
  
  /// Invalidate cache for a specific slot.
  void invalidateSlot({required String page, required String position}) {
    _cache.remove('$page:$position');
  }
}

/// Cache entry with expiration.
class _CacheEntry {
  _CacheEntry(this.creative, this.cachedAt);
  
  final AdCreative? creative;
  final DateTime cachedAt;
  
  bool get isExpired {
    final expiry = cachedAt.add(const Duration(minutes: AdService._cacheDurationMinutes));
    return DateTime.now().isAfter(expiry);
  }
}

/// Provider for AdService.
final adServiceProvider = Provider<AdService>((ref) {
  final client = SupabaseService.instance.client;
  return AdService(client);
});

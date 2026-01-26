import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Swap shop listing model.
class SwapShopListing {
  SwapShopListing({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    this.description,
    this.price,
    this.condition,
    required this.state,
    this.county,
    required this.contactMethod,
    required this.contactValue,
    required this.status,
    required this.createdAt,
    this.photos = const [],
    this.sellerName,
    this.sellerAvatarPath,
  });

  final String id;
  final String userId;
  final String category;
  final String title;
  final String? description;
  final double? price;
  final String? condition;
  final String state;
  final String? county;
  final String contactMethod;
  final String contactValue;
  final String status;
  final DateTime createdAt;
  final List<String> photos;
  final String? sellerName;
  final String? sellerAvatarPath;

  factory SwapShopListing.fromJson(Map<String, dynamic> json) {
    // Extract photos from related table if available
    final photosRaw = json['swap_shop_photos'] as List<dynamic>?;
    final photos = photosRaw?.map((p) => p['storage_path'] as String).toList() ?? [];

    // Extract seller info if available
    final profile = json['profiles'] as Map<String, dynamic>?;

    return SwapShopListing(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      condition: json['condition'] as String?,
      state: json['state'] as String,
      county: json['county'] as String?,
      contactMethod: json['contact_method'] as String,
      contactValue: json['contact_value'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photos: photos,
      sellerName: profile?['display_name'] as String? ?? profile?['username'] as String?,
      sellerAvatarPath: profile?['avatar_path'] as String?,
    );
  }

  String get locationDisplay {
    if (county != null) return '$county, $state';
    return state;
  }
}

/// Search/filter parameters for swap shop.
class SwapShopSearchParams {
  SwapShopSearchParams({
    this.query,
    this.category,
    this.condition,
    this.state,
    this.county,
    this.minPrice,
    this.maxPrice,
    this.sortBy = SwapShopSortBy.newest,
  });

  final String? query;
  final String? category;
  final String? condition;
  final String? state;
  final String? county;
  final double? minPrice;
  final double? maxPrice;
  final SwapShopSortBy sortBy;

  SwapShopSearchParams copyWith({
    String? query,
    String? category,
    String? condition,
    String? state,
    String? county,
    double? minPrice,
    double? maxPrice,
    SwapShopSortBy? sortBy,
    bool clearQuery = false,
    bool clearCategory = false,
    bool clearCondition = false,
    bool clearState = false,
    bool clearCounty = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return SwapShopSearchParams(
      query: clearQuery ? null : (query ?? this.query),
      category: clearCategory ? null : (category ?? this.category),
      condition: clearCondition ? null : (condition ?? this.condition),
      state: clearState ? null : (state ?? this.state),
      county: clearCounty ? null : (county ?? this.county),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

enum SwapShopSortBy {
  newest,
  priceLowToHigh,
  priceHighToLow,
}

/// Service for managing swap shop listings.
class SwapShopService {
  SwapShopService(this._supabaseService);

  final SupabaseService _supabaseService;

  SupabaseClient get _client {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Supabase not initialized');
    return client;
  }

  /// Fetch listings with optional search/filter.
  Future<List<SwapShopListing>> fetchListings({
    SwapShopSearchParams? params,
    int limit = 50,
    int offset = 0,
  }) async {
    // Build base query
    var builder = _client
        .from('swap_shop_listings')
        .select('''
          *,
          swap_shop_photos(storage_path, sort_order),
          profiles(display_name, username, avatar_path)
        ''')
        .eq('status', 'active');

    // Apply filters
    if (params != null) {
      if (params.query != null && params.query!.isNotEmpty) {
        builder = builder.or('title.ilike.%${params.query}%,description.ilike.%${params.query}%');
      }

      if (params.category != null) {
        builder = builder.eq('category', params.category!);
      }

      if (params.condition != null) {
        builder = builder.eq('condition', params.condition!);
      }

      if (params.state != null) {
        builder = builder.eq('state', params.state!);
      }

      if (params.county != null) {
        builder = builder.eq('county', params.county!);
      }

      if (params.minPrice != null) {
        builder = builder.gte('price', params.minPrice!);
      }

      if (params.maxPrice != null) {
        builder = builder.lte('price', params.maxPrice!);
      }
    }

    // Apply sorting and pagination
    final sortBy = params?.sortBy ?? SwapShopSortBy.newest;
    final String orderColumn;
    final bool ascending;
    
    switch (sortBy) {
      case SwapShopSortBy.newest:
        orderColumn = 'created_at';
        ascending = false;
        break;
      case SwapShopSortBy.priceLowToHigh:
        orderColumn = 'price';
        ascending = true;
        break;
      case SwapShopSortBy.priceHighToLow:
        orderColumn = 'price';
        ascending = false;
        break;
    }

    final response = await builder
        .order(orderColumn, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((json) => SwapShopListing.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single listing by ID.
  Future<SwapShopListing?> fetchListing(String id) async {
    final response = await _client
        .from('swap_shop_listings')
        .select('''
          *,
          swap_shop_photos(storage_path, sort_order),
          profiles(display_name, username, avatar_path)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return SwapShopListing.fromJson(response);
  }

  /// Create a new listing.
  Future<String> createListing({
    required String category,
    required String title,
    String? description,
    double? price,
    String? condition,
    required String stateCode,
    String? county,
    required String contactMethod,
    required String contactValue,
    List<XFile>? photos,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Insert the listing
    final listingResponse = await _client.from('swap_shop_listings').insert({
      'user_id': userId,
      'category': category,
      'title': title,
      'description': description,
      'price': price,
      'condition': condition,
      'state': stateCode,
      'county': county,
      'contact_method': contactMethod,
      'contact_value': contactValue,
      'status': 'active',
    }).select().single();

    final listingId = listingResponse['id'] as String;

    // Upload photos
    if (photos != null && photos.isNotEmpty) {
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        final path = '$userId/$listingId/${i}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        try {
          await _client.storage.from('swap_shop_photos').uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
              );

          // Insert photo record
          await _client.from('swap_shop_photos').insert({
            'listing_id': listingId,
            'storage_path': path,
            'sort_order': i,
          });
        } catch (e) {
          // Log error but continue with other photos
          if (kDebugMode) {
            debugPrint('Error uploading swap shop photo $i: $e');
          }
          // Re-throw on first photo failure to show user error
          if (i == 0) {
            throw Exception('Upload failed. Please check your connection and try again.');
          }
        }
      }
    }

    return listingId;
  }

  /// Delete a listing (owner only).
  Future<void> deleteListing(String id) async {
    await _client.from('swap_shop_listings').delete().eq('id', id);
  }

  /// Get public URL for a photo.
  String getPhotoUrl(String path) {
    return _client.storage.from('swap_shop_photos').getPublicUrl(path);
  }
}

/// Provider for swap shop service.
final swapShopServiceProvider = Provider<SwapShopService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SwapShopService(supabaseService);
});

/// State for swap shop listings with search/filter.
class SwapShopListingsState {
  SwapShopListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
    this.params,
  });

  final List<SwapShopListing> listings;
  final bool isLoading;
  final String? error;
  final SwapShopSearchParams? params;

  SwapShopListingsState copyWith({
    List<SwapShopListing>? listings,
    bool? isLoading,
    String? error,
    SwapShopSearchParams? params,
    bool clearError = false,
  }) {
    return SwapShopListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      params: params ?? this.params,
    );
  }
}

/// Notifier for swap shop listings.
class SwapShopListingsNotifier extends StateNotifier<SwapShopListingsState> {
  SwapShopListingsNotifier(this._service) : super(SwapShopListingsState());

  final SwapShopService _service;

  Future<void> fetchListings({SwapShopSearchParams? params}) async {
    state = state.copyWith(isLoading: true, clearError: true, params: params);

    try {
      final listings = await _service.fetchListings(params: params);
      state = state.copyWith(listings: listings, isLoading: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SwapShopListingsNotifier] Error: $e');
      }
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void updateParams(SwapShopSearchParams params) {
    fetchListings(params: params);
  }

  void clearFilters() {
    fetchListings(params: SwapShopSearchParams());
  }
}

/// Provider for swap shop listings notifier.
final swapShopListingsNotifierProvider =
    StateNotifierProvider<SwapShopListingsNotifier, SwapShopListingsState>((ref) {
  final service = ref.watch(swapShopServiceProvider);
  return SwapShopListingsNotifier(service);
});

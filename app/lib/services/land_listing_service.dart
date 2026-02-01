import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/utils/privacy_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Land listing model.
class LandListing {
  LandListing({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.description,
    required this.state,
    required this.county,
    this.acreage,
    this.priceTotal,
    this.pricePerAcre,
    this.speciesTags,
    required this.contactMethod,
    required this.contactValue,
    required this.status,
    required this.createdAt,
    this.photos = const [],
    this.ownerName,
    this.ownerAvatarPath,
  });

  final String id;
  final String userId;
  final String type; // 'lease' or 'sale'
  final String title;
  final String? description;
  final String state;
  final String county;
  final double? acreage;
  final double? priceTotal;
  final double? pricePerAcre;
  final List<String>? speciesTags;
  final String contactMethod;
  final String contactValue;
  final String status;
  final DateTime createdAt;
  final List<String> photos;
  final String? ownerName;
  final String? ownerAvatarPath;

  factory LandListing.fromJson(Map<String, dynamic> json) {
    // Extract photos from related table if available
    final photosRaw = json['land_photos'] as List<dynamic>?;
    final photos = photosRaw?.map((p) => p['storage_path'] as String).toList() ?? [];

    // Extract owner info if available
    final profile = json['profiles'] as Map<String, dynamic>?;

    // Extract species tags
    final speciesRaw = json['species_tags'] as List<dynamic>?;
    final speciesTags = speciesRaw?.cast<String>();

    return LandListing(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      state: json['state'] as String,
      county: json['county'] as String,
      acreage: (json['acreage'] as num?)?.toDouble(),
      priceTotal: (json['price_total'] as num?)?.toDouble(),
      pricePerAcre: (json['price_per_acre'] as num?)?.toDouble(),
      speciesTags: speciesTags,
      contactMethod: json['contact_method'] as String,
      contactValue: json['contact_value'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photos: photos,
      ownerName: getSafeDisplayName(
        displayName: profile?['display_name'] as String?,
        username: profile?['username'] as String?,
        defaultName: 'Owner',
      ),
      ownerAvatarPath: profile?['avatar_path'] as String?,
    );
  }

  String get locationDisplay => '$county, $state';

  String get priceDisplay {
    if (priceTotal == null) return 'Contact for price';
    if (type == 'lease') {
      return '\$${priceTotal!.toStringAsFixed(0)}/season';
    }
    return '\$${_formatPrice(priceTotal!)}';
  }

  static String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

/// Search/filter parameters for land listings.
class LandSearchParams {
  LandSearchParams({
    this.type,
    this.state,
    this.county,
    this.minAcreage,
    this.maxAcreage,
    this.minPrice,
    this.maxPrice,
    this.speciesTag,
    this.sortBy = LandSortBy.newest,
  });

  final String? type; // 'lease' or 'sale'
  final String? state;
  final String? county;
  final double? minAcreage;
  final double? maxAcreage;
  final double? minPrice;
  final double? maxPrice;
  final String? speciesTag;
  final LandSortBy sortBy;

  LandSearchParams copyWith({
    String? type,
    String? state,
    String? county,
    double? minAcreage,
    double? maxAcreage,
    double? minPrice,
    double? maxPrice,
    String? speciesTag,
    LandSortBy? sortBy,
    bool clearType = false,
    bool clearState = false,
    bool clearCounty = false,
    bool clearMinAcreage = false,
    bool clearMaxAcreage = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearSpeciesTag = false,
  }) {
    return LandSearchParams(
      type: clearType ? null : (type ?? this.type),
      state: clearState ? null : (state ?? this.state),
      county: clearCounty ? null : (county ?? this.county),
      minAcreage: clearMinAcreage ? null : (minAcreage ?? this.minAcreage),
      maxAcreage: clearMaxAcreage ? null : (maxAcreage ?? this.maxAcreage),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      speciesTag: clearSpeciesTag ? null : (speciesTag ?? this.speciesTag),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

enum LandSortBy {
  newest,
  priceLowToHigh,
  priceHighToLow,
  acreageLowToHigh,
  acreageHighToLow,
}

/// Service for managing land listings.
class LandListingService {
  LandListingService(this._supabaseService);

  final SupabaseService _supabaseService;

  SupabaseClient get _client {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Supabase not initialized');
    return client;
  }

  /// Fetch listings with optional filters.
  Future<List<LandListing>> fetchListings({
    LandSearchParams? params,
    int limit = 50,
    int offset = 0,
  }) async {
    // Build base query
    var builder = _client
        .from('land_listings')
        .select('''
          *,
          land_photos(storage_path, sort_order),
          profiles(display_name, username, avatar_path)
        ''')
        .eq('status', 'active');

    // Apply filters
    if (params != null) {
      if (params.type != null) {
        builder = builder.eq('type', params.type!);
      }

      if (params.state != null) {
        builder = builder.eq('state', params.state!);
      }

      if (params.county != null) {
        builder = builder.eq('county', params.county!);
      }

      if (params.minAcreage != null) {
        builder = builder.gte('acreage', params.minAcreage!);
      }

      if (params.maxAcreage != null) {
        builder = builder.lte('acreage', params.maxAcreage!);
      }

      if (params.minPrice != null) {
        builder = builder.gte('price_total', params.minPrice!);
      }

      if (params.maxPrice != null) {
        builder = builder.lte('price_total', params.maxPrice!);
      }

      if (params.speciesTag != null) {
        builder = builder.contains('species_tags', [params.speciesTag!]);
      }
    }

    // Apply sorting and pagination
    final sortBy = params?.sortBy ?? LandSortBy.newest;
    final String orderColumn;
    final bool ascending;

    switch (sortBy) {
      case LandSortBy.newest:
        orderColumn = 'created_at';
        ascending = false;
        break;
      case LandSortBy.priceLowToHigh:
        orderColumn = 'price_total';
        ascending = true;
        break;
      case LandSortBy.priceHighToLow:
        orderColumn = 'price_total';
        ascending = false;
        break;
      case LandSortBy.acreageLowToHigh:
        orderColumn = 'acreage';
        ascending = true;
        break;
      case LandSortBy.acreageHighToLow:
        orderColumn = 'acreage';
        ascending = false;
        break;
    }

    final response = await builder
        .order(orderColumn, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((json) => LandListing.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single listing by ID.
  Future<LandListing?> fetchListing(String id) async {
    final response = await _client
        .from('land_listings')
        .select('''
          *,
          land_photos(storage_path, sort_order),
          profiles(display_name, username, avatar_path)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return LandListing.fromJson(response);
  }

  /// Create a new listing.
  Future<String> createListing({
    required String type,
    required String title,
    String? description,
    double? price,
    double? acreage,
    required String stateCode,
    required String stateName,
    String? county,
    required String contactMethod,
    required String contactValue,
    List<String>? speciesTags,
    List<XFile>? photos,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Calculate price per acre if both values provided
    double? pricePerAcre;
    if (price != null && acreage != null && acreage > 0) {
      pricePerAcre = price / acreage;
    }

    // Insert the listing
    final listingResponse = await _client.from('land_listings').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'description': description,
      'state': stateCode,
      'county': county ?? stateName, // Use state name if no county
      'acreage': acreage,
      'price_total': price,
      'price_per_acre': pricePerAcre,
      'species_tags': speciesTags,
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
          await _client.storage.from('land_photos').uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
              );

          // Insert photo record
          await _client.from('land_photos').insert({
            'listing_id': listingId,
            'storage_path': path,
            'sort_order': i,
          });
        } catch (e) {
          // Log error but continue with other photos
          if (kDebugMode) {
            debugPrint('Error uploading land listing photo $i: $e');
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
    await _client.from('land_listings').delete().eq('id', id);
  }

  /// Get public URL for a photo.
  String getPhotoUrl(String path) {
    return _client.storage.from('land_photos').getPublicUrl(path);
  }
}

/// Provider for land listing service.
final landListingServiceProvider = Provider<LandListingService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return LandListingService(supabaseService);
});

/// State for land listings with filters.
class LandListingsState {
  LandListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
    this.params,
  });

  final List<LandListing> listings;
  final bool isLoading;
  final String? error;
  final LandSearchParams? params;

  LandListingsState copyWith({
    List<LandListing>? listings,
    bool? isLoading,
    String? error,
    LandSearchParams? params,
    bool clearError = false,
  }) {
    return LandListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      params: params ?? this.params,
    );
  }
}

/// Notifier for land listings.
class LandListingsNotifier extends StateNotifier<LandListingsState> {
  LandListingsNotifier(this._service) : super(LandListingsState());

  final LandListingService _service;

  Future<void> fetchListings({LandSearchParams? params}) async {
    state = state.copyWith(isLoading: true, clearError: true, params: params);

    try {
      final listings = await _service.fetchListings(params: params);
      state = state.copyWith(listings: listings, isLoading: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LandListingsNotifier] Error: $e');
      }
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void updateParams(LandSearchParams params) {
    fetchListings(params: params);
  }

  void clearFilters() {
    fetchListings(params: LandSearchParams());
  }
}

/// Provider for land listings notifier.
final landListingsNotifierProvider =
    StateNotifierProvider<LandListingsNotifier, LandListingsState>((ref) {
  final service = ref.watch(landListingServiceProvider);
  return LandListingsNotifier(service);
});

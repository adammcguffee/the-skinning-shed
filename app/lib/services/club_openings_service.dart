import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// MODEL
// ════════════════════════════════════════════════════════════════════════════

class ClubOpening {
  const ClubOpening({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    this.rules,
    this.acres,
    this.game = const [],
    this.amenities = const [],
    this.priceCents,
    required this.pricePeriod,
    required this.stateCode,
    required this.county,
    this.nearestTown,
    required this.isAvailable,
    this.spotsAvailable,
    this.season,
    this.contactName,
    this.contactPhone,
    required this.contactPreferred,
    this.photoPaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.ownerUsername,
    this.ownerDisplayName,
    this.photoUrls = const [],
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String? rules;
  final int? acres;
  final List<String> game;
  final List<String> amenities;
  final int? priceCents;
  final String pricePeriod;
  final String stateCode;
  final String county;
  final String? nearestTown;
  final bool isAvailable;
  final int? spotsAvailable;
  final String? season;
  final String? contactName;
  final String? contactPhone;
  final String contactPreferred;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerUsername;
  final String? ownerDisplayName;
  final List<String> photoUrls;

  String get ownerName => ownerDisplayName ?? ownerUsername ?? 'Unknown';
  String get ownerHandle => ownerUsername != null ? '@$ownerUsername' : '';

  String get priceFormatted {
    if (priceCents == null) return 'Contact for price';
    final dollars = (priceCents! / 100).toStringAsFixed(priceCents! % 100 == 0 ? 0 : 2);
    final period = switch (pricePeriod) {
      'year' => '/year',
      'season' => '/season',
      'month' => '/month',
      'weekend' => '/weekend',
      'one_time' => ' (one-time)',
      _ => '',
    };
    return '\$$dollars$period';
  }

  String get locationDisplay {
    final parts = <String>[stateCode, county];
    if (nearestTown != null && nearestTown!.isNotEmpty) {
      parts.add('near $nearestTown');
    }
    return parts.join(' • ');
  }

  factory ClubOpening.fromJson(Map<String, dynamic> json, {List<String>? photoUrls}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubOpening(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      rules: json['rules'] as String?,
      acres: json['acres'] as int?,
      game: (json['game'] as List<dynamic>?)?.cast<String>() ?? [],
      amenities: (json['amenities'] as List<dynamic>?)?.cast<String>() ?? [],
      priceCents: json['price_cents'] as int?,
      pricePeriod: json['price_period'] as String,
      stateCode: json['state_code'] as String,
      county: json['county'] as String,
      nearestTown: json['nearest_town'] as String?,
      isAvailable: json['is_available'] as bool,
      spotsAvailable: json['spots_available'] as int?,
      season: json['season'] as String?,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactPreferred: json['contact_preferred'] as String,
      photoPaths: (json['photo_paths'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      ownerUsername: profile?['username'] as String?,
      ownerDisplayName: profile?['display_name'] as String?,
      photoUrls: photoUrls ?? [],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FILTER MODEL
// ════════════════════════════════════════════════════════════════════════════

class OpeningsFilter {
  const OpeningsFilter({
    this.stateCode,
    this.county,
    this.availableOnly = true,
    this.game = const [],
    this.amenities = const [],
    this.minPrice,
    this.maxPrice,
  });

  final String? stateCode;
  final String? county;
  final bool availableOnly;
  final List<String> game;
  final List<String> amenities;
  final int? minPrice;
  final int? maxPrice;

  OpeningsFilter copyWith({
    String? stateCode,
    String? county,
    bool? availableOnly,
    List<String>? game,
    List<String>? amenities,
    int? minPrice,
    int? maxPrice,
    bool clearState = false,
    bool clearCounty = false,
  }) {
    return OpeningsFilter(
      stateCode: clearState ? null : (stateCode ?? this.stateCode),
      county: clearCounty ? null : (county ?? this.county),
      availableOnly: availableOnly ?? this.availableOnly,
      game: game ?? this.game,
      amenities: amenities ?? this.amenities,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  bool get hasFilters =>
      stateCode != null ||
      county != null ||
      game.isNotEmpty ||
      amenities.isNotEmpty ||
      minPrice != null ||
      maxPrice != null;
}

// ════════════════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════════════════

class ClubOpeningsService {
  ClubOpeningsService(this._client);

  final SupabaseClient? _client;
  static const _bucket = 'club-openings';
  static const _uuid = Uuid();

  /// Get openings with optional filters
  Future<List<ClubOpening>> getOpenings({
    OpeningsFilter filter = const OpeningsFilter(),
    int limit = 25,
    int offset = 0,
  }) async {
    if (_client == null) return [];

    try {
      var query = _client
          .from('club_openings')
          .select('*, profiles:profiles!club_openings_owner_profiles_fkey(username, display_name)');

      // Apply filters
      if (filter.availableOnly) {
        query = query.eq('is_available', true);
      }
      if (filter.stateCode != null) {
        query = query.eq('state_code', filter.stateCode!);
      }
      if (filter.county != null) {
        query = query.eq('county', filter.county!);
      }
      if (filter.game.isNotEmpty) {
        query = query.overlaps('game', filter.game);
      }
      if (filter.amenities.isNotEmpty) {
        query = query.overlaps('amenities', filter.amenities);
      }
      if (filter.minPrice != null) {
        query = query.gte('price_cents', filter.minPrice!);
      }
      if (filter.maxPrice != null) {
        query = query.lte('price_cents', filter.maxPrice!);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final openings = <ClubOpening>[];
      for (final row in response as List) {
        final opening = ClubOpening.fromJson(row as Map<String, dynamic>);
        // Get signed URLs for photos
        final photoUrls = await _getPhotoUrls(opening.photoPaths);
        openings.add(ClubOpening.fromJson(row, photoUrls: photoUrls));
      }
      return openings;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error getting openings: $e');
      return [];
    }
  }

  /// Get a single opening by ID
  Future<ClubOpening?> getOpening(String id) async {
    if (_client == null) return null;

    try {
      final response = await _client
          .from('club_openings')
          .select('*, profiles:profiles!club_openings_owner_profiles_fkey(username, display_name)')
          .eq('id', id)
          .single();

      final opening = ClubOpening.fromJson(response);
      final photoUrls = await _getPhotoUrls(opening.photoPaths);
      return ClubOpening.fromJson(response, photoUrls: photoUrls);
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error getting opening: $e');
      return null;
    }
  }

  /// Get current user's openings
  Future<List<ClubOpening>> getMyOpenings() async {
    if (_client == null) return [];

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('club_openings')
          .select('*, profiles:profiles!club_openings_owner_profiles_fkey(username, display_name)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final openings = <ClubOpening>[];
      for (final row in response as List) {
        final opening = ClubOpening.fromJson(row as Map<String, dynamic>);
        final photoUrls = await _getPhotoUrls(opening.photoPaths);
        openings.add(ClubOpening.fromJson(row, photoUrls: photoUrls));
      }
      return openings;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error getting my openings: $e');
      return [];
    }
  }

  /// Create a new opening
  Future<ClubOpening?> createOpening({
    required String title,
    required String description,
    required String stateCode,
    required String county,
    String? rules,
    int? acres,
    List<String>? game,
    List<String>? amenities,
    int? priceCents,
    String pricePeriod = 'year',
    String? nearestTown,
    int? spotsAvailable,
    String? season,
    String? contactName,
    String? contactPhone,
    String contactPreferred = 'dm',
  }) async {
    if (_client == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client.from('club_openings').insert({
        'owner_id': userId,
        'title': title,
        'description': description,
        'state_code': stateCode,
        'county': county,
        'rules': rules,
        'acres': acres,
        'game': game,
        'amenities': amenities,
        'price_cents': priceCents,
        'price_period': pricePeriod,
        'nearest_town': nearestTown,
        'spots_available': spotsAvailable,
        'season': season,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'contact_preferred': contactPreferred,
      }).select('*, profiles:profiles!club_openings_owner_profiles_fkey(username, display_name)').single();

      return ClubOpening.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error creating opening: $e');
      return null;
    }
  }

  /// Update an opening
  Future<bool> updateOpening(
    String id, {
    String? title,
    String? description,
    String? stateCode,
    String? county,
    String? rules,
    int? acres,
    List<String>? game,
    List<String>? amenities,
    int? priceCents,
    String? pricePeriod,
    String? nearestTown,
    int? spotsAvailable,
    String? season,
    String? contactName,
    String? contactPhone,
    String? contactPreferred,
    bool? isAvailable,
    List<String>? photoPaths,
  }) async {
    if (_client == null) return false;

    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (stateCode != null) data['state_code'] = stateCode;
      if (county != null) data['county'] = county;
      if (rules != null) data['rules'] = rules;
      if (acres != null) data['acres'] = acres;
      if (game != null) data['game'] = game;
      if (amenities != null) data['amenities'] = amenities;
      if (priceCents != null) data['price_cents'] = priceCents;
      if (pricePeriod != null) data['price_period'] = pricePeriod;
      if (nearestTown != null) data['nearest_town'] = nearestTown;
      if (spotsAvailable != null) data['spots_available'] = spotsAvailable;
      if (season != null) data['season'] = season;
      if (contactName != null) data['contact_name'] = contactName;
      if (contactPhone != null) data['contact_phone'] = contactPhone;
      if (contactPreferred != null) data['contact_preferred'] = contactPreferred;
      if (isAvailable != null) data['is_available'] = isAvailable;
      if (photoPaths != null) data['photo_paths'] = photoPaths;

      await _client.from('club_openings').update(data).eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error updating opening: $e');
      return false;
    }
  }

  /// Delete an opening
  Future<bool> deleteOpening(String id) async {
    if (_client == null) return false;

    try {
      await _client.from('club_openings').delete().eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error deleting opening: $e');
      return false;
    }
  }

  /// Upload a photo for an opening
  Future<String?> uploadPhoto(String openingId, Uint8List bytes, String fileName) async {
    if (_client == null) return null;

    try {
      final photoId = _uuid.v4();
      final ext = fileName.split('.').last.toLowerCase();
      final path = 'club_openings/$openingId/$photoId.$ext';

      await _client.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );

      return path;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubOpeningsService] Error uploading photo: $e');
      return null;
    }
  }

  Future<List<String>> _getPhotoUrls(List<String> paths) async {
    if (_client == null || paths.isEmpty) return [];

    final urls = <String>[];
    for (final path in paths) {
      try {
        final url = await _client.storage.from(_bucket).createSignedUrl(path, 3600);
        urls.add(url);
      } catch (e) {
        // Skip failed URLs
      }
    }
    return urls;
  }

  /// Get available states from existing openings
  Future<List<String>> getAvailableStates() async {
    if (_client == null) return [];

    try {
      final response = await _client
          .from('club_openings')
          .select('state_code')
          .eq('is_available', true);

      final states = <String>{};
      for (final row in response as List) {
        final state = row['state_code'] as String?;
        if (state != null) states.add(state);
      }
      return states.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  /// Get available counties for a state
  Future<List<String>> getAvailableCounties(String stateCode) async {
    if (_client == null) return [];

    try {
      final response = await _client
          .from('club_openings')
          .select('county')
          .eq('state_code', stateCode)
          .eq('is_available', true);

      final counties = <String>{};
      for (final row in response as List) {
        final county = row['county'] as String?;
        if (county != null) counties.add(county);
      }
      return counties.toList()..sort();
    } catch (e) {
      return [];
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

final clubOpeningsServiceProvider = Provider<ClubOpeningsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ClubOpeningsService(client);
});

final openingsFilterProvider = StateProvider<OpeningsFilter>((ref) => const OpeningsFilter());

final openingsProvider = FutureProvider.autoDispose<List<ClubOpening>>((ref) async {
  final service = ref.watch(clubOpeningsServiceProvider);
  final filter = ref.watch(openingsFilterProvider);
  return service.getOpenings(filter: filter);
});

final openingDetailProvider = FutureProvider.autoDispose.family<ClubOpening?, String>((ref, id) async {
  final service = ref.watch(clubOpeningsServiceProvider);
  return service.getOpening(id);
});

final myOpeningsProvider = FutureProvider.autoDispose<List<ClubOpening>>((ref) async {
  final service = ref.watch(clubOpeningsServiceProvider);
  return service.getMyOpenings();
});

final availableStatesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final service = ref.watch(clubOpeningsServiceProvider);
  return service.getAvailableStates();
});

final availableCountiesProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, stateCode) async {
  final service = ref.watch(clubOpeningsServiceProvider);
  return service.getAvailableCounties(stateCode);
});

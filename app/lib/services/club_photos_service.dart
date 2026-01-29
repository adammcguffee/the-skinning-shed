import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// MODELS
// ════════════════════════════════════════════════════════════════════════════

/// Club photo model
class ClubPhoto {
  const ClubPhoto({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.storageBucket,
    required this.storagePath,
    this.thumbPath,
    this.mediumPath,
    this.caption,
    this.takenAt,
    this.cameraLabel,
    required this.createdAt,
    this.authorName,
    this.authorUsername,
    this.signedUrl,
    this.thumbSignedUrl,
    this.mediumSignedUrl,
    this.linkedBucks = const [],
  });

  final String id;
  final String clubId;
  final String authorId;
  final String storageBucket;
  final String storagePath;
  final String? thumbPath;
  final String? mediumPath;
  final String? caption;
  final DateTime? takenAt;
  final String? cameraLabel;
  final DateTime createdAt;
  final String? authorName;
  final String? authorUsername;
  final String? signedUrl;
  final String? thumbSignedUrl;
  final String? mediumSignedUrl;
  final List<BuckProfileSummary> linkedBucks;
  
  /// Get the best URL for feed/grid display (thumb preferred)
  String? get feedUrl => thumbSignedUrl ?? signedUrl;
  
  /// Get the best URL for detail display (medium preferred)
  String? get detailUrl => mediumSignedUrl ?? signedUrl;

  String get displayDate {
    final date = takenAt ?? createdAt;
    return '${date.month}/${date.day}/${date.year}';
  }

  factory ClubPhoto.fromJson(
    Map<String, dynamic> json, {
    String? signedUrl, 
    String? thumbSignedUrl,
    String? mediumSignedUrl,
    List<BuckProfileSummary>? linkedBucks,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubPhoto(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      authorId: json['author_id'] as String,
      storageBucket: json['storage_bucket'] as String,
      storagePath: json['storage_path'] as String,
      thumbPath: json['thumb_path'] as String?,
      mediumPath: json['medium_path'] as String?,
      caption: json['caption'] as String?,
      takenAt: json['taken_at'] != null ? DateTime.parse(json['taken_at'] as String) : null,
      cameraLabel: json['camera_label'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: profile?['display_name'] as String? ?? profile?['username'] as String?,
      authorUsername: profile?['username'] as String?,
      signedUrl: signedUrl,
      thumbSignedUrl: thumbSignedUrl,
      mediumSignedUrl: mediumSignedUrl,
      linkedBucks: linkedBucks ?? [],
    );
  }
}

/// Buck profile model
class BuckProfile {
  const BuckProfile({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.name,
    this.notes,
    required this.status,
    required this.createdAt,
    this.creatorName,
    this.shooterVotes = 0,
    this.cullVotes = 0,
    this.letWalkVotes = 0,
    this.myVote,
    this.photoCount = 0,
    this.latestPhotoUrl,
  });

  final String id;
  final String clubId;
  final String createdBy;
  final String name;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final String? creatorName;
  final int shooterVotes;
  final int cullVotes;
  final int letWalkVotes;
  final String? myVote;
  final int photoCount;
  final String? latestPhotoUrl;

  int get totalVotes => shooterVotes + cullVotes + letWalkVotes;

  String? get consensusVote {
    if (totalVotes == 0) return null;
    if (shooterVotes >= cullVotes && shooterVotes >= letWalkVotes) return 'shooter';
    if (cullVotes >= shooterVotes && cullVotes >= letWalkVotes) return 'cull';
    return 'let_walk';
  }

  factory BuckProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return BuckProfile(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      createdBy: json['created_by'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      creatorName: profile?['display_name'] as String? ?? profile?['username'] as String?,
      shooterVotes: json['shooter_votes'] as int? ?? 0,
      cullVotes: json['cull_votes'] as int? ?? 0,
      letWalkVotes: json['let_walk_votes'] as int? ?? 0,
      myVote: json['my_vote'] as String?,
      photoCount: json['photo_count'] as int? ?? 0,
      latestPhotoUrl: json['latest_photo_url'] as String?,
    );
  }
}

/// Lightweight buck summary for photo cards
class BuckProfileSummary {
  const BuckProfileSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory BuckProfileSummary.fromJson(Map<String, dynamic> json) {
    return BuckProfileSummary(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

/// Vote counts for a buck
class BuckVoteSummary {
  const BuckVoteSummary({
    required this.shooterVotes,
    required this.cullVotes,
    required this.letWalkVotes,
    this.myVote,
  });

  final int shooterVotes;
  final int cullVotes;
  final int letWalkVotes;
  final String? myVote;

  int get total => shooterVotes + cullVotes + letWalkVotes;
}

// ════════════════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════════════════

class ClubPhotosService {
  ClubPhotosService(this._client);

  final SupabaseClient? _client;
  static const _bucket = 'club-photos';
  static const _uuid = Uuid();

  // ──────────────────────────────────────────────────────────────────────────
  // PHOTOS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get photos for a club with signed URLs (including thumbnails when available)
  Future<List<ClubPhoto>> getPhotos(String clubId, {int limit = 50, int offset = 0}) async {
    if (_client == null) return [];

    try {
      final response = await _client
          .from('club_photos')
          .select('*, profiles:profiles!club_photos_author_profiles_fkey(username, display_name)')
          .eq('club_id', clubId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final photos = <ClubPhoto>[];
      for (final row in response as List) {
        final photo = ClubPhoto.fromJson(row as Map<String, dynamic>);
        // Get signed URLs (original + variants when available)
        final signedUrl = await _getSignedUrl(photo.storagePath);
        final thumbSignedUrl = photo.thumbPath != null 
            ? await _getSignedUrl(photo.thumbPath!) 
            : null;
        final mediumSignedUrl = photo.mediumPath != null 
            ? await _getSignedUrl(photo.mediumPath!) 
            : null;
        // Get linked bucks
        final bucks = await _getLinkedBucks(photo.id);
        photos.add(ClubPhoto.fromJson(
          row, 
          signedUrl: signedUrl, 
          thumbSignedUrl: thumbSignedUrl,
          mediumSignedUrl: mediumSignedUrl,
          linkedBucks: bucks,
        ));
      }
      return photos;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error getting photos: $e');
      return [];
    }
  }

  /// Get photos linked to a specific buck
  Future<List<ClubPhoto>> getBuckPhotos(String buckId) async {
    if (_client == null) return [];

    try {
      // Get photo IDs linked to this buck
      final linksResponse = await _client
          .from('club_buck_photo_links')
          .select('photo_id')
          .eq('buck_id', buckId);

      final photoIds = (linksResponse as List).map((r) => r['photo_id'] as String).toList();
      if (photoIds.isEmpty) return [];

      final response = await _client
          .from('club_photos')
          .select('*, profiles:profiles!club_photos_author_profiles_fkey(username, display_name)')
          .inFilter('id', photoIds)
          .order('created_at', ascending: false);

      final photos = <ClubPhoto>[];
      for (final row in response as List) {
        final photo = ClubPhoto.fromJson(row as Map<String, dynamic>);
        final signedUrl = await _getSignedUrl(photo.storagePath);
        final thumbSignedUrl = photo.thumbPath != null 
            ? await _getSignedUrl(photo.thumbPath!) 
            : null;
        final mediumSignedUrl = photo.mediumPath != null 
            ? await _getSignedUrl(photo.mediumPath!) 
            : null;
        photos.add(ClubPhoto.fromJson(
          row, 
          signedUrl: signedUrl,
          thumbSignedUrl: thumbSignedUrl,
          mediumSignedUrl: mediumSignedUrl,
        ));
      }
      return photos;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error getting buck photos: $e');
      return [];
    }
  }

  /// Upload a photo
  Future<ClubPhoto?> uploadPhoto({
    required String clubId,
    required Uint8List imageBytes,
    required String fileName,
    String? caption,
    DateTime? takenAt,
    String? cameraLabel,
  }) async {
    if (_client == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final photoId = _uuid.v4();
      final ext = fileName.split('.').last.toLowerCase();
      final storagePath = 'clubs/$clubId/trailcam/$photoId.$ext';

      // Upload to storage
      await _client.storage.from(_bucket).uploadBinary(
        storagePath,
        imageBytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: false,
        ),
      );

      // Insert DB row
      final response = await _client.from('club_photos').insert({
        'id': photoId,
        'club_id': clubId,
        'author_id': userId,
        'storage_bucket': _bucket,
        'storage_path': storagePath,
        'caption': caption,
        'taken_at': takenAt?.toIso8601String(),
        'camera_label': cameraLabel,
      }).select('*, profiles:profiles!club_photos_author_profiles_fkey(username, display_name)').single();

      final signedUrl = await _getSignedUrl(storagePath);
      
      // Trigger thumbnail generation (fire-and-forget, non-blocking)
      _generateThumbnails(photoId, storagePath);
      
      return ClubPhoto.fromJson(response, signedUrl: signedUrl);
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error uploading photo: $e');
      return null;
    }
  }
  
  /// Generate thumbnail variants for a photo (fire-and-forget)
  void _generateThumbnails(String photoId, String storagePath) {
    if (_client == null) return;
    
    // Fire-and-forget: don't await, don't block the upload
    Future.microtask(() async {
      try {
        await _client.functions.invoke(
          'image-variants',
          body: {
            'bucket': _bucket,
            'path': storagePath,
            'recordType': 'club_photos',
            'recordId': photoId,
          },
        );
        if (kDebugMode) debugPrint('[ClubPhotosService] Thumbnail generation triggered for $photoId');
      } catch (e) {
        // Don't fail - thumbnails are optional enhancement
        if (kDebugMode) debugPrint('[ClubPhotosService] Thumbnail generation error (non-fatal): $e');
      }
    });
  }

  /// Update photo metadata
  Future<bool> updatePhoto(String photoId, {String? caption, DateTime? takenAt, String? cameraLabel}) async {
    if (_client == null) return false;

    try {
      final data = <String, dynamic>{};
      if (caption != null) data['caption'] = caption;
      if (takenAt != null) data['taken_at'] = takenAt.toIso8601String();
      if (cameraLabel != null) data['camera_label'] = cameraLabel;

      await _client.from('club_photos').update(data).eq('id', photoId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error updating photo: $e');
      return false;
    }
  }

  /// Delete a photo
  Future<bool> deletePhoto(String photoId, String storagePath) async {
    if (_client == null) return false;

    try {
      // Delete from storage
      await _client.storage.from(_bucket).remove([storagePath]);
      // Delete DB row (cascades to links)
      await _client.from('club_photos').delete().eq('id', photoId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error deleting photo: $e');
      return false;
    }
  }

  Future<String?> _getSignedUrl(String path) async {
    if (_client == null) return null;
    try {
      final result = await _client.storage.from(_bucket).createSignedUrl(path, 3600);
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<List<BuckProfileSummary>> _getLinkedBucks(String photoId) async {
    if (_client == null) return [];
    try {
      final response = await _client
          .from('club_buck_photo_links')
          .select('buck_id, club_buck_profiles!inner(id, name)')
          .eq('photo_id', photoId);

      return (response as List).map((r) {
        final buck = r['club_buck_profiles'] as Map<String, dynamic>;
        return BuckProfileSummary.fromJson(buck);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get unique camera labels for a club
  Future<List<String>> getCameraLabels(String clubId) async {
    if (_client == null) return [];

    try {
      final response = await _client
          .from('club_photos')
          .select('camera_label')
          .eq('club_id', clubId)
          .not('camera_label', 'is', null);

      final labels = <String>{};
      for (final row in response as List) {
        final label = row['camera_label'] as String?;
        if (label != null && label.isNotEmpty) labels.add(label);
      }
      return labels.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUCK PROFILES (TARGETS)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get all buck profiles for a club with vote summaries
  Future<List<BuckProfile>> getBuckProfiles(String clubId) async {
    if (_client == null) return [];

    final userId = _client.auth.currentUser?.id;

    try {
      final response = await _client
          .from('club_buck_profiles')
          .select('*, profiles:profiles!club_buck_profiles_creator_profiles_fkey(username, display_name)')
          .eq('club_id', clubId)
          .order('name');

      final bucks = <BuckProfile>[];
      for (final row in response as List) {
        final buckId = row['id'] as String;

        // Get vote counts
        final voteCounts = await _getVoteCounts(buckId);

        // Get my vote
        String? myVote;
        if (userId != null) {
          final myVoteResponse = await _client
              .from('club_buck_votes')
              .select('vote')
              .eq('buck_id', buckId)
              .eq('user_id', userId)
              .maybeSingle();
          myVote = myVoteResponse?['vote'] as String?;
        }

        // Get photo count and latest photo
        final photoCountResp = await _client
            .from('club_buck_photo_links')
            .select('photo_id')
            .eq('buck_id', buckId);
        final photoCount = (photoCountResp as List).length;

        String? latestPhotoUrl;
        if (photoCount > 0) {
          final latestPhotoResp = await _client
              .from('club_buck_photo_links')
              .select('club_photos!inner(storage_path)')
              .eq('buck_id', buckId)
              .order('created_at', ascending: false)
              .limit(1);
          if ((latestPhotoResp as List).isNotEmpty) {
            final path = latestPhotoResp[0]['club_photos']['storage_path'] as String;
            latestPhotoUrl = await _getSignedUrl(path);
          }
        }

        final buckJson = Map<String, dynamic>.from(row as Map);
        buckJson['shooter_votes'] = voteCounts['shooter'] ?? 0;
        buckJson['cull_votes'] = voteCounts['cull'] ?? 0;
        buckJson['let_walk_votes'] = voteCounts['let_walk'] ?? 0;
        buckJson['my_vote'] = myVote;
        buckJson['photo_count'] = photoCount;
        buckJson['latest_photo_url'] = latestPhotoUrl;

        bucks.add(BuckProfile.fromJson(buckJson));
      }
      return bucks;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error getting buck profiles: $e');
      return [];
    }
  }

  Future<Map<String, int>> _getVoteCounts(String buckId) async {
    if (_client == null) return {};
    try {
      final response = await _client
          .from('club_buck_votes')
          .select('vote')
          .eq('buck_id', buckId);

      final counts = <String, int>{'shooter': 0, 'cull': 0, 'let_walk': 0};
      for (final row in response as List) {
        final vote = row['vote'] as String;
        counts[vote] = (counts[vote] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  /// Create a new buck profile
  Future<BuckProfile?> createBuckProfile(String clubId, String name, {String? notes}) async {
    if (_client == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client.from('club_buck_profiles').insert({
        'club_id': clubId,
        'created_by': userId,
        'name': name.trim(),
        'notes': notes,
      }).select('*, profiles:profiles!club_buck_profiles_creator_profiles_fkey(username, display_name)').single();

      return BuckProfile.fromJson(response);
    } on PostgrestException catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error creating buck: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error creating buck: $e');
      return null;
    }
  }

  /// Update a buck profile
  Future<bool> updateBuckProfile(String buckId, {String? name, String? notes, String? status}) async {
    if (_client == null) return false;

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name.trim();
      if (notes != null) data['notes'] = notes;
      if (status != null) data['status'] = status;

      await _client.from('club_buck_profiles').update(data).eq('id', buckId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error updating buck: $e');
      return false;
    }
  }

  /// Delete a buck profile
  Future<bool> deleteBuckProfile(String buckId) async {
    if (_client == null) return false;

    try {
      await _client.from('club_buck_profiles').delete().eq('id', buckId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error deleting buck: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHOTO-BUCK LINKING
  // ──────────────────────────────────────────────────────────────────────────

  /// Link a photo to a buck profile
  Future<bool> linkPhotoToBuck(String clubId, String photoId, String buckId) async {
    if (_client == null) return false;

    try {
      await _client.from('club_buck_photo_links').insert({
        'club_id': clubId,
        'photo_id': photoId,
        'buck_id': buckId,
      });
      return true;
    } on PostgrestException catch (e) {
      // Ignore duplicate key errors
      if (e.code == '23505') return true;
      if (kDebugMode) debugPrint('[ClubPhotosService] Error linking photo: ${e.message}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error linking photo: $e');
      return false;
    }
  }

  /// Unlink a photo from a buck profile
  Future<bool> unlinkPhotoFromBuck(String photoId, String buckId) async {
    if (_client == null) return false;

    try {
      await _client
          .from('club_buck_photo_links')
          .delete()
          .eq('photo_id', photoId)
          .eq('buck_id', buckId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error unlinking photo: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VOTING
  // ──────────────────────────────────────────────────────────────────────────

  /// Cast or update vote for a buck
  Future<bool> vote(String clubId, String buckId, String vote) async {
    if (_client == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _client.from('club_buck_votes').upsert({
        'club_id': clubId,
        'buck_id': buckId,
        'user_id': userId,
        'vote': vote,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error voting: $e');
      return false;
    }
  }

  /// Remove vote for a buck
  Future<bool> removeVote(String buckId) async {
    if (_client == null) return false;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _client
          .from('club_buck_votes')
          .delete()
          .eq('buck_id', buckId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubPhotosService] Error removing vote: $e');
      return false;
    }
  }

  /// Get vote summary for a buck
  Future<BuckVoteSummary> getVoteSummary(String buckId) async {
    final counts = await _getVoteCounts(buckId);

    String? myVote;
    if (_client != null) {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final response = await _client
            .from('club_buck_votes')
            .select('vote')
            .eq('buck_id', buckId)
            .eq('user_id', userId)
            .maybeSingle();
        myVote = response?['vote'] as String?;
      }
    }

    return BuckVoteSummary(
      shooterVotes: counts['shooter'] ?? 0,
      cullVotes: counts['cull'] ?? 0,
      letWalkVotes: counts['let_walk'] ?? 0,
      myVote: myVote,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

final clubPhotosServiceProvider = Provider<ClubPhotosService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ClubPhotosService(client);
});

final clubPhotosProvider = FutureProvider.autoDispose.family<List<ClubPhoto>, String>((ref, clubId) async {
  final service = ref.watch(clubPhotosServiceProvider);
  return service.getPhotos(clubId);
});

final buckPhotosProvider = FutureProvider.autoDispose.family<List<ClubPhoto>, String>((ref, buckId) async {
  final service = ref.watch(clubPhotosServiceProvider);
  return service.getBuckPhotos(buckId);
});

final buckProfilesProvider = FutureProvider.autoDispose.family<List<BuckProfile>, String>((ref, clubId) async {
  final service = ref.watch(clubPhotosServiceProvider);
  return service.getBuckProfiles(clubId);
});

final cameraLabelsProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, clubId) async {
  final service = ref.watch(clubPhotosServiceProvider);
  return service.getCameraLabels(clubId);
});

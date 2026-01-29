import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// OPENING ALERT MODEL
// ════════════════════════════════════════════════════════════════════════════

class OpeningAlert {
  const OpeningAlert({
    required this.id,
    required this.userId,
    required this.stateCode,
    this.county,
    required this.availableOnly,
    this.minPriceCents,
    this.maxPriceCents,
    this.game = const [],
    this.amenities = const [],
    required this.notifyPush,
    required this.notifyInApp,
    required this.isEnabled,
    this.lastNotifiedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String stateCode;
  final String? county;
  final bool availableOnly;
  final int? minPriceCents;
  final int? maxPriceCents;
  final List<String> game;
  final List<String> amenities;
  final bool notifyPush;
  final bool notifyInApp;
  final bool isEnabled;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;

  String get locationDisplay {
    if (county != null && county!.isNotEmpty) {
      return '$county, $stateCode';
    }
    return stateCode;
  }

  factory OpeningAlert.fromJson(Map<String, dynamic> json) {
    return OpeningAlert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stateCode: json['state_code'] as String,
      county: json['county'] as String?,
      availableOnly: json['available_only'] as bool? ?? true,
      minPriceCents: json['min_price_cents'] as int?,
      maxPriceCents: json['max_price_cents'] as int?,
      game: (json['game'] as List<dynamic>?)?.cast<String>() ?? [],
      amenities: (json['amenities'] as List<dynamic>?)?.cast<String>() ?? [],
      notifyPush: json['notify_push'] as bool? ?? true,
      notifyInApp: json['notify_in_app'] as bool? ?? true,
      isEnabled: json['is_enabled'] as bool? ?? true,
      lastNotifiedAt: json['last_notified_at'] != null 
          ? DateTime.parse(json['last_notified_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════════════════

class OpeningAlertsService {
  OpeningAlertsService(this._client);

  final SupabaseClient? _client;

  /// Get all alerts for current user
  Future<List<OpeningAlert>> getMyAlerts() async {
    if (_client == null) return [];

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('opening_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => OpeningAlert.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error getting alerts: $e');
      return [];
    }
  }

  /// Get alert for specific location (if exists)
  Future<OpeningAlert?> getAlertForLocation(String stateCode, String? county) async {
    if (_client == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      var query = _client
          .from('opening_alerts')
          .select()
          .eq('user_id', userId)
          .eq('state_code', stateCode);

      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      } else {
        query = query.isFilter('county', null);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;
      return OpeningAlert.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error getting alert: $e');
      return null;
    }
  }

  /// Create a new alert
  Future<OpeningAlert?> createAlert({
    required String stateCode,
    String? county,
    bool availableOnly = true,
    int? minPriceCents,
    int? maxPriceCents,
    List<String>? game,
    List<String>? amenities,
    bool notifyPush = true,
    bool notifyInApp = true,
  }) async {
    if (_client == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client.from('opening_alerts').insert({
        'user_id': userId,
        'state_code': stateCode,
        'county': county?.isNotEmpty == true ? county : null,
        'available_only': availableOnly,
        'min_price_cents': minPriceCents,
        'max_price_cents': maxPriceCents,
        'game': game?.isNotEmpty == true ? game : null,
        'amenities': amenities?.isNotEmpty == true ? amenities : null,
        'notify_push': notifyPush,
        'notify_in_app': notifyInApp,
      }).select().single();

      return OpeningAlert.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error creating alert: $e');
      return null;
    }
  }

  /// Update an alert
  Future<bool> updateAlert(
    String alertId, {
    String? county,
    bool? availableOnly,
    int? minPriceCents,
    int? maxPriceCents,
    List<String>? game,
    List<String>? amenities,
    bool? notifyPush,
    bool? notifyInApp,
    bool? isEnabled,
  }) async {
    if (_client == null) return false;

    try {
      final data = <String, dynamic>{};
      if (county != null) data['county'] = county.isNotEmpty ? county : null;
      if (availableOnly != null) data['available_only'] = availableOnly;
      if (minPriceCents != null) data['min_price_cents'] = minPriceCents;
      if (maxPriceCents != null) data['max_price_cents'] = maxPriceCents;
      if (game != null) data['game'] = game.isNotEmpty ? game : null;
      if (amenities != null) data['amenities'] = amenities.isNotEmpty ? amenities : null;
      if (notifyPush != null) data['notify_push'] = notifyPush;
      if (notifyInApp != null) data['notify_in_app'] = notifyInApp;
      if (isEnabled != null) data['is_enabled'] = isEnabled;

      await _client.from('opening_alerts').update(data).eq('id', alertId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error updating alert: $e');
      return false;
    }
  }

  /// Delete an alert
  Future<bool> deleteAlert(String alertId) async {
    if (_client == null) return false;

    try {
      await _client.from('opening_alerts').delete().eq('id', alertId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error deleting alert: $e');
      return false;
    }
  }

  /// Toggle alert enabled state
  Future<bool> toggleAlert(String alertId, bool enabled) async {
    return updateAlert(alertId, isEnabled: enabled);
  }

  /// Trigger notification for a new opening (call from client after creating opening)
  Future<void> notifyForOpening(String openingId) async {
    if (_client == null) return;

    try {
      // Call the edge function
      await _client.functions.invoke(
        'openings-notify',
        body: {'openingId': openingId},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[OpeningAlertsService] Error triggering notify: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

final openingAlertsServiceProvider = Provider<OpeningAlertsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OpeningAlertsService(client);
});

final myOpeningAlertsProvider = FutureProvider.autoDispose<List<OpeningAlert>>((ref) async {
  final service = ref.watch(openingAlertsServiceProvider);
  return service.getMyAlerts();
});

final alertForLocationProvider = FutureProvider.autoDispose.family<OpeningAlert?, (String, String?)>(
  (ref, args) async {
    final (stateCode, county) = args;
    final service = ref.watch(openingAlertsServiceProvider);
    return service.getAlertForLocation(stateCode, county);
  },
);

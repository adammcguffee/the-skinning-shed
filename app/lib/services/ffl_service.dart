import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// FFL DEALER MODEL
// ════════════════════════════════════════════════════════════════════════════

class FFLDealer {
  const FFLDealer({
    required this.id,
    this.licenseNumber,
    required this.licenseName,
    this.licenseType,
    required this.premiseStreet,
    required this.premiseCity,
    required this.premiseState,
    required this.premiseZip,
    required this.premiseCounty,
    this.phone,
  });

  final String id;
  final String? licenseNumber;
  final String licenseName;
  final String? licenseType;
  final String premiseStreet;
  final String premiseCity;
  final String premiseState;
  final String premiseZip;
  final String premiseCounty;
  final String? phone;

  String get fullAddress => '$premiseStreet, $premiseCity, $premiseState $premiseZip';

  String get shortAddress => '$premiseCity, $premiseState $premiseZip';

  String get locationDisplay => '$premiseCity, $premiseCounty, $premiseState';

  String get mapsUrl => Uri.encodeFull(
    'https://maps.google.com/?q=$premiseStreet, $premiseCity, $premiseState $premiseZip'
  );

  factory FFLDealer.fromJson(Map<String, dynamic> json) {
    return FFLDealer(
      id: json['id'] as String,
      licenseNumber: json['license_number'] as String?,
      licenseName: json['license_name'] as String,
      licenseType: json['license_type'] as String?,
      premiseStreet: json['premise_street'] as String,
      premiseCity: json['premise_city'] as String,
      premiseState: json['premise_state'] as String,
      premiseZip: json['premise_zip'] as String,
      premiseCounty: json['premise_county'] as String,
      phone: json['phone'] as String?,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FFL IMPORT RUN MODEL
// ════════════════════════════════════════════════════════════════════════════

class FFLImportRun {
  const FFLImportRun({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    this.rowsTotal,
    this.rowsInserted,
    this.rowsUpdated,
    this.rowsSkipped,
    this.error,
    required this.startedAt,
    this.finishedAt,
  });

  final String id;
  final int year;
  final int month;
  final String status;
  final int? rowsTotal;
  final int? rowsInserted;
  final int? rowsUpdated;
  final int? rowsSkipped;
  final String? error;
  final DateTime startedAt;
  final DateTime? finishedAt;

  String get monthLabel {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[month - 1]} $year';
  }

  factory FFLImportRun.fromJson(Map<String, dynamic> json) {
    return FFLImportRun(
      id: json['id'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      status: json['status'] as String,
      rowsTotal: json['rows_total'] as int?,
      rowsInserted: json['rows_inserted'] as int?,
      rowsUpdated: json['rows_updated'] as int?,
      rowsSkipped: json['rows_skipped'] as int?,
      error: json['error'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FFL FILTER MODEL
// ════════════════════════════════════════════════════════════════════════════

class FFLFilter {
  const FFLFilter({
    this.state,
    this.county,
    this.city,
    this.searchQuery,
  });

  final String? state;
  final String? county;
  final String? city;
  final String? searchQuery;

  FFLFilter copyWith({
    String? state,
    String? county,
    String? city,
    String? searchQuery,
    bool clearCounty = false,
    bool clearCity = false,
    bool clearSearch = false,
  }) {
    return FFLFilter(
      state: state ?? this.state,
      county: clearCounty ? null : (county ?? this.county),
      city: clearCity ? null : (city ?? this.city),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }

  bool get hasFilters => state != null || county != null || city != null || 
      (searchQuery != null && searchQuery!.isNotEmpty);

  bool get canQuery => state != null;
}

// ════════════════════════════════════════════════════════════════════════════
// STATE/COUNTY MODELS
// ════════════════════════════════════════════════════════════════════════════

class FFLStateOption {
  const FFLStateOption({required this.state, required this.dealerCount});
  final String state;
  final int dealerCount;
}

class FFLCountyOption {
  const FFLCountyOption({required this.county, required this.dealerCount});
  final String county;
  final int dealerCount;
}

class FFLCityOption {
  const FFLCityOption({required this.city, required this.dealerCount});
  final String city;
  final int dealerCount;
}

// ════════════════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════════════════

class FFLService {
  FFLService(this._client);

  final SupabaseClient? _client;

  /// Get states with FFL dealers
  Future<List<FFLStateOption>> getStates() async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc('get_ffl_states');
      
      return (response as List).map((row) => FFLStateOption(
        state: row['state'] as String,
        dealerCount: (row['dealer_count'] as num).toInt(),
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting states: $e');
      return [];
    }
  }

  /// Get counties for a state
  Future<List<FFLCountyOption>> getCounties(String state) async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc('get_ffl_counties', params: {
        'p_state': state.toUpperCase(),
      });
      
      return (response as List).map((row) => FFLCountyOption(
        county: row['county'] as String,
        dealerCount: (row['dealer_count'] as num).toInt(),
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting counties: $e');
      return [];
    }
  }

  /// Get cities for a state and county
  Future<List<FFLCityOption>> getCities(String state, String county) async {
    if (_client == null) return [];

    try {
      final response = await _client.rpc('get_ffl_cities', params: {
        'p_state': state.toUpperCase(),
        'p_county': county,
      });
      
      return (response as List).map((row) => FFLCityOption(
        city: row['city'] as String,
        dealerCount: (row['dealer_count'] as num).toInt(),
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting cities: $e');
      return [];
    }
  }

  /// Search FFL dealers with filters
  Future<List<FFLDealer>> searchDealers({
    required FFLFilter filter,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_client == null) return [];
    if (filter.state == null) return [];

    try {
      var query = _client
          .from('ffl_dealers')
          .select()
          .eq('premise_state', filter.state!.toUpperCase());

      if (filter.county != null) {
        query = query.eq('premise_county', filter.county!);
      }

      if (filter.city != null) {
        query = query.eq('premise_city', filter.city!);
      }

      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        query = query.ilike('license_name', '%${filter.searchQuery}%');
      }

      final response = await query
          .order('license_name', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((row) => FFLDealer.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error searching dealers: $e');
      return [];
    }
  }

  /// Get total count for current filter
  Future<int> getDealerCount(FFLFilter filter) async {
    if (_client == null) return 0;
    if (filter.state == null) return 0;

    try {
      var query = _client
          .from('ffl_dealers')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('premise_state', filter.state!.toUpperCase());

      if (filter.county != null) {
        query = query.eq('premise_county', filter.county!);
      }

      if (filter.city != null) {
        query = query.eq('premise_city', filter.city!);
      }

      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        query = query.ilike('license_name', '%${filter.searchQuery}%');
      }

      final response = await query;
      return response.count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting count: $e');
      return 0;
    }
  }

  /// Get latest import run info
  Future<FFLImportRun?> getLatestImportRun() async {
    if (_client == null) return null;

    try {
      final response = await _client
          .from('ffl_import_runs')
          .select()
          .eq('status', 'success')
          .order('finished_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return FFLImportRun.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting import run: $e');
      return null;
    }
  }

  /// Get all import runs (for admin)
  Future<List<FFLImportRun>> getImportRuns({int limit = 10}) async {
    if (_client == null) return [];

    try {
      final response = await _client
          .from('ffl_import_runs')
          .select()
          .order('started_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => FFLImportRun.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error getting import runs: $e');
      return [];
    }
  }

  /// Trigger manual import (admin only)
  Future<bool> triggerManualImport() async {
    if (_client == null) return false;

    try {
      final result = await _client.rpc('trigger_ffl_import_manual');
      return result['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('[FFLService] Error triggering import: $e');
      return false;
    }
  }

  /// Open address in maps
  Future<void> openInMaps(FFLDealer dealer) async {
    final uri = Uri.parse(dealer.mapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Call phone number
  Future<void> callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

final fflServiceProvider = Provider<FFLService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return FFLService(client);
});

final fflFilterProvider = StateProvider<FFLFilter>((ref) => const FFLFilter());

final fflStatesProvider = FutureProvider.autoDispose<List<FFLStateOption>>((ref) async {
  final service = ref.watch(fflServiceProvider);
  return service.getStates();
});

final fflCountiesProvider = FutureProvider.autoDispose.family<List<FFLCountyOption>, String?>((ref, state) async {
  if (state == null) return [];
  final service = ref.watch(fflServiceProvider);
  return service.getCounties(state);
});

final fflCitiesProvider = FutureProvider.autoDispose.family<List<FFLCityOption>, (String, String)>((ref, args) async {
  final (state, county) = args;
  final service = ref.watch(fflServiceProvider);
  return service.getCities(state, county);
});

final fflDealersProvider = FutureProvider.autoDispose<List<FFLDealer>>((ref) async {
  final service = ref.watch(fflServiceProvider);
  final filter = ref.watch(fflFilterProvider);
  return service.searchDealers(filter: filter);
});

final fflDealerCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(fflServiceProvider);
  final filter = ref.watch(fflFilterProvider);
  return service.getDealerCount(filter);
});

final fflLatestImportProvider = FutureProvider.autoDispose<FFLImportRun?>((ref) async {
  final service = ref.watch(fflServiceProvider);
  return service.getLatestImportRun();
});

final fflImportRunsProvider = FutureProvider.autoDispose<List<FFLImportRun>>((ref) async {
  final service = ref.watch(fflServiceProvider);
  return service.getImportRuns();
});

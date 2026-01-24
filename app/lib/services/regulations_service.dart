import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/services/supabase_service.dart';

/// Regulation category types.
enum RegulationCategory {
  deer,
  turkey,
  fishing,
}

extension RegulationCategoryX on RegulationCategory {
  String get value {
    switch (this) {
      case RegulationCategory.deer:
        return 'deer';
      case RegulationCategory.turkey:
        return 'turkey';
      case RegulationCategory.fishing:
        return 'fishing';
    }
  }
  
  String get label {
    switch (this) {
      case RegulationCategory.deer:
        return 'Deer';
      case RegulationCategory.turkey:
        return 'Turkey';
      case RegulationCategory.fishing:
        return 'Fishing';
    }
  }
}

/// Season date range.
class SeasonDateRange {
  const SeasonDateRange({
    required this.name,
    this.startDate,
    this.endDate,
    this.notes,
  });
  
  final String name;
  final String? startDate;
  final String? endDate;
  final String? notes;
  
  factory SeasonDateRange.fromJson(Map<String, dynamic> json) {
    return SeasonDateRange(
      name: json['name'] as String? ?? '',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// Bag limit entry.
class BagLimit {
  const BagLimit({
    required this.species,
    this.daily,
    this.possession,
    this.season,
    this.notes,
  });
  
  final String species;
  final String? daily;
  final String? possession;
  final String? season;
  final String? notes;
  
  factory BagLimit.fromJson(Map<String, dynamic> json) {
    return BagLimit(
      species: json['species'] as String? ?? '',
      daily: json['daily'] as String?,
      possession: json['possession'] as String?,
      season: json['season'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// Weapon/method entry.
class WeaponMethod {
  const WeaponMethod({
    required this.name,
    this.allowed,
    this.restrictions,
  });
  
  final String name;
  final bool? allowed;
  final String? restrictions;
  
  factory WeaponMethod.fromJson(Map<String, dynamic> json) {
    return WeaponMethod(
      name: json['name'] as String? ?? '',
      allowed: json['allowed'] as bool?,
      restrictions: json['restrictions'] as String?,
    );
  }
}

/// Regulation summary data.
class RegulationSummary {
  const RegulationSummary({
    this.seasons = const [],
    this.bagLimits = const [],
    this.weapons = const [],
    this.notes = const [],
  });
  
  final List<SeasonDateRange> seasons;
  final List<BagLimit> bagLimits;
  final List<WeaponMethod> weapons;
  final List<String> notes;
  
  factory RegulationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RegulationSummary();
    
    return RegulationSummary(
      seasons: (json['seasons'] as List<dynamic>?)
          ?.map((e) => SeasonDateRange.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      bagLimits: (json['bag_limits'] as List<dynamic>?)
          ?.map((e) => BagLimit.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      weapons: (json['weapons'] as List<dynamic>?)
          ?.map((e) => WeaponMethod.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      notes: (json['notes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

/// Approved state regulation.
class StateRegulation {
  const StateRegulation({
    required this.id,
    required this.stateCode,
    required this.category,
    required this.seasonYearLabel,
    required this.yearStart,
    this.yearEnd,
    required this.summary,
    this.sourceUrl,
    this.lastCheckedAt,
    this.approvedAt,
  });
  
  final String id;
  final String stateCode;
  final RegulationCategory category;
  final String seasonYearLabel;
  final int yearStart;
  final int? yearEnd;
  final RegulationSummary summary;
  final String? sourceUrl;
  final DateTime? lastCheckedAt;
  final DateTime? approvedAt;
  
  factory StateRegulation.fromJson(Map<String, dynamic> json) {
    return StateRegulation(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      category: RegulationCategory.values.firstWhere(
        (c) => c.value == json['category'],
        orElse: () => RegulationCategory.deer,
      ),
      seasonYearLabel: json['season_year_label'] as String,
      yearStart: json['year_start'] as int,
      yearEnd: json['year_end'] as int?,
      summary: RegulationSummary.fromJson(json['summary'] as Map<String, dynamic>?),
      sourceUrl: json['source_url'] as String?,
      lastCheckedAt: json['last_checked_at'] != null
          ? DateTime.parse(json['last_checked_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }
}

/// Pending regulation update for admin review.
class PendingRegulation {
  const PendingRegulation({
    required this.id,
    required this.stateCode,
    required this.category,
    required this.seasonYearLabel,
    required this.yearStart,
    this.yearEnd,
    this.proposedSummary,
    this.diffSummary,
    this.sourceUrl,
    required this.status,
    this.notes,
    this.createdAt,
  });
  
  final String id;
  final String stateCode;
  final RegulationCategory category;
  final String seasonYearLabel;
  final int yearStart;
  final int? yearEnd;
  final RegulationSummary? proposedSummary;
  final String? diffSummary;
  final String? sourceUrl;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  
  factory PendingRegulation.fromJson(Map<String, dynamic> json) {
    return PendingRegulation(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      category: RegulationCategory.values.firstWhere(
        (c) => c.value == json['category'],
        orElse: () => RegulationCategory.deer,
      ),
      seasonYearLabel: json['season_year_label'] as String,
      yearStart: json['year_start'] as int,
      yearEnd: json['year_end'] as int?,
      proposedSummary: json['proposed_summary'] != null
          ? RegulationSummary.fromJson(json['proposed_summary'] as Map<String, dynamic>)
          : null,
      diffSummary: json['diff_summary'] as String?,
      sourceUrl: json['source_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Service for accessing state regulations.
class RegulationsService {
  RegulationsService(this._supabaseService);
  
  final SupabaseService _supabaseService;
  
  /// Fetch regulations for a specific state and category.
  Future<List<StateRegulation>> fetchRegulations({
    required String stateCode,
    RegulationCategory? category,
    int? yearStart,
  }) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    var query = client
        .from('state_regulations_approved')
        .select()
        .eq('state_code', stateCode);
    
    if (category != null) {
      query = query.eq('category', category.value);
    }
    
    if (yearStart != null) {
      query = query.eq('year_start', yearStart);
    }
    
    final response = await query.order('year_start', ascending: false);
    
    return (response as List)
        .map((json) => StateRegulation.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Fetch all states that have regulations.
  Future<List<String>> fetchStatesWithRegulations() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final response = await client
        .from('state_regulations_approved')
        .select('state_code')
        .order('state_code');
    
    final states = <String>{};
    for (final row in response as List) {
      states.add(row['state_code'] as String);
    }
    return states.toList();
  }
  
  /// Check if a state has pending updates.
  Future<bool> hasPendingUpdates(String stateCode) async {
    final client = _supabaseService.client;
    if (client == null) return false;
    
    try {
      final response = await client
          .from('state_regulations_pending')
          .select('id')
          .eq('state_code', stateCode)
          .eq('status', 'pending')
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      // Non-admins will get permission denied - that's expected
      return false;
    }
  }
  
  /// Fetch pending regulations (admin only).
  Future<List<PendingRegulation>> fetchPendingRegulations() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final response = await client
        .from('state_regulations_pending')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => PendingRegulation.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Approve a pending regulation (admin only).
  Future<void> approvePendingRegulation(String pendingId, RegulationSummary summary) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    // Fetch the pending regulation
    final pendingResponse = await client
        .from('state_regulations_pending')
        .select()
        .eq('id', pendingId)
        .single();
    
    final pending = PendingRegulation.fromJson(pendingResponse as Map<String, dynamic>);
    
    // Upsert into approved table
    await client.from('state_regulations_approved').upsert({
      'state_code': pending.stateCode,
      'category': pending.category.value,
      'season_year_label': pending.seasonYearLabel,
      'year_start': pending.yearStart,
      'year_end': pending.yearEnd,
      'summary': {
        'seasons': summary.seasons.map((s) => {
          'name': s.name,
          'start_date': s.startDate,
          'end_date': s.endDate,
          'notes': s.notes,
        }).toList(),
        'bag_limits': summary.bagLimits.map((b) => {
          'species': b.species,
          'daily': b.daily,
          'possession': b.possession,
          'season': b.season,
          'notes': b.notes,
        }).toList(),
        'weapons': summary.weapons.map((w) => {
          'name': w.name,
          'allowed': w.allowed,
          'restrictions': w.restrictions,
        }).toList(),
        'notes': summary.notes,
      },
      'source_url': pending.sourceUrl,
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': client.auth.currentUser?.id,
    }, onConflict: 'state_code,category,season_year_label');
    
    // Update pending status
    await client.from('state_regulations_pending').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': client.auth.currentUser?.id,
    }).eq('id', pendingId);
  }
  
  /// Reject a pending regulation (admin only).
  Future<void> rejectPendingRegulation(String pendingId, String? notes) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    await client.from('state_regulations_pending').update({
      'status': 'rejected',
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': client.auth.currentUser?.id,
      'notes': notes,
    }).eq('id', pendingId);
  }
}

/// Provider for regulations service.
final regulationsServiceProvider = Provider<RegulationsService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RegulationsService(supabaseService);
});

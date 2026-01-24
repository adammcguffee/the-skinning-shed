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

/// Region info for a state regulation.
class RegulationRegion {
  const RegulationRegion({
    required this.regionKey,
    required this.regionLabel,
    this.regionScope = 'statewide',
    this.regionGeo,
  });
  
  final String regionKey;
  final String regionLabel;
  final String regionScope; // statewide, zone, unit, county_group
  final Map<String, dynamic>? regionGeo;
  
  factory RegulationRegion.fromJson(Map<String, dynamic> json) {
    return RegulationRegion(
      regionKey: json['region_key'] as String? ?? 'STATEWIDE',
      regionLabel: json['region_label'] as String? ?? 'Statewide',
      regionScope: json['region_scope'] as String? ?? 'statewide',
      regionGeo: json['region_geo'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'region_key': regionKey,
    'region_label': regionLabel,
    'region_scope': regionScope,
    if (regionGeo != null) 'region_geo': regionGeo,
  };
  
  bool get isStatewide => regionKey == 'STATEWIDE';
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
    this.regionKey = 'STATEWIDE',
    this.regionLabel = 'Statewide',
    this.regionScope = 'statewide',
    this.regionGeo,
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
  // Region fields
  final String regionKey;
  final String regionLabel;
  final String regionScope;
  final Map<String, dynamic>? regionGeo;
  
  RegulationRegion get region => RegulationRegion(
    regionKey: regionKey,
    regionLabel: regionLabel,
    regionScope: regionScope,
    regionGeo: regionGeo,
  );
  
  bool get isStatewide => regionKey == 'STATEWIDE';
  
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
      regionKey: json['region_key'] as String? ?? 'STATEWIDE',
      regionLabel: json['region_label'] as String? ?? 'Statewide',
      regionScope: json['region_scope'] as String? ?? 'statewide',
      regionGeo: json['region_geo'] as Map<String, dynamic>?,
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
    this.regionKey = 'STATEWIDE',
    this.regionLabel = 'Statewide',
    this.regionScope = 'statewide',
    this.regionGeo,
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
  // Region fields
  final String regionKey;
  final String regionLabel;
  final String regionScope;
  final Map<String, dynamic>? regionGeo;
  
  RegulationRegion get region => RegulationRegion(
    regionKey: regionKey,
    regionLabel: regionLabel,
    regionScope: regionScope,
    regionGeo: regionGeo,
  );
  
  bool get isStatewide => regionKey == 'STATEWIDE';
  
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
      regionKey: json['region_key'] as String? ?? 'STATEWIDE',
      regionLabel: json['region_label'] as String? ?? 'Statewide',
      regionScope: json['region_scope'] as String? ?? 'statewide',
      regionGeo: json['region_geo'] as Map<String, dynamic>?,
    );
  }
}

/// Coverage status for a state/category combination.
class RegulationCoverage {
  const RegulationCoverage({
    required this.stateCode,
    required this.category,
    this.approvedCount = 0,
    this.pendingCount = 0,
    this.hasSource = false,
  });
  
  final String stateCode;
  final String category;
  final int approvedCount;
  final int pendingCount;
  final bool hasSource;
  
  bool get hasApproved => approvedCount > 0;
  bool get hasPending => pendingCount > 0;
  bool get isMissing => !hasApproved && !hasPending;
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
    String? regionKey,
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
    
    if (regionKey != null) {
      query = query.eq('region_key', regionKey);
    }
    
    final response = await query.order('year_start', ascending: false);
    
    return (response as List)
        .map((json) => StateRegulation.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Fetch available regions for a state and category.
  Future<List<RegulationRegion>> fetchRegionsForState({
    required String stateCode,
    required RegulationCategory category,
  }) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final response = await client
        .from('state_regulations_approved')
        .select('region_key, region_label, region_scope, region_geo')
        .eq('state_code', stateCode)
        .eq('category', category.value)
        .order('region_key');
    
    final regions = <String, RegulationRegion>{};
    for (final row in response as List) {
      final key = row['region_key'] as String;
      if (!regions.containsKey(key)) {
        regions[key] = RegulationRegion.fromJson(row as Map<String, dynamic>);
      }
    }
    
    // Sort so STATEWIDE comes first
    final sorted = regions.values.toList()
      ..sort((a, b) {
        if (a.regionKey == 'STATEWIDE') return -1;
        if (b.regionKey == 'STATEWIDE') return 1;
        return a.regionLabel.compareTo(b.regionLabel);
      });
    
    return sorted;
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
    
    // Upsert into approved table (now includes region_key in conflict)
    await client.from('state_regulations_approved').upsert({
      'state_code': pending.stateCode,
      'category': pending.category.value,
      'season_year_label': pending.seasonYearLabel,
      'year_start': pending.yearStart,
      'year_end': pending.yearEnd,
      'region_key': pending.regionKey,
      'region_label': pending.regionLabel,
      'region_scope': pending.regionScope,
      'region_geo': pending.regionGeo,
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
    }, onConflict: 'state_code,category,season_year_label,region_key');
    
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
  
  /// Run the regulations checker edge function (admin only).
  /// Returns a map with check results: checked, changed, results array.
  Future<Map<String, dynamic>> runRegulationsChecker() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    final response = await client.functions.invoke(
      'regulations-check',
      body: {},
    );
    
    if (response.status != 200) {
      throw Exception('Failed to run checker: ${response.data}');
    }
    
    return response.data as Map<String, dynamic>;
  }
  
  /// Fetch coverage data for all states (admin only).
  /// Returns a map of state_code -> category -> coverage.
  Future<Map<String, Map<String, RegulationCoverage>>> fetchCoverageData() async {
    final client = _supabaseService.client;
    if (client == null) return {};
    
    // Fetch approved counts by state/category
    final approvedResponse = await client
        .from('state_regulations_approved')
        .select('state_code, category');
    
    // Fetch pending counts by state/category
    final pendingResponse = await client
        .from('state_regulations_pending')
        .select('state_code, category')
        .eq('status', 'pending');
    
    // Fetch sources by state/category
    final sourcesResponse = await client
        .from('state_regulations_sources')
        .select('state_code, category');
    
    // Build coverage map
    final coverage = <String, Map<String, RegulationCoverage>>{};
    final categories = ['deer', 'turkey', 'fishing'];
    
    // Count approved
    final approvedCounts = <String, int>{};
    for (final row in approvedResponse as List) {
      final key = '${row['state_code']}_${row['category']}';
      approvedCounts[key] = (approvedCounts[key] ?? 0) + 1;
    }
    
    // Count pending
    final pendingCounts = <String, int>{};
    for (final row in pendingResponse as List) {
      final key = '${row['state_code']}_${row['category']}';
      pendingCounts[key] = (pendingCounts[key] ?? 0) + 1;
    }
    
    // Track sources
    final hasSources = <String>{};
    for (final row in sourcesResponse as List) {
      hasSources.add('${row['state_code']}_${row['category']}');
    }
    
    // Build result for all states
    // Note: We'll populate all states in the UI
    for (final row in [...approvedResponse as List, ...pendingResponse as List, ...sourcesResponse as List]) {
      final stateCode = row['state_code'] as String;
      final category = row['category'] as String;
      final key = '${stateCode}_$category';
      
      coverage[stateCode] ??= {};
      coverage[stateCode]![category] = RegulationCoverage(
        stateCode: stateCode,
        category: category,
        approvedCount: approvedCounts[key] ?? 0,
        pendingCount: pendingCounts[key] ?? 0,
        hasSource: hasSources.contains(key),
      );
    }
    
    return coverage;
  }
  
  /// Bulk import regulations into pending table (admin only).
  /// Returns count of imported records.
  Future<int> importBulkRegulations(List<Map<String, dynamic>> regulations) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    int imported = 0;
    final now = DateTime.now().toIso8601String();
    
    for (final reg in regulations) {
      try {
        await client.from('state_regulations_pending').upsert({
          'state_code': reg['state_code'],
          'category': reg['category'],
          'season_year_label': reg['season_year_label'],
          'year_start': reg['year_start'],
          'year_end': reg['year_end'],
          'region_key': reg['region_key'] ?? 'STATEWIDE',
          'region_label': reg['region_label'] ?? 'Statewide',
          'region_scope': reg['region_scope'] ?? 'statewide',
          'region_geo': reg['region_geo'],
          'proposed_summary': reg['summary'],
          'source_url': reg['source_url'],
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        }, onConflict: 'state_code,category,season_year_label,region_key');
        imported++;
      } catch (e) {
        print('Error importing ${reg['state_code']}/${reg['category']}: $e');
      }
    }
    
    return imported;
  }
  
  /// Export approved regulations for a state (admin only).
  Future<List<Map<String, dynamic>>> exportRegulations({
    String? stateCode,
    String? category,
  }) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    var query = client.from('state_regulations_approved').select();
    
    if (stateCode != null) {
      query = query.eq('state_code', stateCode);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    
    final response = await query.order('state_code').order('category');
    
    return (response as List).map((row) => {
      'state_code': row['state_code'],
      'category': row['category'],
      'season_year_label': row['season_year_label'],
      'year_start': row['year_start'],
      'year_end': row['year_end'],
      'region_key': row['region_key'],
      'region_label': row['region_label'],
      'region_scope': row['region_scope'],
      'region_geo': row['region_geo'],
      'summary': row['summary'],
      'source_url': row['source_url'],
    }).toList();
  }
  
  /// Seed regulation sources from a list (admin only).
  /// Returns map with inserted and updated counts.
  Future<Map<String, int>> seedSources(List<Map<String, dynamic>> sources) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    int inserted = 0;
    int updated = 0;
    final now = DateTime.now().toIso8601String();
    
    for (final source in sources) {
      try {
        // Check if exists
        final existing = await client
            .from('state_regulations_sources')
            .select('id')
            .eq('state_code', source['state_code'])
            .eq('category', source['category'])
            .eq('region_key', source['region_key'] ?? 'STATEWIDE')
            .maybeSingle();
        
        if (existing != null) {
          // Update
          await client.from('state_regulations_sources').update({
            'source_url': source['source_url'],
            'source_name': source['source_name'],
            'region_label': source['region_label'] ?? 'Statewide',
            'updated_at': now,
          }).eq('id', existing['id']);
          updated++;
        } else {
          // Insert
          await client.from('state_regulations_sources').insert({
            'state_code': source['state_code'],
            'category': source['category'],
            'region_key': source['region_key'] ?? 'STATEWIDE',
            'region_label': source['region_label'] ?? 'Statewide',
            'source_url': source['source_url'],
            'source_name': source['source_name'],
            'created_at': now,
            'updated_at': now,
          });
          inserted++;
        }
      } catch (e) {
        print('Error seeding ${source['state_code']}/${source['category']}: $e');
      }
    }
    
    return {'inserted': inserted, 'updated': updated};
  }
  
  /// Fetch all sources (admin only).
  Future<List<Map<String, dynamic>>> fetchSources() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final response = await client
        .from('state_regulations_sources')
        .select()
        .order('state_code')
        .order('category');
    
    return List<Map<String, dynamic>>.from(response as List);
  }
}

/// Provider for regulations service.
final regulationsServiceProvider = Provider<RegulationsService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RegulationsService(supabaseService);
});

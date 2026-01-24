import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/services/edge_admin_client.dart';
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
    this.confidenceScore = 0,
    this.approvalMode = 'manual',
    this.approvedBy,
    this.extractionVersion,
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
  // Confidence and approval fields
  final double confidenceScore;
  final String approvalMode; // 'auto' or 'manual'
  final String? approvedBy;
  final String? extractionVersion;
  
  RegulationRegion get region => RegulationRegion(
    regionKey: regionKey,
    regionLabel: regionLabel,
    regionScope: regionScope,
    regionGeo: regionGeo,
  );
  
  bool get isStatewide => regionKey == 'STATEWIDE';
  bool get isAutoApproved => approvalMode == 'auto';
  
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
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      approvalMode: json['approval_mode'] as String? ?? 'manual',
      approvedBy: json['approved_by'] as String?,
      extractionVersion: json['extraction_version'] as String?,
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
    this.confidenceScore = 0,
    this.extractionWarnings = const [],
    this.pendingReason,
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
  // Confidence fields
  final double confidenceScore;
  final List<String> extractionWarnings;
  final String? pendingReason;
  
  RegulationRegion get region => RegulationRegion(
    regionKey: regionKey,
    regionLabel: regionLabel,
    regionScope: regionScope,
    regionGeo: regionGeo,
  );
  
  bool get isStatewide => regionKey == 'STATEWIDE';
  bool get isHighConfidence => confidenceScore >= 0.85;
  
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
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      extractionWarnings: (json['extraction_warnings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      pendingReason: json['pending_reason'] as String?,
    );
  }
}

/// Audit log entry for regulation changes.
class RegulationAuditEntry {
  const RegulationAuditEntry({
    required this.id,
    required this.stateCode,
    required this.category,
    required this.regionKey,
    required this.detectedAt,
    this.previousHash,
    required this.newHash,
    required this.confidenceScore,
    required this.approvalMode,
    this.diffSummary,
    this.extractionWarnings = const [],
    this.approvedRowId,
    this.pendingRowId,
  });
  
  final String id;
  final String stateCode;
  final String category;
  final String regionKey;
  final DateTime detectedAt;
  final String? previousHash;
  final String newHash;
  final double confidenceScore;
  final String approvalMode; // 'auto', 'manual', 'pending'
  final String? diffSummary;
  final List<String> extractionWarnings;
  final String? approvedRowId;
  final String? pendingRowId;
  
  bool get wasAutoApproved => approvalMode == 'auto';
  bool get wasPending => approvalMode == 'pending';
  
  factory RegulationAuditEntry.fromJson(Map<String, dynamic> json) {
    return RegulationAuditEntry(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      category: json['category'] as String,
      regionKey: json['region_key'] as String? ?? 'STATEWIDE',
      detectedAt: DateTime.parse(json['detected_at'] as String),
      previousHash: json['previous_hash'] as String?,
      newHash: json['new_hash'] as String,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      approvalMode: json['approval_mode'] as String,
      diffSummary: json['diff_summary'] as String?,
      extractionWarnings: (json['extraction_warnings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      approvedRowId: json['approved_row_id'] as String?,
      pendingRowId: json['pending_row_id'] as String?,
    );
  }
}

/// State portal links for quick access to official agency pages.
/// Links are only shown in UI if verified OK AND within 14 days.
class StatePortalLinks {
  const StatePortalLinks({
    required this.stateCode,
    required this.stateName,
    this.agencyName,
    this.seasonsUrl,
    this.regulationsUrl,
    this.licensingUrl,
    this.buyLicenseUrl,
    this.fishingUrl,
    this.recordsUrl,
    this.notes,
    // Verification status booleans - THE GATEKEEPER
    this.verifiedSeasonsOk = false,
    this.verifiedRegsOk = false,
    this.verifiedFishingOk = false,
    this.verifiedLicensingOk = false,
    this.verifiedBuyLicenseOk = false,
    this.verifiedRecordsOk = false,
    this.lastVerifiedAt,
  });
  
  final String stateCode;
  final String stateName;
  final String? agencyName;
  final String? seasonsUrl;
  final String? regulationsUrl;
  final String? licensingUrl;
  final String? buyLicenseUrl;
  final String? fishingUrl;
  final String? recordsUrl;
  final String? notes;
  
  // Verification status - must be true AND recent to show link
  final bool verifiedSeasonsOk;
  final bool verifiedRegsOk;
  final bool verifiedFishingOk;
  final bool verifiedLicensingOk;
  final bool verifiedBuyLicenseOk;
  final bool verifiedRecordsOk;
  final DateTime? lastVerifiedAt;
  
  /// Maximum age for verification to be considered valid (14 days).
  static const verificationMaxAgeDays = 14;
  
  /// Check if verification is recent enough (within 14 days).
  bool get isVerificationRecent {
    if (lastVerifiedAt == null) return false;
    final age = DateTime.now().difference(lastVerifiedAt!);
    return age.inDays <= verificationMaxAgeDays;
  }
  
  // GATED ACCESSORS: Only true if URL exists AND verified OK AND recent
  bool get canShowSeasons => 
      seasonsUrl != null && seasonsUrl!.isNotEmpty && 
      verifiedSeasonsOk && isVerificationRecent;
  
  bool get canShowRegulations => 
      regulationsUrl != null && regulationsUrl!.isNotEmpty && 
      verifiedRegsOk && isVerificationRecent;
  
  bool get canShowFishing => 
      fishingUrl != null && fishingUrl!.isNotEmpty && 
      verifiedFishingOk && isVerificationRecent;
  
  bool get canShowLicensing => 
      licensingUrl != null && licensingUrl!.isNotEmpty && 
      verifiedLicensingOk && isVerificationRecent;
  
  bool get canShowBuyLicense => 
      buyLicenseUrl != null && buyLicenseUrl!.isNotEmpty && 
      verifiedBuyLicenseOk && isVerificationRecent;
  
  bool get canShowRecords => 
      recordsUrl != null && recordsUrl!.isNotEmpty && 
      verifiedRecordsOk && isVerificationRecent;
  
  // Legacy accessors (just check URL presence) - use canShow* instead
  bool get hasSeasons => seasonsUrl != null && seasonsUrl!.isNotEmpty;
  bool get hasRegulations => regulationsUrl != null && regulationsUrl!.isNotEmpty;
  bool get hasLicensing => licensingUrl != null && licensingUrl!.isNotEmpty;
  bool get hasBuyLicense => buyLicenseUrl != null && buyLicenseUrl!.isNotEmpty;
  bool get hasFishing => fishingUrl != null && fishingUrl!.isNotEmpty;
  bool get hasRecords => recordsUrl != null && recordsUrl!.isNotEmpty;
  
  /// Count of links that can be shown (verified + recent).
  int get verifiedLinkCount {
    int count = 0;
    if (canShowSeasons) count++;
    if (canShowRegulations) count++;
    if (canShowFishing) count++;
    if (canShowLicensing) count++;
    if (canShowBuyLicense) count++;
    if (canShowRecords) count++;
    return count;
  }
  
  /// True if at least one link can be shown.
  bool get hasAnyVerifiedLinks => verifiedLinkCount > 0;
  
  factory StatePortalLinks.fromJson(Map<String, dynamic> json) {
    return StatePortalLinks(
      stateCode: json['state_code'] as String,
      stateName: json['state_name'] as String,
      agencyName: json['agency_name'] as String?,
      seasonsUrl: json['hunting_seasons_url'] as String? ?? json['seasons_url'] as String?,
      regulationsUrl: json['hunting_regs_url'] as String? ?? json['regulations_url'] as String?,
      licensingUrl: json['licensing_url'] as String?,
      buyLicenseUrl: json['buy_license_url'] as String?,
      fishingUrl: json['fishing_regs_url'] as String? ?? json['fishing_url'] as String?,
      recordsUrl: json['records_url'] as String?,
      notes: json['notes'] as String?,
      // Parse verification booleans
      verifiedSeasonsOk: json['verified_hunting_seasons_ok'] as bool? ?? false,
      verifiedRegsOk: json['verified_hunting_regs_ok'] as bool? ?? false,
      verifiedFishingOk: json['verified_fishing_regs_ok'] as bool? ?? false,
      verifiedLicensingOk: json['verified_licensing_ok'] as bool? ?? false,
      verifiedBuyLicenseOk: json['verified_buy_license_ok'] as bool? ?? false,
      verifiedRecordsOk: json['verified_records_ok'] as bool? ?? false,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'] as String)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'state_code': stateCode,
    'state_name': stateName,
    if (agencyName != null) 'agency_name': agencyName,
    if (seasonsUrl != null) 'hunting_seasons_url': seasonsUrl,
    if (regulationsUrl != null) 'hunting_regs_url': regulationsUrl,
    if (licensingUrl != null) 'licensing_url': licensingUrl,
    if (buyLicenseUrl != null) 'buy_license_url': buyLicenseUrl,
    if (fishingUrl != null) 'fishing_regs_url': fishingUrl,
    if (recordsUrl != null) 'records_url': recordsUrl,
    if (notes != null) 'notes': notes,
  };
}

/// Official state wildlife agency root domain.
/// These are the ONLY allowed source domains for portal links.
class OfficialRoot {
  const OfficialRoot({
    required this.stateCode,
    required this.stateName,
    required this.agencyName,
    required this.officialRootUrl,
    required this.officialDomain,
    this.verifiedOk = false,
    this.lastVerifiedAt,
    this.verifyError,
  });
  
  final String stateCode;
  final String stateName;
  final String agencyName;
  final String officialRootUrl;
  final String officialDomain;
  final bool verifiedOk;
  final DateTime? lastVerifiedAt;
  final String? verifyError;
  
  /// Check if a URL is within this official domain (or subdomain).
  bool isUrlAllowed(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final domain = officialDomain.toLowerCase();
      return host == domain || host.endsWith('.$domain');
    } catch (_) {
      return false;
    }
  }
  
  factory OfficialRoot.fromJson(Map<String, dynamic> json) {
    return OfficialRoot(
      stateCode: json['state_code'] as String,
      stateName: json['state_name'] as String,
      agencyName: json['agency_name'] as String,
      officialRootUrl: json['official_root_url'] as String,
      officialDomain: json['official_domain'] as String,
      verifiedOk: json['verified_ok'] as bool? ?? false,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'] as String)
          : null,
      verifyError: json['verify_error'] as String?,
    );
  }
}

/// Source counts by category.
class SourceCounts {
  const SourceCounts({
    this.total = 0,
    this.deer = 0,
    this.turkey = 0,
    this.fishing = 0,
  });
  
  final int total;
  final int deer;
  final int turkey;
  final int fishing;
  
  factory SourceCounts.fromList(List<Map<String, dynamic>> rows) {
    int total = 0;
    int deer = 0;
    int turkey = 0;
    int fishing = 0;
    
    for (final row in rows) {
      final category = row['category'] as String;
      final count = row['count'] as int;
      total += count;
      if (category == 'deer') deer = count;
      if (category == 'turkey') turkey = count;
      if (category == 'fishing') fishing = count;
    }
    
    return SourceCounts(total: total, deer: deer, turkey: turkey, fishing: fishing);
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
  
  // ========================================================================
  // ADMIN EDGE FUNCTION HELPER - Standardized JWT auth for all admin calls
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
  /// Sorted by confidence ascending (lowest first) so admins review uncertain items first.
  Future<List<PendingRegulation>> fetchPendingRegulations() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final response = await client
        .from('state_regulations_pending')
        .select()
        .eq('status', 'pending')
        .order('confidence_score', ascending: true)
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
    final now = DateTime.now().toIso8601String();
    final userId = client.auth.currentUser?.id;
    
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
      'approved_at': now,
      'approved_by': userId,
      'approval_mode': 'manual',
      'confidence_score': pending.confidenceScore,
    }, onConflict: 'state_code,category,season_year_label,region_key');
    
    // Update pending status
    await client.from('state_regulations_pending').update({
      'status': 'approved',
      'reviewed_at': now,
      'reviewed_by': userId,
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
  /// Uses v6: OpenAI normalization + strict validation + processes all 150.
  /// Returns a map with check results: checked, auto_approved, pending, skipped, failed.
  Future<Map<String, dynamic>> runRegulationsChecker() async {
    return EdgeAdminClient.invokeAdminEdge('regulations-check-v6');
  }
  
  /// Fetch coverage statistics for admin dashboard.
  Future<Map<String, dynamic>> fetchCoverageStats() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    // Portal links coverage
    final portalRes = await client.from('state_portal_links').select('state_code');
    final portalStates = (portalRes as List).map((e) => e['state_code'] as String).toSet();
    
    // Approved facts coverage
    final approvedRes = await client.from('state_regulations_approved')
        .select('state_code, category')
        .order('state_code');
    final approvedMap = <String, Set<String>>{};
    for (final row in approvedRes as List) {
      final state = row['state_code'] as String;
      final cat = row['category'] as String;
      approvedMap.putIfAbsent(state, () => {}).add(cat);
    }
    
    // Pending count
    final pendingRes = await client.from('state_regulations_pending')
        .select('id')
        .eq('status', 'pending');
    final pendingCount = (pendingRes as List).length;
    
    // Sources by type
    final sourcesRes = await client.from('state_regulations_sources')
        .select('source_type');
    int extractable = 0;
    int portalOnly = 0;
    for (final row in sourcesRes as List) {
      final t = row['source_type'] as String?;
      if (t == 'extractable' || t == 'season_schedule' || t == 'reg_summary') {
        extractable++;
      } else if (t == 'portal_only' || t == 'landing') {
        portalOnly++;
      } else {
        extractable++; // default
      }
    }
    
    return {
      'portal_coverage': portalStates.length,
      'portal_total': 50,
      'facts_states': approvedMap.length,
      'facts_total_rows': approvedRes.length,
      'pending_count': pendingCount,
      'sources_extractable': extractable,
      'sources_portal_only': portalOnly,
    };
  }
  
  /// Delete junk pending items (zero confidence or landing pages).
  Future<int> deleteJunkPending() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    final res = await client.from('state_regulations_pending')
        .delete()
        .or('confidence_score.eq.0,pending_reason.ilike.%landing%,proposed_summary.is.null')
        .select('id');
    
    return (res as List).length;
  }
  
  /// Reset all regulations data (admin only).
  /// Deletes pending, approved, sources, and optionally audit log.
  /// Also resets portal links verification status.
  Future<Map<String, int>> resetRegulationsData({bool includeAuditLog = false}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    final pendingRes = await client.from('state_regulations_pending').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    final approvedRes = await client.from('state_regulations_approved').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    final sourcesRes = await client.from('state_regulations_sources').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    
    // Optionally clear audit log
    int auditDeleted = 0;
    if (includeAuditLog) {
      final auditRes = await client.from('state_regulations_audit_log').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      auditDeleted = (auditRes as List?)?.length ?? 0;
    }
    
    // Reset portal links verification status (keep URLs but mark unverified)
    await client.from('state_portal_links').update({
      'verified_hunting_seasons_ok': false,
      'verified_hunting_regs_ok': false,
      'verified_fishing_regs_ok': false,
      'verified_licensing_ok': false,
      'verified_buy_license_ok': false,
      'verified_records_ok': false,
      'last_verified_at': null,
    }).neq('state_code', '');
    
    return {
      'pending': (pendingRes as List?)?.length ?? 0,
      'approved': (approvedRes as List?)?.length ?? 0,
      'sources': (sourcesRes as List?)?.length ?? 0,
      'audit': auditDeleted,
    };
  }
  
  /// Fetch official roots for all states (admin only).
  Future<List<OfficialRoot>> fetchOfficialRoots() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final res = await client.from('state_official_roots')
        .select()
        .order('state_code');
    
    return (res as List)
        .map((json) => OfficialRoot.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Fetch official root for a single state.
  Future<OfficialRoot?> fetchOfficialRoot(String stateCode) async {
    final client = _supabaseService.client;
    if (client == null) return null;
    
    final res = await client.from('state_official_roots')
        .select()
        .eq('state_code', stateCode)
        .maybeSingle();
    
    if (res == null) return null;
    return OfficialRoot.fromJson(res as Map<String, dynamic>);
  }
  
  /// Verify portal links (checks HTTP status of all URLs).
  Future<Map<String, dynamic>> verifyPortalLinks() async {
    return EdgeAdminClient.invokeAdminEdge('regs-links-verify');
  }
  
  /// Auth diagnostic (debug-only) - validates auth and returns JWT metadata.
  Future<Map<String, dynamic>> runAuthDiagnostic() async {
    return EdgeAdminClient.invokeAdminEdge('regs-auth-diagnostic');
  }

  /// Discover portal links by crawling official domains (official-only).
  /// Uses regs-discover-official to crawl state_official_roots domains.
  Future<Map<String, dynamic>> discoverOfficialLinks({int limit = 5, int offset = 0}) async {
    return EdgeAdminClient.invokeAdminEdge('regs-discover-official', body: {
      'limit': limit,
      'offset': offset,
    });
  }
  
  /// Legacy discover method - redirects to official-only discovery.
  Future<Map<String, dynamic>> discoverPortalLinks({int limit = 5, int offset = 0}) async {
    return discoverOfficialLinks(limit: limit, offset: offset);
  }
  
  /// Fetch broken portal links for admin review (where URL exists but verification failed).
  Future<List<Map<String, dynamic>>> fetchBrokenLinks() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    // Fetch all states with their URLs and verification status
    final res = await client.from('state_portal_links')
        .select()
        .order('state_code');
    
    final broken = <Map<String, dynamic>>[];
    
    for (final row in res as List) {
      final state = row as Map<String, dynamic>;
      final stateCode = state['state_code'] as String;
      final stateName = state['state_name'] as String;
      
      // Check each URL field
      final fields = [
        {'url': 'hunting_seasons_url', 'ok': 'verified_hunting_seasons_ok', 'label': 'Hunting Seasons'},
        {'url': 'hunting_regs_url', 'ok': 'verified_hunting_regs_ok', 'label': 'Hunting Regs'},
        {'url': 'fishing_regs_url', 'ok': 'verified_fishing_regs_ok', 'label': 'Fishing Regs'},
        {'url': 'licensing_url', 'ok': 'verified_licensing_ok', 'label': 'Licensing'},
        {'url': 'buy_license_url', 'ok': 'verified_buy_license_ok', 'label': 'Buy License'},
        {'url': 'records_url', 'ok': 'verified_records_ok', 'label': 'Records'},
      ];
      
      for (final field in fields) {
        final url = state[field['url']] as String?;
        final isOk = state[field['ok']] as bool? ?? false;
        
        // Broken = URL exists but not verified OK
        if (url != null && url.isNotEmpty && !isOk) {
          broken.add({
            'state_code': stateCode,
            'state_name': stateName,
            'field': field['label'],
            'url': url,
            'verified_ok': false,
          });
        }
      }
    }
    
    return broken;
  }
  
  /// Fetch all portal links for coverage matrix.
  Future<List<StatePortalLinks>> fetchAllPortalLinks() async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final res = await client.from('state_portal_links')
        .select()
        .order('state_code');
    
    return (res as List)
        .map((json) => StatePortalLinks.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Update a single portal link field for a state.
  Future<void> updatePortalLink({
    required String stateCode,
    String? huntingSeasonsUrl,
    String? huntingRegsUrl,
    String? fishingRegsUrl,
    String? licensingUrl,
    String? buyLicenseUrl,
    String? recordsUrl,
  }) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    // Only include fields that were provided (null = keep existing, empty string = clear)
    if (huntingSeasonsUrl != null) {
      updates['hunting_seasons_url'] = huntingSeasonsUrl.isEmpty ? null : huntingSeasonsUrl;
      updates['verified_hunting_seasons_ok'] = false; // Reset verification
    }
    if (huntingRegsUrl != null) {
      updates['hunting_regs_url'] = huntingRegsUrl.isEmpty ? null : huntingRegsUrl;
      updates['verified_hunting_regs_ok'] = false;
    }
    if (fishingRegsUrl != null) {
      updates['fishing_regs_url'] = fishingRegsUrl.isEmpty ? null : fishingRegsUrl;
      updates['verified_fishing_regs_ok'] = false;
    }
    if (licensingUrl != null) {
      updates['licensing_url'] = licensingUrl.isEmpty ? null : licensingUrl;
      updates['verified_licensing_ok'] = false;
    }
    if (buyLicenseUrl != null) {
      updates['buy_license_url'] = buyLicenseUrl.isEmpty ? null : buyLicenseUrl;
      updates['verified_buy_license_ok'] = false;
    }
    if (recordsUrl != null) {
      updates['records_url'] = recordsUrl.isEmpty ? null : recordsUrl;
      updates['verified_records_ok'] = false;
    }
    
    await client.from('state_portal_links')
        .update(updates)
        .eq('state_code', stateCode);
  }
  
  /// Fetch audit log entries (admin only).
  Future<List<RegulationAuditEntry>> fetchAuditLog({
    String? stateCode,
    int limit = 50,
  }) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    var query = client
        .from('state_regulations_audit_log')
        .select();
    
    if (stateCode != null) {
      query = query.eq('state_code', stateCode);
    }
    
    final response = await query
        .order('detected_at', ascending: false)
        .limit(limit);
    
    return (response as List)
        .map((json) => RegulationAuditEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Get checker run statistics (admin only).
  /// Returns counts of recent auto-approved vs pending.
  Future<Map<String, int>> getCheckerStats({int days = 7}) async {
    final client = _supabaseService.client;
    if (client == null) return {'auto_approved': 0, 'pending': 0, 'manual': 0};
    
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    
    final response = await client
        .from('state_regulations_audit_log')
        .select('approval_mode')
        .gte('detected_at', cutoff);
    
    int autoApproved = 0;
    int pending = 0;
    int manual = 0;
    
    for (final row in response as List) {
      final mode = row['approval_mode'] as String;
      if (mode == 'auto') autoApproved++;
      else if (mode == 'pending') pending++;
      else if (mode == 'manual') manual++;
    }
    
    return {
      'auto_approved': autoApproved,
      'pending': pending,
      'manual': manual,
    };
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
  
  /// Fetch source counts by category (admin only).
  Future<SourceCounts> fetchSourceCounts() async {
    final client = _supabaseService.client;
    if (client == null) return const SourceCounts();
    
    // Use RPC or raw query for grouping
    final response = await client
        .from('state_regulations_sources')
        .select('category');
    
    int deer = 0;
    int turkey = 0;
    int fishing = 0;
    
    for (final row in response as List) {
      final category = row['category'] as String;
      if (category == 'deer') deer++;
      if (category == 'turkey') turkey++;
      if (category == 'fishing') fishing++;
    }
    
    return SourceCounts(
      total: deer + turkey + fishing,
      deer: deer,
      turkey: turkey,
      fishing: fishing,
    );
  }
  
  /// Fetch portal links for a state.
  Future<StatePortalLinks?> fetchPortalLinks(String stateCode) async {
    final client = _supabaseService.client;
    if (client == null) return null;
    
    final response = await client
        .from('state_portal_links')
        .select()
        .eq('state_code', stateCode)
        .maybeSingle();
    
    if (response == null) return null;
    return StatePortalLinks.fromJson(response as Map<String, dynamic>);
  }
  
  /// Seed portal links for all states (admin only).
  Future<Map<String, int>> seedPortalLinks(List<Map<String, dynamic>> links) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    int inserted = 0;
    int updated = 0;
    
    for (final link in links) {
      try {
        final existing = await client
            .from('state_portal_links')
            .select('state_code')
            .eq('state_code', link['state_code'])
            .maybeSingle();
        
        if (existing != null) {
          await client.from('state_portal_links').update({
            ...link,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('state_code', link['state_code']);
          updated++;
        } else {
          await client.from('state_portal_links').insert(link);
          inserted++;
        }
      } catch (e) {
        print('Error seeding portal link ${link['state_code']}: $e');
      }
    }
    
    return {'inserted': inserted, 'updated': updated};
  }
  
  // ========================================================================
  // DISCOVERY RUN METHODS - Full 50-state discovery with progress tracking
  // ========================================================================
  
  /// Start a new discovery run for all states.
  /// Returns run_id and initial status.
  Future<DiscoveryRun> startDiscoveryRun({int batchSize = 5}) async {
    try {
      final data = await EdgeAdminClient.invokeAdminEdge(
        'regs-discovery-start',
        body: {'batch_size': batchSize},
      );
      
      return DiscoveryRun(
        id: data['run_id'] as String,
        status: data['status'] as String? ?? 'running',
        processed: 0,
        total: data['total'] as int? ?? 50,
        batchSize: data['batch_size'] as int? ?? 5,
        statsOk: 0,
        statsSkipped: 0,
        statsError: 0,
      );
    } on EdgeAdminException catch (e) {
      if (e.status == 409 && e.data is Map<String, dynamic>) {
        final data = e.data as Map<String, dynamic>;
        if (data['error_code'] == 'ALREADY_RUNNING') {
          return DiscoveryRun(
            id: data['run_id'] as String,
            status: 'running',
            processed: data['processed'] as int? ?? 0,
            total: data['total'] as int? ?? 50,
            statsOk: 0,
            statsSkipped: 0,
            statsError: 0,
          );
        }
      }
      rethrow;
    }
  }
  
  /// Continue a discovery run by processing the next batch.
  /// Returns updated run status and batch results.
  Future<DiscoveryRunProgress> continueDiscoveryRun(String runId) async {
    final data = await EdgeAdminClient.invokeAdminEdge(
      'regs-discovery-continue',
      body: {'run_id': runId},
    );
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final batchResults = (data['batch_results'] as List?)
        ?.map((r) => DiscoveryBatchResult.fromJson(r as Map<String, dynamic>))
        .toList() ?? [];
    
    return DiscoveryRunProgress(
      runId: data['run_id'] as String,
      status: data['status'] as String? ?? 'running',
      processed: data['processed'] as int? ?? 0,
      total: data['total'] as int? ?? 50,
      lastStateCode: data['last_state_code'] as String?,
      statsOk: stats['ok'] as int? ?? 0,
      statsSkipped: stats['skipped'] as int? ?? 0,
      statsError: stats['error'] as int? ?? 0,
      batchResults: batchResults,
    );
  }
  
  /// Get the current active discovery run (if any).
  /// Used to resume progress after page refresh.
  Future<DiscoveryRun?> getActiveDiscoveryRun() async {
    final client = _supabaseService.client;
    if (client == null) return null;
    
    try {
      final res = await client
          .from('reg_discovery_runs')
          .select()
          .eq('status', 'running')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (res == null) return null;
      return DiscoveryRun.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      print('Error getting active discovery run: $e');
      return null;
    }
  }
  
  /// Get a specific discovery run by ID.
  Future<DiscoveryRun?> getDiscoveryRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) return null;
    
    try {
      final res = await client
          .from('reg_discovery_runs')
          .select()
          .eq('id', runId)
          .single();
      
      return DiscoveryRun.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      print('Error getting discovery run: $e');
      return null;
    }
  }
  
  /// Get per-state audit results for a discovery run.
  Future<List<DiscoveryRunItem>> getDiscoveryRunItems(String runId) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final res = await client
        .from('reg_discovery_run_items')
        .select()
        .eq('run_id', runId)
        .order('state_code');
    
    return (res as List)
        .map((json) => DiscoveryRunItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Get recent discovery runs for history.
  Future<List<DiscoveryRun>> getRecentDiscoveryRuns({int limit = 10}) async {
    final client = _supabaseService.client;
    if (client == null) return [];
    
    final res = await client
        .from('reg_discovery_runs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (res as List)
        .map((json) => DiscoveryRun.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Cancel an active discovery run.
  Future<void> cancelDiscoveryRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    await client.from('reg_discovery_runs')
        .update({'status': 'canceled', 'finished_at': DateTime.now().toIso8601String()})
        .eq('id', runId);
  }
}

// ============================================================================
// DISCOVERY RUN MODELS
// ============================================================================

/// Represents a discovery run job.
class DiscoveryRun {
  final String id;
  final String status;
  final int processed;
  final int total;
  final int? batchSize;
  final String? lastStateCode;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int statsOk;
  final int statsSkipped;
  final int statsError;
  
  DiscoveryRun({
    required this.id,
    required this.status,
    required this.processed,
    required this.total,
    this.batchSize,
    this.lastStateCode,
    this.startedAt,
    this.finishedAt,
    this.statsOk = 0,
    this.statsSkipped = 0,
    this.statsError = 0,
  });
  
  factory DiscoveryRun.fromJson(Map<String, dynamic> json) {
    return DiscoveryRun(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'unknown',
      processed: json['processed'] as int? ?? 0,
      total: json['total'] as int? ?? 50,
      batchSize: json['batch_size'] as int?,
      lastStateCode: json['last_state_code'] as String?,
      startedAt: json['started_at'] != null 
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null 
          ? DateTime.tryParse(json['finished_at'] as String)
          : null,
      statsOk: json['stats_ok'] as int? ?? 0,
      statsSkipped: json['stats_skipped'] as int? ?? 0,
      statsError: json['stats_error'] as int? ?? 0,
    );
  }
  
  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
  bool get isCanceled => status == 'canceled';
  bool get isError => status == 'error';
  
  double get progress => total > 0 ? processed / total : 0;
  String get progressText => '$processed/$total';
}

/// Progress update from continuing a discovery run.
class DiscoveryRunProgress {
  final String runId;
  final String status;
  final int processed;
  final int total;
  final String? lastStateCode;
  final int statsOk;
  final int statsSkipped;
  final int statsError;
  final List<DiscoveryBatchResult> batchResults;
  
  DiscoveryRunProgress({
    required this.runId,
    required this.status,
    required this.processed,
    required this.total,
    this.lastStateCode,
    this.statsOk = 0,
    this.statsSkipped = 0,
    this.statsError = 0,
    this.batchResults = const [],
  });
  
  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
  double get progress => total > 0 ? processed / total : 0;
}

/// Result of processing a single state in a batch.
class DiscoveryBatchResult {
  final String stateCode;
  final String status;
  final String? message;
  final int linksFound;
  
  DiscoveryBatchResult({
    required this.stateCode,
    required this.status,
    this.message,
    this.linksFound = 0,
  });
  
  factory DiscoveryBatchResult.fromJson(Map<String, dynamic> json) {
    return DiscoveryBatchResult(
      stateCode: json['state_code'] as String,
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String?,
      linksFound: json['links_found'] as int? ?? 0,
    );
  }
}

/// Per-state audit item from a discovery run.
class DiscoveryRunItem {
  final String runId;
  final String stateCode;
  final String status;
  final String? message;
  final Map<String, dynamic>? discovered;
  final Map<String, dynamic>? verified;
  final int pagesCrawled;
  final int linksFound;
  final DateTime? updatedAt;
  
  DiscoveryRunItem({
    required this.runId,
    required this.stateCode,
    required this.status,
    this.message,
    this.discovered,
    this.verified,
    this.pagesCrawled = 0,
    this.linksFound = 0,
    this.updatedAt,
  });
  
  factory DiscoveryRunItem.fromJson(Map<String, dynamic> json) {
    return DiscoveryRunItem(
      runId: json['run_id'] as String,
      stateCode: json['state_code'] as String,
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String?,
      discovered: json['discovered'] as Map<String, dynamic>?,
      verified: json['verified'] as Map<String, dynamic>?,
      pagesCrawled: json['pages_crawled'] as int? ?? 0,
      linksFound: json['links_found'] as int? ?? 0,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
  
  bool get isOk => status == 'ok';
  bool get isSkipped => status == 'skipped';
  bool get isError => status == 'error';
  
  /// Get list of discovered URLs as key-value pairs.
  List<MapEntry<String, String>> get discoveredUrls {
    if (discovered == null) return [];
    return discovered!.entries
        .where((e) => e.value != null && e.value is String)
        .map((e) => MapEntry(e.key.replaceAll('_url', ''), e.value as String))
        .toList();
  }
}

/// Provider for regulations service.
final regulationsServiceProvider = Provider<RegulationsService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RegulationsService(supabaseService);
});

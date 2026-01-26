import 'package:flutter/foundation.dart';
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

/// Status of a server-side verification run.
class VerifyRunStatus {
  const VerifyRunStatus({
    required this.runId,
    required this.status,
    required this.processedStates,
    required this.totalStates,
    required this.okCount,
    required this.brokenCount,
    this.lastStateCode,
    required this.done,
    required this.resumed,
  });

  final String runId;
  final String status; // running, done, error, canceled
  final int processedStates;
  final int totalStates;
  final int okCount;
  final int brokenCount;
  final String? lastStateCode;
  final bool done;
  final bool resumed;

  factory VerifyRunStatus.fromJson(Map<String, dynamic> json) {
    return VerifyRunStatus(
      runId: json['run_id'] as String,
      status: json['status'] as String,
      processedStates: json['processed_states'] as int? ?? 0,
      totalStates: json['total_states'] as int? ?? 50,
      okCount: json['ok_count'] as int? ?? 0,
      brokenCount: json['broken_count'] as int? ?? 0,
      lastStateCode: json['last_state_code'] as String?,
      done: json['done'] as bool? ?? false,
      resumed: json['resumed'] as bool? ?? false,
    );
  }

  double get progress => totalStates > 0 ? processedStates / totalStates : 0.0;
  bool get isRunning => status == 'running';
  bool get isComplete => status == 'done';
  bool get hasError => status == 'error';
  bool get isCanceled => status == 'canceled';
}

/// Misc related URL for when we can't find exact regs page.
class MiscRelatedUrl {
  const MiscRelatedUrl({
    required this.url,
    required this.label,
    this.confidence = 0.0,
    this.evidenceSnippet,
  });
  
  final String url;
  final String label;
  final double confidence;
  final String? evidenceSnippet;
  
  factory MiscRelatedUrl.fromJson(Map<String, dynamic> json) {
    return MiscRelatedUrl(
      url: json['url'] as String? ?? '',
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      evidenceSnippet: json['evidence_snippet'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'label': label,
    'confidence': confidence,
    'evidence_snippet': evidenceSnippet,
  };
}

/// State portal links for quick access to official agency pages.
class StatePortalLinks {
  const StatePortalLinks({
    required this.stateCode,
    required this.stateName,
    this.agencyName,
    this.huntingSeasonsUrl,
    this.huntingRegsUrl,
    this.fishingRegsUrl,
    this.licensingUrl,
    this.buyLicenseUrl,
    this.recordsUrl,
    this.notes,
    this.huntingSeasonsVerified = false,
    this.huntingRegsVerified = false,
    this.fishingRegsVerified = false,
    this.licensingVerified = false,
    this.buyLicenseVerified = false,
    this.recordsVerified = false,
    // New species-specific hunting slots
    this.deerSeasonsUrl,
    this.turkeySeasonsUrl,
    this.huntingDigestUrl,
    this.deerSeasonsVerified = false,
    this.turkeySeasonsVerified = false,
    this.huntingDigestVerified = false,
    // PDF URLs for when regulations are in PDF format
    this.huntingRegsPdfUrl,
    this.fishingRegsPdfUrl,
    this.huntingRegsPdfStatus,
    this.fishingRegsPdfStatus,
    // Misc related URLs for fallback
    this.miscRelatedUrls,
    // Discovery metadata
    this.discoveryNotes,
    this.discoveryConfidence,
  });
  
  final String stateCode;
  final String stateName;
  final String? agencyName;
  final String? huntingSeasonsUrl;
  final String? huntingRegsUrl;
  final String? fishingRegsUrl;
  final String? licensingUrl;
  final String? buyLicenseUrl;
  final String? recordsUrl;
  final String? notes;
  
  // New species-specific hunting slots
  final String? deerSeasonsUrl;
  final String? turkeySeasonsUrl;
  final String? huntingDigestUrl;
  
  // PDF URLs (for states where regs are PDF handbooks)
  final String? huntingRegsPdfUrl;
  final String? fishingRegsPdfUrl;
  final String? huntingRegsPdfStatus;
  final String? fishingRegsPdfStatus;
  
  // Misc related URLs (fallback when exact page uncertain)
  final List<MiscRelatedUrl>? miscRelatedUrls;
  
  // Discovery metadata
  final String? discoveryNotes;
  final Map<String, double>? discoveryConfidence;
  
  // Verification status
  final bool huntingSeasonsVerified;
  final bool huntingRegsVerified;
  final bool fishingRegsVerified;
  final bool licensingVerified;
  final bool buyLicenseVerified;
  final bool recordsVerified;
  final bool deerSeasonsVerified;
  final bool turkeySeasonsVerified;
  final bool huntingDigestVerified;
  
  // Has URL (HTML or PDF)
  bool get hasHuntingSeasons => huntingSeasonsUrl != null && huntingSeasonsUrl!.isNotEmpty;
  bool get hasHuntingRegs => huntingRegsUrl != null && huntingRegsUrl!.isNotEmpty;
  bool get hasHuntingRegsPdf => huntingRegsPdfUrl != null && huntingRegsPdfUrl!.isNotEmpty;
  bool get hasAnyHuntingRegs => hasHuntingRegs || hasHuntingRegsPdf;
  bool get hasFishingRegs => fishingRegsUrl != null && fishingRegsUrl!.isNotEmpty;
  bool get hasFishingRegsPdf => fishingRegsPdfUrl != null && fishingRegsPdfUrl!.isNotEmpty;
  bool get hasAnyFishingRegs => hasFishingRegs || hasFishingRegsPdf;
  bool get hasLicensing => licensingUrl != null && licensingUrl!.isNotEmpty;
  bool get hasBuyLicense => buyLicenseUrl != null && buyLicenseUrl!.isNotEmpty;
  bool get hasRecords => recordsUrl != null && recordsUrl!.isNotEmpty;
  bool get hasDeerSeasons => deerSeasonsUrl != null && deerSeasonsUrl!.isNotEmpty;
  bool get hasTurkeySeasons => turkeySeasonsUrl != null && turkeySeasonsUrl!.isNotEmpty;
  bool get hasHuntingDigest => huntingDigestUrl != null && huntingDigestUrl!.isNotEmpty;
  bool get hasMiscRelated => miscRelatedUrls != null && miscRelatedUrls!.isNotEmpty;
  
  // Check if we have ANY extractable source
  bool get hasAnyExtractableSource => 
      hasHuntingRegs || hasHuntingRegsPdf || 
      hasFishingRegs || hasFishingRegsPdf || 
      hasMiscRelated || hasHuntingDigest;
  
  // Available = has URL AND verified
  bool get huntingSeasonsAvailable => hasHuntingSeasons && huntingSeasonsVerified;
  bool get huntingRegsAvailable => hasHuntingRegs && huntingRegsVerified;
  bool get fishingRegsAvailable => hasFishingRegs && fishingRegsVerified;
  bool get licensingAvailable => hasLicensing && licensingVerified;
  bool get buyLicenseAvailable => hasBuyLicense && buyLicenseVerified;
  bool get recordsAvailable => hasRecords && recordsVerified;
  bool get deerSeasonsAvailable => hasDeerSeasons && deerSeasonsVerified;
  bool get turkeySeasonsAvailable => hasTurkeySeasons && turkeySeasonsVerified;
  bool get huntingDigestAvailable => hasHuntingDigest && huntingDigestVerified;
  
  /// True if using PDF as primary source (no HTML available)
  bool get usingHuntingPdf => !hasHuntingRegs && hasHuntingRegsPdf;
  bool get usingFishingPdf => !hasFishingRegs && hasFishingRegsPdf;
  
  factory StatePortalLinks.fromJson(Map<String, dynamic> json) {
    // Parse misc_related_urls JSONB
    List<MiscRelatedUrl>? miscUrls;
    if (json['misc_related_urls'] != null) {
      final rawList = json['misc_related_urls'] as List<dynamic>?;
      if (rawList != null) {
        miscUrls = rawList
            .map((e) => MiscRelatedUrl.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    
    // Parse discovery_confidence JSONB
    Map<String, double>? confidence;
    if (json['discovery_confidence'] != null) {
      final rawMap = json['discovery_confidence'] as Map<String, dynamic>?;
      if (rawMap != null) {
        confidence = rawMap.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
      }
    }
    
    return StatePortalLinks(
      stateCode: json['state_code'] as String,
      stateName: json['state_name'] as String? ?? '',
      agencyName: json['agency_name'] as String?,
      huntingSeasonsUrl: json['hunting_seasons_url'] as String?,
      huntingRegsUrl: json['hunting_regs_url'] as String?,
      fishingRegsUrl: json['fishing_regs_url'] as String?,
      licensingUrl: json['licensing_url'] as String?,
      buyLicenseUrl: json['buy_license_url'] as String?,
      recordsUrl: json['records_url'] as String?,
      notes: json['notes'] as String?,
      huntingSeasonsVerified: json['verified_hunting_seasons_ok'] as bool? ?? false,
      huntingRegsVerified: json['verified_hunting_regs_ok'] as bool? ?? false,
      fishingRegsVerified: json['verified_fishing_regs_ok'] as bool? ?? false,
      licensingVerified: json['verified_licensing_ok'] as bool? ?? false,
      buyLicenseVerified: json['verified_buy_license_ok'] as bool? ?? false,
      recordsVerified: json['verified_records_ok'] as bool? ?? false,
      // New species-specific hunting slots
      deerSeasonsUrl: json['deer_seasons_url'] as String?,
      turkeySeasonsUrl: json['turkey_seasons_url'] as String?,
      huntingDigestUrl: json['hunting_digest_url'] as String?,
      deerSeasonsVerified: json['verified_deer_seasons_ok'] as bool? ?? false,
      turkeySeasonsVerified: json['verified_turkey_seasons_ok'] as bool? ?? false,
      huntingDigestVerified: json['verified_hunting_digest_ok'] as bool? ?? false,
      // PDF URLs
      huntingRegsPdfUrl: json['hunting_regs_pdf_url'] as String?,
      fishingRegsPdfUrl: json['fishing_regs_pdf_url'] as String?,
      huntingRegsPdfStatus: json['hunting_regs_pdf_status'] as String?,
      fishingRegsPdfStatus: json['fishing_regs_pdf_status'] as String?,
      // Misc related URLs
      miscRelatedUrls: miscUrls,
      // Discovery metadata
      discoveryNotes: json['discovery_notes'] as String?,
      discoveryConfidence: confidence,
    );
  }
}

/// State record highlights for buck and bass.
/// Used to display premium content on state pages.
class StateRecordHighlights {
  const StateRecordHighlights({
    required this.stateCode,
    this.updatedAt,
    // Buck fields
    this.buckTitle,
    this.buckSpecies,
    this.buckScoreText,
    this.buckWeightText,
    this.buckHunterName,
    this.buckDateText,
    this.buckLocationText,
    this.buckWeapon,
    this.buckPhotoUrl,
    this.buckStorySummary,
    this.buckSourceUrl,
    this.buckSourceName,
    // Bass fields
    this.bassTitle,
    this.bassSpecies,
    this.bassWeightText,
    this.bassLengthText,
    this.bassAnglerName,
    this.bassDateText,
    this.bassLocationText,
    this.bassMethod,
    this.bassPhotoUrl,
    this.bassStorySummary,
    this.bassSourceUrl,
    this.bassSourceName,
    // Metadata
    this.dataQuality,
  });

  final String stateCode;
  final DateTime? updatedAt;
  
  // Buck (deer) record
  final String? buckTitle;
  final String? buckSpecies;
  final String? buckScoreText;
  final String? buckWeightText;
  final String? buckHunterName;
  final String? buckDateText;
  final String? buckLocationText;
  final String? buckWeapon;
  final String? buckPhotoUrl;
  final String? buckStorySummary;
  final String? buckSourceUrl;
  final String? buckSourceName;
  
  // Bass record
  final String? bassTitle;
  final String? bassSpecies;
  final String? bassWeightText;
  final String? bassLengthText;
  final String? bassAnglerName;
  final String? bassDateText;
  final String? bassLocationText;
  final String? bassMethod;
  final String? bassPhotoUrl;
  final String? bassStorySummary;
  final String? bassSourceUrl;
  final String? bassSourceName;
  
  // Metadata
  final String? dataQuality;
  
  // Convenience getters
  bool get hasBuckRecord => buckTitle != null && buckTitle!.isNotEmpty;
  bool get hasBassRecord => bassTitle != null && bassTitle!.isNotEmpty;
  bool get hasAnyRecord => hasBuckRecord || hasBassRecord;
  
  factory StateRecordHighlights.fromJson(Map<String, dynamic> json) {
    return StateRecordHighlights(
      stateCode: json['state_code'] as String,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'] as String) 
          : null,
      // Buck
      buckTitle: json['buck_title'] as String?,
      buckSpecies: json['buck_species'] as String?,
      buckScoreText: json['buck_score_text'] as String?,
      buckWeightText: json['buck_weight_text'] as String?,
      buckHunterName: json['buck_hunter_name'] as String?,
      buckDateText: json['buck_date_text'] as String?,
      buckLocationText: json['buck_location_text'] as String?,
      buckWeapon: json['buck_weapon'] as String?,
      buckPhotoUrl: json['buck_photo_url'] as String?,
      buckStorySummary: json['buck_story_summary'] as String?,
      buckSourceUrl: json['buck_source_url'] as String?,
      buckSourceName: json['buck_source_name'] as String?,
      // Bass
      bassTitle: json['bass_title'] as String?,
      bassSpecies: json['bass_species'] as String?,
      bassWeightText: json['bass_weight_text'] as String?,
      bassLengthText: json['bass_length_text'] as String?,
      bassAnglerName: json['bass_angler_name'] as String?,
      bassDateText: json['bass_date_text'] as String?,
      bassLocationText: json['bass_location_text'] as String?,
      bassMethod: json['bass_method'] as String?,
      bassPhotoUrl: json['bass_photo_url'] as String?,
      bassStorySummary: json['bass_story_summary'] as String?,
      bassSourceUrl: json['bass_source_url'] as String?,
      bassSourceName: json['bass_source_name'] as String?,
      // Metadata
      dataQuality: json['data_quality'] as String?,
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
  
  /// Public access to Supabase client for admin operations.
  dynamic get client => _supabaseService.client;
  
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
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');
    
    final response = await client.functions.invoke(
      'regulations-check-v6',
      body: {},
    );
    
    if (response.status != 200) {
      throw Exception('Failed to run checker: ${response.data}');
    }
    
    return response.data as Map<String, dynamic>;
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
    return StatePortalLinks.fromJson(response);
  }
  
  /// Fetch state record highlights (buck and bass records).
  Future<StateRecordHighlights?> fetchRecordHighlights(String stateCode) async {
    final client = _supabaseService.client;
    if (client == null) return null;
    
    final response = await client
        .from('state_record_highlights')
        .select()
        .eq('state_code', stateCode)
        .maybeSingle();
    
    if (response == null) return null;
    return StateRecordHighlights.fromJson(response);
  }
  
  /// Fetch portal links readiness for all states.
  /// Returns a map of state_code -> StateReadiness.
  Future<Map<String, StateReadiness>> fetchAllStatesReadiness() async {
    final client = _supabaseService.client;
    if (client == null) return {};
    
    final response = await client
        .from('state_portal_links')
        .select('''
          state_code,
          hunting_seasons_url, verified_hunting_seasons_ok,
          hunting_regs_url, verified_hunting_regs_ok,
          fishing_regs_url, verified_fishing_regs_ok,
          licensing_url, verified_licensing_ok,
          buy_license_url, verified_buy_license_ok,
          records_url, verified_records_ok
        ''');
    
    final result = <String, StateReadiness>{};
    
    for (final row in response as List) {
      final stateCode = row['state_code'] as String;
      
      // Count total links and verified links
      int totalLinks = 0;
      int verifiedLinks = 0;
      
      final fields = [
        ('hunting_seasons_url', 'verified_hunting_seasons_ok'),
        ('hunting_regs_url', 'verified_hunting_regs_ok'),
        ('fishing_regs_url', 'verified_fishing_regs_ok'),
        ('licensing_url', 'verified_licensing_ok'),
        ('buy_license_url', 'verified_buy_license_ok'),
        ('records_url', 'verified_records_ok'),
      ];
      
      for (final (urlField, verifiedField) in fields) {
        final url = row[urlField] as String?;
        if (url != null && url.isNotEmpty) {
          totalLinks++;
          if (row[verifiedField] == true) {
            verifiedLinks++;
          }
        }
      }
      
      result[stateCode] = StateReadiness(
        stateCode: stateCode,
        totalLinks: totalLinks,
        verifiedLinks: verifiedLinks,
      );
    }
    
    return result;
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

  // ============================================================================
  // ADMIN STATS & VERIFICATION (Simplified 2026)
  // ============================================================================

  /// Fetch admin dashboard stats.
  Future<Map<String, dynamic>> fetchAdminStats() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    // Count official roots
    final rootsResponse = await client
        .from('state_official_roots')
        .select('state_code');
    final rootsCount = (rootsResponse as List).length;

    // Count portal links and their verification status
    final linksResponse = await client
        .from('state_portal_links')
        .select('''
          state_code,
          hunting_seasons_url, verified_hunting_seasons_ok,
          hunting_regs_url, verified_hunting_regs_ok,
          fishing_regs_url, verified_fishing_regs_ok,
          licensing_url, verified_licensing_ok,
          buy_license_url, verified_buy_license_ok,
          records_url, verified_records_ok,
          deer_seasons_url, verified_deer_seasons_ok,
          turkey_seasons_url, verified_turkey_seasons_ok,
          hunting_digest_url, verified_hunting_digest_ok,
          hunting_regs_pdf_url,
          fishing_regs_pdf_url,
          misc_related_urls,
          last_verified_at
        ''');

    final portalRowsCount = (linksResponse as List).length;
    int filledFieldsCount = 0;
    int verifiedFieldsCount = 0;
    int pdfFieldsCount = 0;
    int miscRelatedCount = 0;
    int extractableStatesCount = 0;
    DateTime? lastVerified;

    for (final row in linksResponse) {
      // Count non-null URLs and their verification status
      final fields = [
        ('hunting_seasons_url', 'verified_hunting_seasons_ok'),
        ('hunting_regs_url', 'verified_hunting_regs_ok'),
        ('fishing_regs_url', 'verified_fishing_regs_ok'),
        ('licensing_url', 'verified_licensing_ok'),
        ('buy_license_url', 'verified_buy_license_ok'),
        ('records_url', 'verified_records_ok'),
        // Species-specific slots
        ('deer_seasons_url', 'verified_deer_seasons_ok'),
        ('turkey_seasons_url', 'verified_turkey_seasons_ok'),
        ('hunting_digest_url', 'verified_hunting_digest_ok'),
      ];

      for (final (urlField, verifiedField) in fields) {
        final url = row[urlField] as String?;
        if (url != null && url.isNotEmpty) {
          filledFieldsCount++;
          final isVerified = row[verifiedField] as bool? ?? false;
          if (isVerified) {
            verifiedFieldsCount++;
          }
        }
      }
      
      // Count PDF fields (not verified separately)
      final huntingPdfUrl = row['hunting_regs_pdf_url'] as String?;
      final fishingPdfUrl = row['fishing_regs_pdf_url'] as String?;
      if (huntingPdfUrl != null && huntingPdfUrl.isNotEmpty) pdfFieldsCount++;
      if (fishingPdfUrl != null && fishingPdfUrl.isNotEmpty) pdfFieldsCount++;
      
      // Count misc_related_urls
      final miscRelated = row['misc_related_urls'] as List?;
      if (miscRelated != null && miscRelated.isNotEmpty) {
        miscRelatedCount += miscRelated.length;
      }
      
      // Check if this state has any extractable source
      final hasHuntingRegs = (row['hunting_regs_url'] as String?)?.isNotEmpty ?? false;
      final hasHuntingPdf = huntingPdfUrl?.isNotEmpty ?? false;
      final hasFishingRegs = (row['fishing_regs_url'] as String?)?.isNotEmpty ?? false;
      final hasFishingPdf = fishingPdfUrl?.isNotEmpty ?? false;
      final hasDigest = (row['hunting_digest_url'] as String?)?.isNotEmpty ?? false;
      final hasMisc = miscRelated?.isNotEmpty ?? false;
      
      if (hasHuntingRegs || hasHuntingPdf || hasFishingRegs || hasFishingPdf || hasDigest || hasMisc) {
        extractableStatesCount++;
      }

      // Track last verified timestamp
      final verifiedAt = row['last_verified_at'] as String?;
      if (verifiedAt != null) {
        final dt = DateTime.tryParse(verifiedAt);
        if (dt != null && (lastVerified == null || dt.isAfter(lastVerified))) {
          lastVerified = dt;
        }
      }
    }

    // Broken = has URL but verified_ok == false and has been checked
    final brokenLinks = await fetchBrokenLinks();
    final brokenCount = brokenLinks.length;

    // Find missing portal rows (states in official_roots but not in portal_links)
    final rootStateCodes = (rootsResponse as List)
        .map((r) => r['state_code'] as String)
        .toSet();
    final portalStateCodes = (linksResponse)
        .map((r) => r['state_code'] as String)
        .toSet();
    final missingStateCodes = rootStateCodes.difference(portalStateCodes).toList()
      ..sort();

    return {
      'roots_count': rootsCount,
      'portal_rows_count': portalRowsCount,
      'filled_fields_count': filledFieldsCount,
      'verified_fields_count': verifiedFieldsCount,
      'pdf_fields_count': pdfFieldsCount,
      'misc_related_count': miscRelatedCount,
      'extractable_states_count': extractableStatesCount,
      'broken_count': brokenCount,
      'missing_state_codes': missingStateCodes,
      'last_verified_at': lastVerified?.toIso8601String(),
    };
  }

  /// Ensure all states have portal link rows.
  Future<List<String>> ensurePortalRows() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    // Get all official roots
    final rootsResponse = await client
        .from('state_official_roots')
        .select('state_code, state_name, agency_name');

    // Get existing portal links
    final linksResponse = await client
        .from('state_portal_links')
        .select('state_code');

    final existingCodes = (linksResponse as List)
        .map((r) => r['state_code'] as String)
        .toSet();

    final inserted = <String>[];

    for (final root in rootsResponse as List) {
      final stateCode = root['state_code'] as String;
      if (!existingCodes.contains(stateCode)) {
        // Insert missing portal row
        await client.from('state_portal_links').insert({
          'state_code': stateCode,
          'state_name': root['state_name'],
          'agency_name': root['agency_name'],
        });
        inserted.add(stateCode);
      }
    }

    return inserted;
  }

  // ============================================================
  // EXTRACTED FACTS
  // ============================================================

  /// Fetch extracted facts for a state and species.
  Future<ExtractedFacts?> fetchExtractedFacts({
    required String stateCode,
    required String speciesGroup,
    String regionKey = 'STATEWIDE',
  }) async {
    final client = _supabaseService.client;
    if (client == null) return null;

    final response = await client
        .from('state_regulations_extracted')
        .select()
        .eq('state_code', stateCode)
        .eq('species_group', speciesGroup)
        .eq('region_key', regionKey)
        .order('extracted_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ExtractedFacts.fromJson(response);
  }

  /// Start a new extraction run.
  /// [tier] can be 'basic' (default) or 'pro' for stronger model.
  Future<ExtractionRunStatus> startExtractionRun({String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-extract-start',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'tier': tier},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Failed to start extraction: $error');
    }

    return ExtractionRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Continue an extraction run (process next batch).
  /// [tier] can be 'basic' (default) or 'pro' for stronger model.
  Future<ExtractionRunStatus> continueExtractionRun(String runId, {String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-extract-facts',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'run_id': runId, 'tier': tier},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Extraction failed: $error');
    }

    return ExtractionRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get extraction run status.
  Future<ExtractionRunStatus?> getExtractionRunStatus(String runId) async {
    final client = _supabaseService.client;
    if (client == null) return null;

    final response = await client
        .from('reg_extraction_runs')
        .select()
        .eq('id', runId)
        .maybeSingle();

    if (response == null) return null;
    
    return ExtractionRunStatus(
      runId: response['id'] as String,
      status: response['status'] as String? ?? 'unknown',
      totalStates: response['total_states'] as int? ?? 0,
      processedStates: response['processed_states'] as int? ?? 0,
      deerPublished: response['deer_published'] as int? ?? 0,
      turkeyPublished: response['turkey_published'] as int? ?? 0,
      needsReviewCount: response['needs_review_count'] as int? ?? 0,
      skippedCount: response['skipped_count'] as int? ?? 0,
      errorCount: response['error_count'] as int? ?? 0,
      lastStateCode: response['last_state_code'] as String?,
      modelUsed: response['model_used'] as String?,
      tierUsed: response['tier_used'] as String?,
      done: response['status'] != 'running',
    );
  }

  /// Get the latest extraction run status (for resuming).
  Future<ExtractionRunStatus?> getLatestExtractionRunStatus() async {
    final client = _supabaseService.client;
    if (client == null) return null;

    final response = await client
        .from('reg_extraction_runs')
        .select()
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    
    return ExtractionRunStatus(
      runId: response['id'] as String,
      status: response['status'] as String? ?? 'unknown',
      totalStates: response['total_states'] as int? ?? 0,
      processedStates: response['processed_states'] as int? ?? 0,
      deerPublished: response['deer_published'] as int? ?? 0,
      turkeyPublished: response['turkey_published'] as int? ?? 0,
      needsReviewCount: response['needs_review_count'] as int? ?? 0,
      skippedCount: response['skipped_count'] as int? ?? 0,
      errorCount: response['error_count'] as int? ?? 0,
      lastStateCode: response['last_state_code'] as String?,
      modelUsed: response['model_used'] as String?,
      tierUsed: response['tier_used'] as String?,
      done: response['status'] != 'running',
    );
  }

  // ============================================================
  // GPT-GUIDED DISCOVERY
  // ============================================================

  /// Start a new GPT-guided discovery run.
  /// [tier] can be 'basic' (default) or 'pro' for stronger model.
  Future<DiscoveryRunStatus> startDiscoveryRun({String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-discover-start',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'tier': tier},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Failed to start discovery: $error');
    }

    return DiscoveryRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Continue a GPT-guided discovery run (process next state).
  /// [tier] can be 'basic' (default) or 'pro' for stronger model.
  Future<DiscoveryRunStatus> continueDiscoveryRun(String runId, {String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-discover-gpt',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'run_id': runId, 'tier': tier},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Discovery failed: $error');
    }

    return DiscoveryRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get the latest discovery run status (for resuming).
  Future<DiscoveryRunStatus?> getLatestDiscoveryRunStatus() async {
    final client = _supabaseService.client;
    if (client == null) return null;

    // Look for discovery runs - identified by having total_fields set (> 0)
    final response = await client
        .from('reg_repair_runs')
        .select()
        .gt('total_fields', 0)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    
    return DiscoveryRunStatus(
      runId: response['id'] as String,
      status: response['status'] as String? ?? 'unknown',
      totalStates: response['total_states'] as int? ?? 50,
      totalFields: response['total_fields'] as int? ?? 300,
      processedStates: response['processed_states'] as int? ?? 0,
      processedFields: response['processed_fields'] as int? ?? 0,
      fixedCount: response['fixed_count'] as int? ?? 0,
      skippedCount: response['skipped_count'] as int? ?? 0,
      lastStateCode: response['last_state_code'] as String?,
      done: response['status'] != 'running',
    );
  }

  /// Fetch broken links for admin dashboard.
  Future<List<Map<String, dynamic>>> fetchBrokenLinks() async {
    final client = _supabaseService.client;
    if (client == null) return [];

    final response = await client
        .from('state_portal_links')
        .select('''
          state_code,
          hunting_seasons_url, hunting_seasons_status, verified_hunting_seasons_ok,
          hunting_regs_url, hunting_regs_status, verified_hunting_regs_ok,
          fishing_regs_url, fishing_regs_status, verified_fishing_regs_ok,
          licensing_url, licensing_status, verified_licensing_ok,
          buy_license_url, buy_license_status, verified_buy_license_ok,
          records_url, records_status, verified_records_ok,
          last_verify_log
        ''')
        .order('state_code');

    final broken = <Map<String, dynamic>>[];

    for (final row in response as List) {
      final stateCode = row['state_code'] as String;
      final verifyLog = row['last_verify_log'] as Map<String, dynamic>? ?? {};

      // Check each field for broken status
      final fields = [
        ('hunting_seasons_url', 'hunting_seasons_status', 'verified_hunting_seasons_ok', 'Hunting Seasons'),
        ('hunting_regs_url', 'hunting_regs_status', 'verified_hunting_regs_ok', 'Hunting Regs'),
        ('fishing_regs_url', 'fishing_regs_status', 'verified_fishing_regs_ok', 'Fishing Regs'),
        ('licensing_url', 'licensing_status', 'verified_licensing_ok', 'Licensing'),
        ('buy_license_url', 'buy_license_status', 'verified_buy_license_ok', 'Buy License'),
        ('records_url', 'records_status', 'verified_records_ok', 'Records'),
      ];

      for (final (urlField, statusField, verifiedField, label) in fields) {
        final url = row[urlField] as String?;
        final status = row[statusField] as int?;
        final verified = row[verifiedField] as bool? ?? false;

        // Has URL, has been checked (status exists), but not verified
        if (url != null && url.isNotEmpty && status != null && !verified) {
          final fieldLog = verifyLog[urlField.replaceAll('_url', '')] as Map<String, dynamic>?;
          broken.add({
            'state_code': stateCode,
            'field': label,
            'url': url,
            'status': status,
            'error': fieldLog?['error'] as String?,
          });
        }
      }
    }

    return broken;
  }

  // ============================================================
  // SERVER-SIDE VERIFICATION (via Edge Functions)
  // ============================================================

  /// Start a new verification run (or resume existing).
  /// Returns the run_id and initial status.
  Future<VerifyRunStatus> startVerificationRun() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-verify-start',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }

    return VerifyRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Continue a verification run (processes next batch).
  /// Returns updated status.
  Future<VerifyRunStatus> continueVerificationRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-verify-continue',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'run_id': runId},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }

    return VerifyRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get the latest verification run status (for resume on page load).
  Future<VerifyRunStatus?> getLatestVerifyRunStatus() async {
    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final response = await client
          .from('reg_verify_runs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return VerifyRunStatus(
        runId: response['id'] as String,
        status: response['status'] as String,
        processedStates: response['processed_states'] as int? ?? 0,
        totalStates: response['total_states'] as int? ?? 50,
        okCount: response['ok_count'] as int? ?? 0,
        brokenCount: response['broken_count'] as int? ?? 0,
        lastStateCode: response['last_state_code'] as String?,
        done: response['status'] != 'running',
        resumed: false,
      );
    } catch (e) {
      print('Error fetching latest verify run: $e');
      return null;
    }
  }

  /// Cancel a running verification run.
  Future<void> cancelVerificationRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    await client
        .from('reg_verify_runs')
        .update({
          'status': 'canceled',
          'finished_at': DateTime.now().toIso8601String(),
        })
        .eq('id', runId);
  }

  /// Reset verification status for all portal links.
  Future<void> resetVerificationStatus() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    await client
        .from('state_portal_links')
        .update({
          'verified_hunting_seasons_ok': false,
          'verified_hunting_regs_ok': false,
          'verified_fishing_regs_ok': false,
          'verified_licensing_ok': false,
          'verified_buy_license_ok': false,
          'verified_records_ok': false,
          'hunting_seasons_status': null,
          'hunting_regs_status': null,
          'fishing_regs_status': null,
          'licensing_status': null,
          'buy_license_status': null,
          'records_status': null,
          'last_verified_at': null,
          'last_verify_log': {},
        })
        .neq('state_code', ''); // Update all rows
  }

  /// Auto-repair broken links (http->https, redirect canonicalization, etc.)
  /// Returns repair results with details.
  Future<RepairResult> repairBrokenLinks() async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-repair-broken',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return RepairResult.fromJson(data);
  }

  /// Update a single portal link URL (admin manual edit).
  Future<void> updatePortalLinkUrl({
    required String stateCode,
    required String field,
    required String newUrl,
  }) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    // Map field name to column name
    final columnMap = {
      'Hunting Seasons': 'hunting_seasons_url',
      'Hunting Regs': 'hunting_regs_url',
      'Fishing Regs': 'fishing_regs_url',
      'Licensing': 'licensing_url',
      'Buy License': 'buy_license_url',
      'Records': 'records_url',
    };

    final column = columnMap[field];
    if (column == null) throw Exception('Invalid field: $field');

    // Reset verification for this field
    final verifiedColumn = 'verified_${column.replaceAll('_url', '')}_ok';
    final statusColumn = '${column.replaceAll('_url', '')}_status';

    await client
        .from('state_portal_links')
        .update({
          column: newUrl,
          verifiedColumn: false,
          statusColumn: null,
        })
        .eq('state_code', stateCode);
  }

  /// Start a discovery repair run (or resume existing).
  Future<RepairRunStatus> startRepairRun({bool fullRebuild = false}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-repair-start',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'full_rebuild': fullRebuild},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }

    return RepairRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Continue a repair run (processes next batch using GPT classification).
  Future<RepairRunStatus> continueRepairRun(String runId, {bool fullRebuild = false}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    // Use GPT-assisted repair function for intelligent URL classification
    final response = await client.functions.invoke(
      'regs-repair-gpt',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'run_id': runId, 'full_rebuild': fullRebuild},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }

    return RepairRunStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Reset all portal sub-links (keeps official roots).
  /// Requires typing "RESET" to confirm.
  Future<void> resetPortalLinks({
    required String confirmCode,
    bool preserveLocks = true,
  }) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-reset-portal-links',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {
        'confirm_code': confirmCode,
        'preserve_locks': preserveLocks,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      if (response.status == 401) throw Exception('Please log in again');
      if (response.status == 403) throw Exception('Admin access required');
      throw Exception(error);
    }
  }

  /// Fetch official root URL for a state.
  Future<String?> getOfficialRootUrl(String stateCode) async {
    final client = _supabaseService.client;
    if (client == null) return null;

    final response = await client
        .from('state_official_roots')
        .select('official_root_url')
        .eq('state_code', stateCode)
        .maybeSingle();

    return response?['official_root_url'] as String?;
  }

  /// Get latest repair run status (for resume on page load).
  Future<RepairRunStatus?> getLatestRepairRunStatus() async {
    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final response = await client
          .from('reg_repair_runs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return RepairRunStatus(
        runId: response['id'] as String,
        status: response['status'] as String,
        totalFields: response['total_fields'] as int? ?? 0,
        processedFields: response['processed_fields'] as int? ?? 0,
        fixedCount: response['fixed_count'] as int? ?? 0,
        skippedCount: response['skipped_count'] as int? ?? 0,
        errorCount: response['error_count'] as int? ?? 0,
        lastStateCode: response['last_state_code'] as String?,
        lastField: response['last_field'] as String?,
        done: response['status'] != 'running',
        resumed: false,
      );
    } catch (e) {
      print('Error fetching latest repair run: $e');
      return null;
    }
  }

  /// Cancel a running repair run.
  Future<void> cancelRepairRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    await client
        .from('reg_repair_runs')
        .update({
          'status': 'canceled',
          'finished_at': DateTime.now().toIso8601String(),
        })
        .eq('id', runId);
  }

  /// Fetch repair run items (results).
  Future<List<RepairRunItem>> fetchRepairRunItems(String runId) async {
    final client = _supabaseService.client;
    if (client == null) return [];

    final response = await client
        .from('reg_repair_run_items')
        .select('*')
        .eq('run_id', runId)
        .order('checked_at', ascending: false);

    return (response as List)
        .map((r) => RepairRunItem.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Toggle lock for a portal link field.
  Future<void> toggleFieldLock({
    required String stateCode,
    required String field,
    required bool locked,
  }) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    // Map field to lock column
    const lockColumns = {
      'hunting_seasons_url': 'locked_hunting_seasons',
      'hunting_regs_url': 'locked_hunting_regs',
      'fishing_regs_url': 'locked_fishing_regs',
      'licensing_url': 'locked_licensing',
      'buy_license_url': 'locked_buy_license',
      'records_url': 'locked_records',
      // Also accept label names
      'Hunting Seasons': 'locked_hunting_seasons',
      'Hunting Regs': 'locked_hunting_regs',
      'Fishing Regs': 'locked_fishing_regs',
      'Licensing': 'locked_licensing',
      'Buy License': 'locked_buy_license',
      'Records': 'locked_records',
    };

    final column = lockColumns[field];
    if (column == null) throw Exception('Invalid field: $field');

    await client
        .from('state_portal_links')
        .update({column: locked})
        .eq('state_code', stateCode);
  }

  /// Fetch recent repair audit records.
  Future<List<RepairAuditRecord>> fetchRecentRepairs({int limit = 50}) async {
    final client = _supabaseService.client;
    if (client == null) return [];

    final response = await client
        .from('reg_link_repairs')
        .select('*')
        .order('repaired_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((r) => RepairAuditRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Undo a repair (roll back to old URL).
  Future<void> undoRepair(String repairId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-repair-undo',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'repair_id': repairId},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }
  }
}

/// Audit record for a GPT-assisted repair.
class RepairAuditRecord {
  const RepairAuditRecord({
    required this.id,
    required this.stateCode,
    required this.field,
    required this.oldUrl,
    this.newUrl,
    required this.status,
    this.message,
    this.pagesCrawled,
    this.candidatesFound,
    this.confidence,
    this.gptReason,
    this.validationPassed,
    this.validationReason,
    this.requiredKeywordMatched,
    this.negativeKeywordBlocked,
    this.repairedAt,
    this.runId,
  });

  final String id;
  final String stateCode;
  final String field;
  final String oldUrl;
  final String? newUrl;
  final String status; // fixed, skipped, undone
  final String? message;
  final int? pagesCrawled;
  final int? candidatesFound;
  final int? confidence;
  final String? gptReason;
  final bool? validationPassed;
  final String? validationReason;
  final bool? requiredKeywordMatched;
  final bool? negativeKeywordBlocked;
  final DateTime? repairedAt;
  final String? runId;

  /// Human-readable field label.
  String get fieldLabel {
    const labels = {
      'hunting_seasons_url': 'Hunting Seasons',
      'hunting_regs_url': 'Hunting Regs',
      'fishing_regs_url': 'Fishing Regs',
      'licensing_url': 'Licensing',
      'buy_license_url': 'Buy License',
      'records_url': 'Records',
    };
    return labels[field] ?? field;
  }

  /// Whether this repair can be undone.
  bool get canUndo => status == 'fixed';

  factory RepairAuditRecord.fromJson(Map<String, dynamic> json) {
    return RepairAuditRecord(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      field: json['field'] as String,
      oldUrl: json['old_url'] as String,
      newUrl: json['new_url'] as String?,
      status: json['status'] as String,
      message: json['message'] as String?,
      pagesCrawled: json['pages_crawled'] as int?,
      candidatesFound: json['candidates_found'] as int?,
      confidence: json['confidence'] as int?,
      gptReason: json['gpt_reason'] as String?,
      validationPassed: json['validation_passed'] as bool?,
      validationReason: json['validation_reason'] as String?,
      requiredKeywordMatched: json['required_keyword_matched'] as bool?,
      negativeKeywordBlocked: json['negative_keyword_blocked'] as bool?,
      repairedAt: json['repaired_at'] != null
          ? DateTime.tryParse(json['repaired_at'] as String)
          : null,
      runId: json['run_id'] as String?,
    );
  }
}

/// Status of a discovery repair run.
class RepairRunStatus {
  const RepairRunStatus({
    required this.runId,
    required this.status,
    required this.totalFields,
    required this.processedFields,
    required this.fixedCount,
    required this.skippedCount,
    required this.errorCount,
    this.lastStateCode,
    this.lastField,
    required this.done,
    required this.resumed,
    this.totalStates,
    this.processedStates,
    this.skipReasons,
  });

  final String runId;
  final String status; // running, done, error, canceled
  final int totalFields;
  final int processedFields;
  final int fixedCount;
  final int skippedCount;
  final int errorCount;
  final String? lastStateCode;
  final String? lastField;
  final bool done;
  final bool resumed;
  final int? totalStates;
  final int? processedStates;
  final Map<String, int>? skipReasons;

  factory RepairRunStatus.fromJson(Map<String, dynamic> json) {
    Map<String, int>? skipReasons;
    if (json['skip_reasons'] != null) {
      skipReasons = (json['skip_reasons'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    }
    
    return RepairRunStatus(
      runId: json['run_id'] as String,
      status: json['status'] as String,
      totalFields: json['total_fields'] as int? ?? 0,
      processedFields: json['processed_fields'] as int? ?? 0,
      totalStates: json['total_states'] as int?,
      processedStates: json['processed_states'] as int?,
      skipReasons: skipReasons,
      fixedCount: json['fixed_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      lastStateCode: json['last_state_code'] as String?,
      lastField: json['last_field'] as String?,
      done: json['done'] as bool? ?? false,
      resumed: json['resumed'] as bool? ?? false,
    );
  }

  /// Progress based on states (preferred) or fields.
  double get progress {
    if (totalStates != null && totalStates! > 0) {
      return (processedStates ?? 0) / totalStates!;
    }
    return totalFields > 0 ? processedFields / totalFields : 0.0;
  }
  
  int get progressPercent => (progress * 100).round().clamp(0, 100);
  bool get isRunning => status == 'running';
  bool get isComplete => status == 'done';
  
  /// Progress text showing states/total.
  String get progressText {
    if (totalStates != null && totalStates! > 0) {
      return '${processedStates ?? 0} / $totalStates states';
    }
    return '$processedFields / $totalFields fields';
  }
  
  String get lastFieldLabel {
    const labels = {
      'hunting_seasons_url': 'Hunting Seasons',
      'hunting_regs_url': 'Hunting Regs',
      'fishing_regs_url': 'Fishing Regs',
      'licensing_url': 'Licensing',
      'buy_license_url': 'Buy License',
      'records_url': 'Records',
    };
    return labels[lastField] ?? lastField ?? '';
  }
}

/// Item result from a repair run.
class RepairRunItem {
  const RepairRunItem({
    required this.runId,
    required this.stateCode,
    required this.field,
    this.oldUrl,
    this.newUrl,
    required this.status,
    this.message,
    required this.pagesCrawled,
    required this.candidatesFound,
    required this.checkedAt,
  });

  final String runId;
  final String stateCode;
  final String field;
  final String? oldUrl;
  final String? newUrl;
  final String status; // fixed, skipped, error
  final String? message;
  final int pagesCrawled;
  final int candidatesFound;
  final DateTime checkedAt;

  factory RepairRunItem.fromJson(Map<String, dynamic> json) {
    return RepairRunItem(
      runId: json['run_id'] as String,
      stateCode: json['state_code'] as String,
      field: json['field'] as String,
      oldUrl: json['old_url'] as String?,
      newUrl: json['new_url'] as String?,
      status: json['status'] as String,
      message: json['message'] as String?,
      pagesCrawled: json['pages_crawled'] as int? ?? 0,
      candidatesFound: json['candidates_found'] as int? ?? 0,
      checkedAt: DateTime.parse(json['checked_at'] as String),
    );
  }

  bool get isFixed => status == 'fixed';
  
  String get fieldLabel {
    const labels = {
      'hunting_seasons_url': 'Hunting Seasons',
      'hunting_regs_url': 'Hunting Regs',
      'fishing_regs_url': 'Fishing Regs',
      'licensing_url': 'Licensing',
      'buy_license_url': 'Buy License',
      'records_url': 'Records',
    };
    return labels[field] ?? field;
  }
}

/// Result of auto-repair operation.
class RepairResult {
  const RepairResult({
    required this.checked,
    required this.repaired,
    required this.stillBroken,
    required this.details,
  });

  final int checked;
  final int repaired;
  final int stillBroken;
  final List<RepairDetail> details;

  factory RepairResult.fromJson(Map<String, dynamic> json) {
    final detailsList = (json['details'] as List? ?? [])
        .map((d) => RepairDetail.fromJson(d as Map<String, dynamic>))
        .toList();
    return RepairResult(
      checked: json['checked'] as int? ?? 0,
      repaired: json['repaired'] as int? ?? 0,
      stillBroken: json['still_broken'] as int? ?? 0,
      details: detailsList,
    );
  }
}

/// Detail of a single repair action.
class RepairDetail {
  const RepairDetail({
    required this.state,
    required this.field,
    required this.action,
    required this.from,
    required this.to,
  });

  final String state;
  final String field;
  final String action;
  final String from;
  final String to;

  factory RepairDetail.fromJson(Map<String, dynamic> json) {
    return RepairDetail(
      state: json['state'] as String? ?? '',
      field: json['field'] as String? ?? '',
      action: json['action'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
    );
  }

  String get actionLabel {
    switch (action) {
      case 'http_to_https':
        return 'HTTP → HTTPS';
      case 'add_trailing_slash':
        return 'Added trailing slash';
      case 'redirect_canonicalized':
        return 'Redirect canonicalized';
      default:
        return action;
    }
  }
}

/// Result of discovery-based repair operation.
class DiscoveryRepairResult {
  const DiscoveryRepairResult({
    required this.runId,
    required this.processed,
    required this.fixed,
    required this.stillBroken,
    required this.results,
  });

  final String runId;
  final int processed;
  final int fixed;
  final int stillBroken;
  final List<DiscoveryRepairItem> results;

  factory DiscoveryRepairResult.fromJson(Map<String, dynamic> json) {
    final resultsList = (json['results'] as List? ?? [])
        .map((r) => DiscoveryRepairItem.fromJson(r as Map<String, dynamic>))
        .toList();
    return DiscoveryRepairResult(
      runId: json['run_id'] as String? ?? '',
      processed: json['processed'] as int? ?? 0,
      fixed: json['fixed'] as int? ?? 0,
      stillBroken: json['still_broken'] as int? ?? 0,
      results: resultsList,
    );
  }
}

/// Single item from discovery repair.
class DiscoveryRepairItem {
  const DiscoveryRepairItem({
    required this.state,
    required this.field,
    required this.status,
    this.oldUrl,
    this.newUrl,
    this.message,
  });

  final String state;
  final String field;
  final String status; // fixed, no_candidate
  final String? oldUrl;
  final String? newUrl;
  final String? message;

  factory DiscoveryRepairItem.fromJson(Map<String, dynamic> json) {
    return DiscoveryRepairItem(
      state: json['state'] as String? ?? '',
      field: json['field'] as String? ?? '',
      status: json['status'] as String? ?? '',
      oldUrl: json['oldUrl'] as String?,
      newUrl: json['newUrl'] as String?,
      message: json['message'] as String?,
    );
  }

  bool get isFixed => status == 'fixed';
}

/// Repair report entry from database.
class RepairReportEntry {
  const RepairReportEntry({
    required this.id,
    required this.stateCode,
    required this.field,
    this.oldUrl,
    this.newUrl,
    required this.status,
    this.message,
    required this.pagesCrawled,
    required this.candidatesFound,
    required this.repairedAt,
    this.runId,
  });

  final String id;
  final String stateCode;
  final String field;
  final String? oldUrl;
  final String? newUrl;
  final String status;
  final String? message;
  final int pagesCrawled;
  final int candidatesFound;
  final DateTime repairedAt;
  final String? runId;

  factory RepairReportEntry.fromJson(Map<String, dynamic> json) {
    return RepairReportEntry(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      field: json['field'] as String,
      oldUrl: json['old_url'] as String?,
      newUrl: json['new_url'] as String?,
      status: json['status'] as String,
      message: json['message'] as String?,
      pagesCrawled: json['pages_crawled'] as int? ?? 0,
      candidatesFound: json['candidates_found'] as int? ?? 0,
      repairedAt: DateTime.parse(json['repaired_at'] as String),
      runId: json['run_id'] as String?,
    );
  }

  bool get isFixed => status == 'fixed';
  
  String get fieldLabel {
    const labels = {
      'hunting_seasons_url': 'Hunting Seasons',
      'hunting_regs_url': 'Hunting Regs',
      'fishing_regs_url': 'Fishing Regs',
      'licensing_url': 'Licensing',
      'buy_license_url': 'Buy License',
      'records_url': 'Records',
    };
    return labels[field] ?? field;
  }
}

/// Readiness status for a state's portal links.
class StateReadiness {
  const StateReadiness({
    required this.stateCode,
    required this.totalLinks,
    required this.verifiedLinks,
  });
  
  final String stateCode;
  final int totalLinks;
  final int verifiedLinks;
  
  /// True if at least one link is verified.
  bool get isReady => verifiedLinks > 0;
  
  /// True if has links but none verified.
  bool get needsVerification => totalLinks > 0 && verifiedLinks == 0;
  
  /// True if no links at all.
  bool get isUnavailable => totalLinks == 0;
  
  /// Status label for display.
  String get statusLabel {
    if (isReady) return 'Ready';
    if (needsVerification) return 'Needs Verify';
    return 'Unavailable';
  }
  
  /// Detail label (e.g., "3/5 verified").
  String get detailLabel {
    if (totalLinks == 0) return 'No links';
    return '$verifiedLinks/$totalLinks verified';
  }
}

// ============================================================
// EXTRACTED FACTS MODELS
// ============================================================

/// Season segment from extracted data.
class ExtractedSeason {
  const ExtractedSeason({
    required this.name,
    this.start,
    this.end,
    this.methods = const [],
    this.notes,
  });
  
  final String name;
  final String? start;
  final String? end;
  final List<String> methods;
  final String? notes;
  
  factory ExtractedSeason.fromJson(Map<String, dynamic> json) {
    return ExtractedSeason(
      name: json['name'] as String? ?? '',
      start: json['start'] as String?,
      end: json['end'] as String?,
      methods: (json['methods'] as List?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes'] as String?,
    );
  }
}

/// Bag limit from extracted data.
class ExtractedBagLimit {
  const ExtractedBagLimit({
    required this.label,
    required this.value,
    this.notes,
  });
  
  final String label;
  final String value;
  final String? notes;
  
  factory ExtractedBagLimit.fromJson(Map<String, dynamic> json) {
    return ExtractedBagLimit(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }
}

/// Extracted regulation facts for a state/species.
class ExtractedFacts {
  const ExtractedFacts({
    required this.id,
    required this.stateCode,
    required this.speciesGroup,
    required this.regionKey,
    required this.seasonYearLabel,
    required this.sourceUrl,
    required this.extractedAt,
    required this.confidenceScore,
    this.seasons = const [],
    this.bagLimits = const [],
    this.legalMethods = const [],
    this.notes = const [],
  });
  
  final String id;
  final String stateCode;
  final String speciesGroup;
  final String regionKey;
  final String seasonYearLabel;
  final String sourceUrl;
  final DateTime extractedAt;
  final double confidenceScore;
  final List<ExtractedSeason> seasons;
  final List<ExtractedBagLimit> bagLimits;
  final List<String> legalMethods;
  final List<String> notes;
  
  /// Has useful content to display.
  bool get hasContent => seasons.isNotEmpty || bagLimits.isNotEmpty || legalMethods.isNotEmpty;
  
  /// Confidence as percentage string.
  String get confidencePercent => '${(confidenceScore * 100).toStringAsFixed(0)}%';
  
  factory ExtractedFacts.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    return ExtractedFacts(
      id: json['id'] as String,
      stateCode: json['state_code'] as String,
      speciesGroup: json['species_group'] as String,
      regionKey: json['region_key'] as String? ?? 'STATEWIDE',
      seasonYearLabel: json['season_year_label'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      extractedAt: DateTime.tryParse(json['extracted_at'] as String? ?? '') ?? DateTime.now(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      seasons: (data['seasons'] as List?)
          ?.map((e) => ExtractedSeason.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      bagLimits: (data['bag_limits'] as List?)
          ?.map((e) => ExtractedBagLimit.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      legalMethods: (data['legal_methods'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      notes: (data['notes'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}

/// Extraction run status.
class ExtractionRunStatus {
  const ExtractionRunStatus({
    required this.runId,
    required this.status,
    required this.totalStates,
    required this.processedStates,
    required this.deerPublished,
    required this.turkeyPublished,
    required this.needsReviewCount,
    required this.skippedCount,
    required this.errorCount,
    this.lastStateCode,
    this.modelUsed,
    this.tierUsed,
    required this.done,
  });
  
  final String runId;
  final String status;
  final int totalStates;
  final int processedStates;
  final int deerPublished;
  final int turkeyPublished;
  final int needsReviewCount;
  final int skippedCount;
  final int errorCount;
  final String? lastStateCode;
  final String? modelUsed;
  final String? tierUsed;
  final bool done;
  
  bool get isRunning => status == 'running';
  
  double get progress => totalStates > 0 ? processedStates / totalStates : 0.0;
  
  String get progressLabel => '$processedStates/$totalStates states';
  
  String get summaryLabel {
    final parts = <String>[];
    if (deerPublished > 0) parts.add('$deerPublished deer');
    if (turkeyPublished > 0) parts.add('$turkeyPublished turkey');
    if (needsReviewCount > 0) parts.add('$needsReviewCount needs review');
    if (skippedCount > 0) parts.add('$skippedCount skipped');
    return parts.isEmpty ? 'Processing...' : parts.join(', ');
  }
  
  factory ExtractionRunStatus.fromJson(Map<String, dynamic> json) {
    return ExtractionRunStatus(
      runId: json['run_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      totalStates: json['total_states'] as int? ?? 0,
      processedStates: json['processed_states'] as int? ?? 0,
      deerPublished: json['deer_published'] as int? ?? 0,
      turkeyPublished: json['turkey_published'] as int? ?? 0,
      needsReviewCount: json['needs_review_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      lastStateCode: json['last_state_code'] as String?,
      modelUsed: json['model_used'] as String?,
      tierUsed: json['tier_used'] as String?,
      done: json['done'] as bool? ?? false,
    );
  }
}

/// Discovery run status (GPT-guided crawler).
class DiscoveryRunStatus {
  const DiscoveryRunStatus({
    required this.runId,
    required this.status,
    required this.totalStates,
    required this.totalFields,
    required this.processedStates,
    required this.processedFields,
    required this.fixedCount,
    required this.skippedCount,
    this.lastStateCode,
    this.modelUsed,
    this.tierUsed,
    required this.done,
  });
  
  final String runId;
  final String status;
  final int totalStates;
  final int totalFields;
  final int processedStates;
  final int processedFields;
  final int fixedCount;
  final int skippedCount;
  final String? lastStateCode;
  final String? modelUsed;
  final String? tierUsed;
  final bool done;
  
  bool get isRunning => status == 'running';
  
  double get progress => totalStates > 0 ? processedStates / totalStates : 0.0;
  
  String get progressLabel => '$processedStates/$totalStates states';
  
  String get fieldsLabel => '$fixedCount/$totalFields filled';
  
  factory DiscoveryRunStatus.fromJson(Map<String, dynamic> json) {
    return DiscoveryRunStatus(
      runId: json['run_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      totalStates: json['total_states'] as int? ?? 50,
      totalFields: json['total_fields'] as int? ?? 300,
      processedStates: json['processed_states'] as int? ?? 0,
      processedFields: json['processed_fields'] as int? ?? 0,
      fixedCount: json['fixed_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      lastStateCode: json['last_state_code'] as String?,
      modelUsed: json['model_used'] as String?,
      tierUsed: json['tier_used'] as String?,
      done: json['done'] as bool? ?? false,
    );
  }
}

// ============================================================
// JOB QUEUE-BASED RUNS (Worker Service)
// ============================================================

/// Status of a job queue-based admin run.
class AdminRunStatus {
  const AdminRunStatus({
    required this.runId,
    required this.type,
    required this.tier,
    required this.status,
    required this.progressDone,
    required this.progressTotal,
    this.lastState,
    this.lastMessage,
    this.errorMessage,
    required this.jobs,
    required this.active,
    required this.done,
    this.createdAt,
    this.stoppedAt,
  });
  
  final String runId;
  final String type; // discover, extract, verify
  final String tier; // basic, pro
  final String status; // queued, running, stopping, stopped, completed, failed
  final int progressDone;
  final int progressTotal;
  final String? lastState;
  final String? lastMessage;
  final String? errorMessage;
  final Map<String, int> jobs; // queued, running, done, failed, skipped, canceled
  final bool active;
  final bool done;
  final DateTime? createdAt;
  final DateTime? stoppedAt;
  
  double get progress => progressTotal > 0 ? progressDone / progressTotal : 0.0;
  bool get isRunning => active;
  
  String get progressLabel => '$progressDone/$progressTotal';
  
  /// Number of jobs that can still be stopped (queued or running)
  int get stoppableJobCount => (jobs['queued'] ?? 0) + (jobs['running'] ?? 0);
  
  /// True if there are jobs that can be stopped
  bool get hasStoppableJobs => stoppableJobCount > 0;
  
  /// True if all jobs are in terminal states (done, failed, skipped, canceled)
  bool get allJobsTerminal {
    final queued = jobs['queued'] ?? 0;
    final running = jobs['running'] ?? 0;
    return queued == 0 && running == 0;
  }
  
  /// True if the run was stopped (has canceled jobs)
  bool get wasStopped => (jobs['canceled'] ?? 0) > 0;
  
  String get summaryLabel {
    final parts = <String>[];
    if (jobs['done'] != null && jobs['done']! > 0) parts.add('${jobs['done']} done');
    if (jobs['failed'] != null && jobs['failed']! > 0) parts.add('${jobs['failed']} failed');
    if (jobs['skipped'] != null && jobs['skipped']! > 0) parts.add('${jobs['skipped']} skipped');
    // Show canceled with explanation
    if (jobs['canceled'] != null && jobs['canceled']! > 0) {
      parts.add('${jobs['canceled']} skipped (stopped)');
    }
    return parts.isEmpty ? 'Processing...' : parts.join(', ');
  }
  
  /// Status label for display (finished/stopped/running)
  String get statusLabel {
    if (done) {
      if (wasStopped) return 'Stopped';
      if (status == 'failed') return 'Failed';
      return 'Completed';
    }
    if (status == 'stopping') return 'Stopping...';
    return 'Running';
  }
  
  factory AdminRunStatus.fromJson(Map<String, dynamic> json) {
    final jobsMap = <String, int>{};
    final jobsData = json['jobs'] as Map<String, dynamic>?;
    if (jobsData != null) {
      for (final entry in jobsData.entries) {
        jobsMap[entry.key] = entry.value as int? ?? 0;
      }
    }
    
    return AdminRunStatus(
      runId: json['run_id'] as String? ?? '',
      type: json['type'] as String? ?? 'discover',
      tier: json['tier'] as String? ?? 'basic',
      status: json['status'] as String? ?? 'queued',
      progressDone: json['progress_done'] as int? ?? 0,
      progressTotal: json['progress_total'] as int? ?? 0,
      lastState: json['last_state'] as String?,
      lastMessage: json['last_message'] as String?,
      errorMessage: json['error_message'] as String?,
      jobs: jobsMap,
      active: json['active'] as bool? ?? false,
      done: json['done'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      stoppedAt: json['stopped_at'] != null
          ? DateTime.tryParse(json['stopped_at'] as String)
          : null,
    );
  }
}

extension RegulationsServiceJobQueue on RegulationsService {
  /// Start a new job queue-based discovery run.
  /// This creates jobs that are processed by the worker service.
  Future<AdminRunStatus> startJobQueueDiscoveryRun({String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    // Create or get active run
    String runId;
    final existingRun = await client
        .from('regs_admin_runs')
        .select()
        .eq('type', 'discover')
        .inFilter('status', ['queued', 'running'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existingRun != null) {
      runId = existingRun['id'] as String;
    } else {
      // Create new run
      final newRun = await client
          .from('regs_admin_runs')
          .insert({
            'type': 'discover',
            'tier': tier,
            'status': 'running',
            'progress_total': 50,
          })
          .select()
          .single();
      runId = newRun['id'] as String;
    }

    // Enqueue all 50 states using RPC
    final enqueueResult = await client.rpc(
      'regs_enqueue_discovery_all_states',
      params: {
        'p_run_id': runId,
        'p_tier': tier,
      },
    );

    final queuedCount = enqueueResult as int? ?? 0;

    // Get updated status - but don't fail if status fetch fails
    // Jobs are already enqueued, so we can build status from what we know
    final status = await getJobQueueRunStatus(runId: runId);
    if (status != null) {
      return status;
    }

    // Fallback: build status from run record and job counts
    // This ensures we never fail after successfully enqueueing
    final runRecord = await client
        .from('regs_admin_runs')
        .select()
        .eq('id', runId)
        .maybeSingle();

    if (runRecord == null) {
      throw Exception('Run not found after enqueue');
    }

    // Get job counts directly
    final jobs = await client
        .from('regs_jobs')
        .select('status')
        .eq('run_id', runId)
        .eq('job_type', 'discover_state');

    final jobsMap = <String, int>{};
    for (final job in jobs) {
      final jobStatus = job['status'] as String;
      jobsMap[jobStatus] = (jobsMap[jobStatus] ?? 0) + 1;
    }

    final runStatus = runRecord['status'] as String;
    final done = runStatus == 'completed' || runStatus == 'stopped' || runStatus == 'failed';
    final active = runStatus == 'running' || runStatus == 'queued' || runStatus == 'stopping';

    return AdminRunStatus(
      runId: runId,
      type: runRecord['type'] as String? ?? 'discover',
      tier: runRecord['tier'] as String? ?? tier,
      status: runStatus,
      progressDone: (jobsMap['done'] ?? 0) + (jobsMap['failed'] ?? 0) + (jobsMap['skipped'] ?? 0) + (jobsMap['canceled'] ?? 0),
      progressTotal: runRecord['progress_total'] as int? ?? 50,
      lastState: runRecord['last_state'] as String?,
      lastMessage: runRecord['last_message'] as String?,
      errorMessage: runRecord['error_message'] as String?,
      jobs: jobsMap,
      active: active,
      done: done,
      createdAt: runRecord['created_at'] != null
          ? DateTime.tryParse(runRecord['created_at'] as String)
          : null,
      stoppedAt: runRecord['stopped_at'] != null
          ? DateTime.tryParse(runRecord['stopped_at'] as String)
          : null,
    );
  }

  /// Resume a discovery run by enqueueing missing states.
  Future<AdminRunStatus> resumeDiscoveryRun(String runId, {String tier = 'pro'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    // Ensure run exists and is resumable
    final run = await client
        .from('regs_admin_runs')
        .select()
        .eq('id', runId)
        .maybeSingle();

    if (run == null) {
      throw Exception('Run not found');
    }

    final runStatus = run['status'] as String;
    if (runStatus == 'completed' || runStatus == 'failed') {
      throw Exception('Cannot resume a completed or failed run');
    }

    // Update run status to running if needed
    if (runStatus != 'running') {
      await client
          .from('regs_admin_runs')
          .update({'status': 'running'})
          .eq('id', runId);
    }

    // Enqueue missing states (RPC handles duplicates)
    final enqueueResult = await client.rpc(
      'regs_enqueue_discovery_all_states',
      params: {
        'p_run_id': runId,
        'p_tier': tier,
      },
    );

    final queuedCount = enqueueResult as int? ?? 0;

    // Get updated status - but don't fail if status fetch fails
    final status = await getJobQueueRunStatus(runId: runId);
    if (status != null) {
      return status;
    }

    // Fallback: build status from run record and job counts
    final runRecord = await client
        .from('regs_admin_runs')
        .select()
        .eq('id', runId)
        .maybeSingle();

    if (runRecord == null) {
      throw Exception('Run not found after resume');
    }

    // Get job counts directly
    final jobs = await client
        .from('regs_jobs')
        .select('status')
        .eq('run_id', runId)
        .eq('job_type', 'discover_state');

    final jobsMap = <String, int>{};
    for (final job in jobs) {
      final jobStatus = job['status'] as String;
      jobsMap[jobStatus] = (jobsMap[jobStatus] ?? 0) + 1;
    }

    final resumeRunStatus = runRecord['status'] as String;
    final done = resumeRunStatus == 'completed' || resumeRunStatus == 'stopped' || resumeRunStatus == 'failed';
    final active = resumeRunStatus == 'running' || resumeRunStatus == 'queued' || resumeRunStatus == 'stopping';

    return AdminRunStatus(
      runId: runId,
      type: runRecord['type'] as String? ?? 'discover',
      tier: runRecord['tier'] as String? ?? tier,
      status: resumeRunStatus,
      progressDone: (jobsMap['done'] ?? 0) + (jobsMap['failed'] ?? 0) + (jobsMap['skipped'] ?? 0) + (jobsMap['canceled'] ?? 0),
      progressTotal: runRecord['progress_total'] as int? ?? 50,
      lastState: runRecord['last_state'] as String?,
      lastMessage: runRecord['last_message'] as String?,
      errorMessage: runRecord['error_message'] as String?,
      jobs: jobsMap,
      active: active,
      done: done,
      createdAt: runRecord['created_at'] != null
          ? DateTime.tryParse(runRecord['created_at'] as String)
          : null,
      stoppedAt: runRecord['stopped_at'] != null
          ? DateTime.tryParse(runRecord['stopped_at'] as String)
          : null,
    );
  }

  /// Start a new job queue-based extraction run.
  Future<AdminRunStatus> startJobQueueExtractionRun({String tier = 'basic'}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    // Create or get active extraction run
    String runId;
    final existingRun = await client
        .from('regs_admin_runs')
        .select()
        .eq('type', 'extract')
        .inFilter('status', ['queued', 'running'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existingRun != null) {
      runId = existingRun['id'] as String;
    } else {
      // Create new run
      final newRun = await client
          .from('regs_admin_runs')
          .insert({
            'type': 'extract',
            'tier': tier,
            'status': 'running',
            'progress_total': 0, // Will be updated by RPC
          })
          .select()
          .single();
      runId = newRun['id'] as String;
    }

    // Enqueue extraction jobs for all states with sources
    final enqueueResult = await client.rpc(
      'regs_enqueue_extraction_all_states',
      params: {
        'p_run_id': runId,
        'p_tier': tier,
      },
    );

    final queuedCount = enqueueResult as int? ?? 0;

    // Get updated status
    final status = await getJobQueueRunStatus(runId: runId);
    if (status != null) {
      return status;
    }

    // Fallback: build status from what we know
    return AdminRunStatus(
      runId: runId,
      type: 'extract',
      tier: tier,
      status: 'running',
      progressDone: 0,
      progressTotal: queuedCount,
      jobs: {'queued': queuedCount, 'running': 0, 'done': 0, 'failed': 0, 'skipped': 0, 'canceled': 0},
      active: true,
      done: false,
    );
  }

  /// Stop a job queue-based run.
  Future<void> stopJobQueueRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    // Update run status to stopping
    await client
        .from('regs_admin_runs')
        .update({
          'status': 'stopping',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', runId);
  }

  /// Get status of a job queue-based run.
  Future<AdminRunStatus?> getJobQueueRunStatus({String? runId}) async {
    final client = _supabaseService.client;
    if (client == null) return null;

    final session = _supabaseService.currentSession;
    if (session == null) return null;

    try {
      // If no runId provided, find latest active run (any type)
      String? actualRunId = runId;
      if (actualRunId == null) {
        final latestRun = await client
            .from('regs_admin_runs')
            .select('id')
            .inFilter('status', ['queued', 'running', 'stopping'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        
        if (latestRun == null) return null;
        actualRunId = latestRun['id'] as String;
      }

      // Get run details
      final run = await client
          .from('regs_admin_runs')
          .select()
          .eq('id', actualRunId)
          .maybeSingle();

      if (run == null) return null;

      // Determine job type based on run type
      final runType = run['type'] as String? ?? 'discover';
      final jobType = runType == 'extract' ? 'extract_state_species' : 'discover_state';

      // Get accurate progress from RPC (only for discovery runs)
      Map<String, dynamic> progressResult = <String, dynamic>{
        'total_expected': run['progress_total'] as int? ?? 50,
        'done_count': 0,
        'running_count': 0,
        'queued_count': 0,
        'failed_count': 0,
        'skipped_count': 0,
        'canceled_count': 0,
      };

      if (runType == 'discover') {
        try {
          final progressResultList = await client.rpc(
            'regs_get_discovery_progress',
            params: {'p_run_id': actualRunId},
          ) as List<dynamic>?;

          if (progressResultList != null && progressResultList.isNotEmpty) {
            progressResult = progressResultList[0] as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint('[RegulationsService] RPC progress failed, using job counts: $e');
        }
      }

      // Get job counts by status
      final jobs = await client
          .from('regs_jobs')
          .select('status')
          .eq('run_id', actualRunId)
          .eq('job_type', jobType);

      final jobsMap = <String, int>{};
      for (final job in jobs) {
        final status = job['status'] as String;
        jobsMap[status] = (jobsMap[status] ?? 0) + 1;
      }

      // Use RPC progress if available, otherwise compute from jobs
      final doneCount = progressResult['done_count'] as int? ?? 
          (jobsMap['done'] ?? 0) + (jobsMap['failed'] ?? 0) + (jobsMap['skipped'] ?? 0) + (jobsMap['canceled'] ?? 0);
      final totalExpected = progressResult['total_expected'] as int? ?? 
          (run['progress_total'] as int? ?? (runType == 'extract' ? 88 : 50));

      // Build AdminRunStatus from run + progress
      final status = run['status'] as String;
      final done = status == 'completed' || status == 'stopped' || status == 'failed';
      final active = status == 'running' || status == 'queued' || status == 'stopping';

      return AdminRunStatus(
        runId: actualRunId,
        type: run['type'] as String? ?? 'discover',
        tier: run['tier'] as String? ?? 'basic',
        status: status,
        progressDone: doneCount,
        progressTotal: totalExpected,
        lastState: run['last_state'] as String?,
        lastMessage: run['last_message'] as String?,
        errorMessage: run['error_message'] as String?,
        jobs: jobsMap,
        active: active,
        done: done,
        createdAt: run['created_at'] != null
            ? DateTime.tryParse(run['created_at'] as String)
            : null,
        stoppedAt: run['stopped_at'] != null
            ? DateTime.tryParse(run['stopped_at'] as String)
            : null,
      );
    } catch (e) {
      debugPrint('[RegulationsService] Error getting run status: $e');
      // If we have a runId, try to build status from run record directly
      if (runId != null) {
        try {
          final runRecord = await client
              .from('regs_admin_runs')
              .select()
              .eq('id', runId)
              .maybeSingle();

          if (runRecord != null) {
            // Determine job type based on run type
            final runType = runRecord['type'] as String? ?? 'discover';
            final jobType = runType == 'extract' ? 'extract_state_species' : 'discover_state';

            // Get job counts directly
            final jobs = await client
                .from('regs_jobs')
                .select('status')
                .eq('run_id', runId)
                .eq('job_type', jobType);

            final jobsMap = <String, int>{};
            for (final job in jobs) {
              final jobStatus = job['status'] as String;
              jobsMap[jobStatus] = (jobsMap[jobStatus] ?? 0) + 1;
            }

            final fallbackRunStatus = runRecord['status'] as String;
            final done = fallbackRunStatus == 'completed' || fallbackRunStatus == 'stopped' || fallbackRunStatus == 'failed';
            final active = fallbackRunStatus == 'running' || fallbackRunStatus == 'queued' || fallbackRunStatus == 'stopping';

            return AdminRunStatus(
              runId: runId,
              type: runType,
              tier: runRecord['tier'] as String? ?? 'basic',
              status: fallbackRunStatus,
              progressDone: (jobsMap['done'] ?? 0) + (jobsMap['failed'] ?? 0) + (jobsMap['skipped'] ?? 0) + (jobsMap['canceled'] ?? 0),
              progressTotal: runRecord['progress_total'] as int? ?? (runType == 'extract' ? 88 : 50),
              lastState: runRecord['last_state'] as String?,
              lastMessage: runRecord['last_message'] as String?,
              errorMessage: runRecord['error_message'] as String?,
              jobs: jobsMap,
              active: active,
              done: done,
              createdAt: runRecord['created_at'] != null
                  ? DateTime.tryParse(runRecord['created_at'] as String)
                  : null,
              stoppedAt: runRecord['stopped_at'] != null
                  ? DateTime.tryParse(runRecord['stopped_at'] as String)
                  : null,
            );
          }
        } catch (fallbackError) {
          debugPrint('[RegulationsService] Fallback status fetch also failed: $fallbackError');
        }
      }
      return null;
    }
  }

  /// Get the latest active job queue run (for resuming on page load).
  Future<AdminRunStatus?> getLatestActiveRun() async {
    return getJobQueueRunStatus();
  }

  /// Full reset: delete all portal links and reseed from official roots.
  /// This is the most thorough reset - clears everything except official roots.
  Future<Map<String, dynamic>> resetFull({required String confirmCode}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-reset-full',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'confirm_code': confirmCode},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Full reset failed: $error');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Reset verification only: clears verification flags and status codes.
  /// Keeps all URLs intact.
  Future<Map<String, dynamic>> resetVerification({required String confirmCode}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-reset-verify',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'confirm_code': confirmCode},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Verification reset failed: $error');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Legacy reset method (deprecated - use resetFull or resetVerification).
  Future<Map<String, dynamic>> resetData({
    required String type,
    required String confirmCode,
  }) async {
    // Route to appropriate new method
    if (type == 'full') {
      return resetFull(confirmCode: confirmCode);
    } else if (type == 'verification') {
      return resetVerification(confirmCode: confirmCode);
    }
    
    // For 'extracted', fall back to old method
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final session = _supabaseService.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await client.functions.invoke(
      'regs-reset',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'type': type, 'confirm_code': confirmCode},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception('Reset failed: $error');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Requeue stuck jobs in a discovery run.
  /// This clears stale locks and ensures the run is in 'running' state.
  Future<Map<String, dynamic>> requeDiscoveryRun(String runId, {int stuckMinutes = 15}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final result = await client.rpc(
      'regs_admin_requeue_run',
      params: {
        'p_run_id': runId,
        'p_stuck_minutes': stuckMinutes,
      },
    );

    // RPC returns TABLE, so result is a list
    final resultList = result as List<dynamic>?;
    if (resultList == null || resultList.isEmpty) {
      return {'requeued_stuck': 0, 'locks_cleared': 0, 'run_status_set': 'running'};
    }
    return resultList[0] as Map<String, dynamic>;
  }

  /// Force restart a discovery run by requeuing all non-terminal jobs.
  Future<Map<String, dynamic>> forceRestartDiscoveryRun(String runId) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    final result = await client.rpc(
      'regs_admin_force_restart_run',
      params: {'p_run_id': runId},
    );

    final resultList = result as List<dynamic>?;
    if (resultList == null || resultList.isEmpty) {
      return {'jobs_requeued': 0, 'run_status': 'running'};
    }
    return resultList[0] as Map<String, dynamic>;
  }

  /// Get worker health status.
  Future<WorkerHealthStatus?> getWorkerHealth() async {
    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final result = await client.rpc('regs_get_worker_health');
      final resultList = result as List<dynamic>?;
      if (resultList == null || resultList.isEmpty) {
        return null;
      }
      final row = resultList[0] as Map<String, dynamic>;
      return WorkerHealthStatus(
        workerId: row['worker_id'] as String? ?? 'unknown',
        activeJobs: row['active_jobs'] as int? ?? 0,
        totalClaimed: row['total_claimed'] as int? ?? 0,
        totalCompleted: row['total_completed'] as int? ?? 0,
        lastHeartbeat: row['last_heartbeat'] != null 
            ? DateTime.tryParse(row['last_heartbeat'] as String)
            : null,
        lastClaimAt: row['last_claim_at'] != null
            ? DateTime.tryParse(row['last_claim_at'] as String)
            : null,
        lastProgressAt: row['last_progress_at'] != null
            ? DateTime.tryParse(row['last_progress_at'] as String)
            : null,
        secondsSinceHeartbeat: row['seconds_since_heartbeat'] as int? ?? 999,
        secondsSinceClaim: row['seconds_since_claim'] as int? ?? 9999,
        secondsSinceProgress: row['seconds_since_progress'] as int? ?? 9999,
        isHealthy: row['is_healthy'] as bool? ?? false,
        isStalled: row['is_stalled'] as bool? ?? false,
        isOffline: row['is_offline'] as bool? ?? true,
        hostname: row['hostname'] as String?,
        version: row['version'] as String?,
        loopsCount: row['loops_count'] as int? ?? 0,
      );
    } catch (e) {
      print('[RegulationsService] Error getting worker health: $e');
      return null;
    }
  }

  /// Issue a command to the worker (restart, stop, etc).
  Future<String?> issueWorkerCommand(String command, {String? targetWorkerId}) async {
    final client = _supabaseService.client;
    if (client == null) throw Exception('Not connected');

    try {
      final result = await client.rpc(
        'regs_issue_worker_command',
        params: {
          'p_command': command,
          'p_target_worker_id': targetWorkerId,
        },
      );
      return result as String?;
    } catch (e) {
      print('[RegulationsService] Error issuing worker command: $e');
      rethrow;
    }
  }
}

/// Worker health status with stall detection.
class WorkerHealthStatus {
  final String workerId;
  final int activeJobs;
  final int totalClaimed;
  final int totalCompleted;
  final DateTime? lastHeartbeat;
  final DateTime? lastClaimAt;
  final DateTime? lastProgressAt;
  final int secondsSinceHeartbeat;
  final int secondsSinceClaim;
  final int secondsSinceProgress;
  final bool isHealthy;
  final bool isStalled;
  final bool isOffline;
  final String? hostname;
  final String? version;
  final int loopsCount;

  WorkerHealthStatus({
    required this.workerId,
    required this.activeJobs,
    required this.totalClaimed,
    required this.totalCompleted,
    this.lastHeartbeat,
    this.lastClaimAt,
    this.lastProgressAt,
    required this.secondsSinceHeartbeat,
    required this.secondsSinceClaim,
    required this.secondsSinceProgress,
    required this.isHealthy,
    required this.isStalled,
    required this.isOffline,
    this.hostname,
    this.version,
    required this.loopsCount,
  });

  /// Derived state for display
  WorkerState get state {
    if (isOffline) return WorkerState.offline;
    if (isStalled) return WorkerState.stalled;
    if (isHealthy) return WorkerState.running;
    return WorkerState.unknown;
  }

  String get statusLabel {
    switch (state) {
      case WorkerState.running:
        if (activeJobs > 0) {
          return 'Running ($activeJobs active)';
        }
        return 'Running (idle)';
      case WorkerState.stalled:
        final mins = (secondsSinceProgress / 60).floor();
        return 'Stalled — no progress for ${mins}m';
      case WorkerState.offline:
        if (secondsSinceHeartbeat > 3600) {
          final hours = (secondsSinceHeartbeat / 3600).floor();
          return 'Offline — last seen ${hours}h ago';
        }
        final mins = (secondsSinceHeartbeat / 60).floor();
        return 'Offline — last seen ${mins}m ago';
      case WorkerState.unknown:
        return 'Unknown';
    }
  }

  String get shortLabel {
    switch (state) {
      case WorkerState.running:
        return 'Running';
      case WorkerState.stalled:
        return 'Stalled';
      case WorkerState.offline:
        return 'Offline';
      case WorkerState.unknown:
        return 'Unknown';
    }
  }
}

enum WorkerState {
  running,
  stalled,
  offline,
  unknown,
}

/// Provider for regulations service.
final regulationsServiceProvider = Provider<RegulationsService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RegulationsService(supabaseService);
});

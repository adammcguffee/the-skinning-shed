/// 🗓️ Season utilities for species-aware season bucketing.
/// 
/// Hunting seasons (deer, turkey, other_game) span two calendar years,
/// typically from fall of one year to spring of the next.
/// Example: "2025-26" season starts Aug 2025 and ends ~Jul 2026.
/// 
/// Fishing seasons (bass, other_fishing) use calendar years.
/// Example: "2026" for all harvests in calendar year 2026.

/// Season type based on species category.
enum SeasonType {
  /// Hunting seasons span two years (Aug Y to Jul Y+1 = "Y-Y+1 Season")
  huntingSeason,
  
  /// Fishing uses calendar years ("2026")
  calendarYear,
}

/// Represents a season with its label and year range.
class Season {
  const Season({
    required this.type,
    required this.label,
    required this.yearStart,
    this.yearEnd,
  });
  
  final SeasonType type;
  final String label;
  final int yearStart;
  final int? yearEnd; // Only for hunting seasons
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Season &&
          type == other.type &&
          yearStart == other.yearStart;
  
  @override
  int get hashCode => type.hashCode ^ yearStart.hashCode;
}

/// Utility class for season computations.
class SeasonUtils {
  SeasonUtils._();
  
  /// Get season type for a species category.
  /// 
  /// [category] should be 'game' or 'fish' from species_master.
  static SeasonType getSeasonType(String? category) {
    if (category == 'fish') {
      return SeasonType.calendarYear;
    }
    return SeasonType.huntingSeason;
  }
  
  /// Get season type for a trophy category.
  /// 
  /// [subcategory] should be 'deer', 'turkey', 'bass', 'other_game', 'other_fishing'.
  static SeasonType getSeasonTypeFromSubcategory(String? subcategory) {
    if (subcategory == 'bass' || subcategory == 'other_fishing') {
      return SeasonType.calendarYear;
    }
    return SeasonType.huntingSeason;
  }
  
  /// Compute season from harvest date and season type.
  /// 
  /// For hunting seasons: Aug-Dec = current year start, Jan-Jul = previous year start.
  /// For calendar years: just the year of the harvest date.
  static Season computeSeason(DateTime harvestDate, SeasonType type) {
    if (type == SeasonType.calendarYear) {
      return Season(
        type: type,
        label: harvestDate.year.toString(),
        yearStart: harvestDate.year,
      );
    }
    
    // Hunting season: Aug 1 of year Y to Jul 31 of year Y+1 = "Y-(Y+1)" season
    final int seasonYearStart;
    if (harvestDate.month >= 8) {
      // Aug-Dec: this year is the season start
      seasonYearStart = harvestDate.year;
    } else {
      // Jan-Jul: previous year is the season start
      seasonYearStart = harvestDate.year - 1;
    }
    
    final yearEnd = seasonYearStart + 1;
    final shortEnd = yearEnd.toString().substring(2); // "26" from 2026
    
    return Season(
      type: type,
      label: '$seasonYearStart-$shortEnd',
      yearStart: seasonYearStart,
      yearEnd: yearEnd,
    );
  }
  
  /// Compute season label from harvest date and species category.
  static String computeSeasonLabel(DateTime harvestDate, String? category) {
    final type = getSeasonType(category);
    final season = computeSeason(harvestDate, type);
    return season.label;
  }
  
  /// Generate season options for filters based on season type.
  /// 
  /// Returns a list of seasons from current back to [yearsBack].
  static List<Season> generateSeasonOptions({
    required SeasonType type,
    int yearsBack = 3,
  }) {
    final now = DateTime.now();
    final seasons = <Season>[];
    
    if (type == SeasonType.calendarYear) {
      // Calendar years: 2026, 2025, 2024, ...
      for (int i = 0; i <= yearsBack; i++) {
        final year = now.year - i;
        seasons.add(Season(
          type: type,
          label: year.toString(),
          yearStart: year,
        ));
      }
    } else {
      // Hunting seasons: determine current season
      final currentSeasonStart = now.month >= 8 ? now.year : now.year - 1;
      
      for (int i = 0; i <= yearsBack; i++) {
        final yearStart = currentSeasonStart - i;
        final yearEnd = yearStart + 1;
        final shortEnd = yearEnd.toString().substring(2);
        seasons.add(Season(
          type: type,
          label: '$yearStart-$shortEnd',
          yearStart: yearStart,
          yearEnd: yearEnd,
        ));
      }
    }
    
    return seasons;
  }
  
  /// Check if a harvest date falls within a specific season.
  static bool isInSeason(DateTime harvestDate, Season season) {
    if (season.type == SeasonType.calendarYear) {
      return harvestDate.year == season.yearStart;
    }
    
    // Hunting season: Aug Y to Jul Y+1
    if (harvestDate.month >= 8) {
      return harvestDate.year == season.yearStart;
    } else {
      return harvestDate.year == season.yearEnd;
    }
  }
}

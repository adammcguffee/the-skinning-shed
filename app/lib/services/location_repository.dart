import '../data/us_counties.dart';
import '../data/us_states.dart';

/// 📍 LOCATION REPOSITORY — Single source of truth for US states & counties
///
/// Use this repository (or the Riverpod providers) for all location data.
/// DO NOT hardcode state/county lists in screens.
class LocationRepository {
  const LocationRepository._();

  /// Singleton instance
  static const instance = LocationRepository._();

  /// Get all US states (50 states + DC)
  List<USState> getStates() => USStates.all;

  /// Get a state by its abbreviation code
  USState? getStateByCode(String code) => USStates.byCode(code);

  /// Get a state by its full name
  USState? getStateByName(String name) => USStates.byName(name);

  /// Search states by query (matches code or name)
  List<USState> searchStates(String query) => USStates.search(query);

  /// Get counties for a state by abbreviation code
  List<String> getCountiesForState(String stateCode) {
    return USCounties.forState(stateCode);
  }

  /// Check if county data is available for a state
  bool hasCountiesFor(String stateCode) {
    return USCounties.hasCountiesFor(stateCode);
  }

  /// Search counties within a state
  List<String> searchCounties(String stateCode, String query) {
    final counties = getCountiesForState(stateCode);
    if (query.isEmpty) return counties;
    final q = query.toLowerCase();
    return counties.where((c) => c.toLowerCase().contains(q)).toList();
  }
}

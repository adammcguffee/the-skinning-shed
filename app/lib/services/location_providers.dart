import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/us_counties.dart';
import '../data/us_states.dart';
import 'location_repository.dart';

/// 📍 LOCATION PROVIDERS — Riverpod providers for location data
///
/// Use these providers throughout the app for consistent state/county access.

/// Location repository provider
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository.instance;
});

/// All US states provider
final statesProvider = Provider<List<USState>>((ref) {
  return ref.watch(locationRepositoryProvider).getStates();
});

/// Counties for a specific state provider (family)
final countiesProvider = Provider.family<List<String>, String?>((ref, stateCode) {
  if (stateCode == null || stateCode.isEmpty) return [];
  return ref.watch(locationRepositoryProvider).getCountiesForState(stateCode);
});

/// Check if counties are available for a state
final hasCountiesProvider = Provider.family<bool, String?>((ref, stateCode) {
  if (stateCode == null || stateCode.isEmpty) return false;
  return ref.watch(locationRepositoryProvider).hasCountiesFor(stateCode);
});

/// State lookup by code
final stateByCodeProvider = Provider.family<USState?, String?>((ref, code) {
  if (code == null || code.isEmpty) return null;
  return ref.watch(locationRepositoryProvider).getStateByCode(code);
});

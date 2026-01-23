import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Service for species-related operations.
class SpeciesService {
  SpeciesService(this._client);
  
  final SupabaseClient? _client;
  
  /// Fetch all active species.
  Future<List<Map<String, dynamic>>> fetchAllSpecies() async {
    if (_client == null) return [];
    
    final response = await _client
        .from('species_master')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Fetch species by category (deer, turkey, bass, etc.).
  Future<List<Map<String, dynamic>>> fetchByCategory(String category) async {
    if (_client == null) return [];
    
    final response = await _client
        .from('species_master')
        .select()
        .eq('subcategory', category)
        .eq('is_active', true)
        .order('sort_order');
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Fetch a single species by ID.
  Future<Map<String, dynamic>?> fetchSpecies(String id) async {
    if (_client == null) return null;
    
    final response = await _client
        .from('species_master')
        .select()
        .eq('id', id)
        .single();
    
    return response;
  }
}

/// Provider for species service.
final speciesServiceProvider = Provider<SpeciesService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SpeciesService(client);
});

/// Provider for all species.
final allSpeciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(speciesServiceProvider);
  return service.fetchAllSpecies();
});

/// Provider for species by category.
final speciesByCategoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, category) async {
  final service = ref.watch(speciesServiceProvider);
  return service.fetchByCategory(category);
});

/// Grouped species data structure.
class SpeciesGroups {
  SpeciesGroups({
    required this.deer,
    required this.turkey,
    required this.bass,
    required this.otherGame,
    required this.otherFishing,
  });
  
  final List<Map<String, dynamic>> deer;
  final List<Map<String, dynamic>> turkey;
  final List<Map<String, dynamic>> bass;
  final List<Map<String, dynamic>> otherGame;
  final List<Map<String, dynamic>> otherFishing;
  
  static SpeciesGroups fromList(List<Map<String, dynamic>> species) {
    return SpeciesGroups(
      deer: species.where((s) => s['subcategory'] == 'deer').toList(),
      turkey: species.where((s) => s['subcategory'] == 'turkey').toList(),
      bass: species.where((s) => s['subcategory'] == 'bass').toList(),
      otherGame: species.where((s) => s['subcategory'] == 'other_game').toList(),
      otherFishing: species.where((s) => s['subcategory'] == 'other_fishing').toList(),
    );
  }
}

/// Provider for grouped species.
final groupedSpeciesProvider = FutureProvider<SpeciesGroups>((ref) async {
  final species = await ref.watch(allSpeciesProvider.future);
  return SpeciesGroups.fromList(species);
});

import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/background_theme.dart';
import 'package:shed/services/background_theme_store.dart';

/// Provider for current background theme ID
final backgroundThemeIdProvider = StateNotifierProvider<BackgroundThemeNotifier, BackgroundThemeId>(
  (ref) => BackgroundThemeNotifier(),
);

/// Provider for current background theme spec
final backgroundThemeSpecProvider = Provider<BackgroundThemeSpec>((ref) {
  final id = ref.watch(backgroundThemeIdProvider);
  return BackgroundThemes.getById(id);
});

/// Provider for favorite theme IDs
final backgroundThemeFavoritesProvider = FutureProvider<Set<BackgroundThemeId>>((ref) async {
  return BackgroundThemeStore.getFavorites();
});

/// Provider for include minimal in random setting
final includeMinimalInRandomProvider = FutureProvider<bool>((ref) async {
  return BackgroundThemeStore.getIncludeMinimalInRandom();
});

/// Notifier for background theme state
class BackgroundThemeNotifier extends StateNotifier<BackgroundThemeId> {
  BackgroundThemeNotifier() : super(BackgroundThemes.defaultId) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final savedId = await BackgroundThemeStore.getThemeId();
    state = savedId;
  }

  Future<void> setTheme(BackgroundThemeId id) async {
    state = id;
    await BackgroundThemeStore.setThemeId(id);
  }

  /// Set random theme (excluding minimal unless enabled)
  Future<void> setRandomTheme(bool includeMinimal) async {
    final allThemes = BackgroundThemes.all;
    final availableThemes = includeMinimal
        ? allThemes
        : allThemes.where((t) => t.category != BackgroundThemeCategory.classicMinimal).toList();
    
    if (availableThemes.isEmpty) {
      return;
    }

    final random = math.Random();
    final randomTheme = availableThemes[random.nextInt(availableThemes.length)];
    await setTheme(randomTheme.id);
  }
}

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
}

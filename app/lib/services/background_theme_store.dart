import 'package:shared_preferences/shared_preferences.dart';
import 'package:shed/app/theme/background_theme.dart';

/// Persistence store for background theme selection
class BackgroundThemeStore {
  BackgroundThemeStore._();

  static const _keyThemeId = 'background_theme_id';
  static const _keyFavorites = 'background_theme_favorites';
  static const _keyIncludeMinimalInRandom = 'background_theme_include_minimal_random';

  /// Get the saved theme ID, or default if not set
  static Future<BackgroundThemeId> getThemeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idString = prefs.getString(_keyThemeId);
      if (idString == null) {
        return BackgroundThemes.defaultId;
      }
      
      // Parse enum from string
      return BackgroundThemeId.values.firstWhere(
        (id) => id.name == idString,
        orElse: () => BackgroundThemes.defaultId,
      );
    } catch (e) {
      return BackgroundThemes.defaultId;
    }
  }

  /// Save the theme ID
  static Future<void> setThemeId(BackgroundThemeId id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeId, id.name);
    } catch (e) {
      // Silently fail - theme will reset to default on next load
    }
  }

  /// Get favorite theme IDs
  static Future<Set<BackgroundThemeId>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList(_keyFavorites) ?? [];
      return favoritesList
          .map((name) {
            try {
              return BackgroundThemeId.values.firstWhere((id) => id.name == name);
            } catch (e) {
              return null;
            }
          })
          .whereType<BackgroundThemeId>()
          .toSet();
    } catch (e) {
      return <BackgroundThemeId>{};
    }
  }

  /// Save favorite theme IDs
  static Future<void> setFavorites(Set<BackgroundThemeId> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _keyFavorites,
        favorites.map((id) => id.name).toList(),
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Toggle favorite status for a theme
  static Future<void> toggleFavorite(BackgroundThemeId id) async {
    final favorites = await getFavorites();
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    await setFavorites(favorites);
  }

  /// Get whether to include minimal themes in random selection
  static Future<bool> getIncludeMinimalInRandom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIncludeMinimalInRandom) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set whether to include minimal themes in random selection
  static Future<void> setIncludeMinimalInRandom(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeMinimalInRandom, value);
    } catch (e) {
      // Silently fail
    }
  }
}

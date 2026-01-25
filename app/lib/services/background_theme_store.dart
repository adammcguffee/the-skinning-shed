import 'package:shared_preferences/shared_preferences.dart';
import 'package:shed/app/theme/background_theme.dart';

/// Persistence store for background theme selection
class BackgroundThemeStore {
  BackgroundThemeStore._();

  static const _keyThemeId = 'background_theme_id';

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
}

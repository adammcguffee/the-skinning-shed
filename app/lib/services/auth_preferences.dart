import 'package:shared_preferences/shared_preferences.dart';

/// Persisted auth preferences.
class AuthPreferences {
  AuthPreferences._();

  static const _keepSignedInKey = 'keep_signed_in';

  static Future<bool> getKeepSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepSignedInKey) ?? true;
  }

  static Future<void> setKeepSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, value);
  }
}

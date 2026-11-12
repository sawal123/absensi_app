import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan penerimaan kebijakan privasi per pengguna.
abstract final class ConsentStore {
  static const _version = 1;

  static String _key(int userId) => 'consent_v${_version}_$userId';

  static Future<bool> hasConsent(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> accept(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}

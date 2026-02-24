import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Persists [AppSettings] to device storage via SharedPreferences.
class AppSettingsService {
  static const _key = 'app_settings';

  /// Load saved settings, or return [AppSettings.defaults] if none exist.
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppSettings.defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  /// Persist [settings] to device storage.
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

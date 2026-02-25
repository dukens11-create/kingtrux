import 'package:shared_preferences/shared_preferences.dart';

/// Controls when the app switches to the dark/night UI theme.
enum NightModeOption {
  /// Automatically switch to night mode between 20:00 and 05:59 local time.
  auto,

  /// Always use the dark/night theme regardless of the time.
  alwaysOn,

  /// Always use the light/day theme regardless of the time.
  alwaysOff,
}

/// Persists [NightModeOption] to device storage via [SharedPreferences].
class NightModeSettingsService {
  static const _key = 'night_mode_option';

  /// Returns `true` if [now] falls within the nighttime window (20:00–05:59).
  static bool isNightByTime(DateTime now) {
    return now.hour >= 20 || now.hour < 6;
  }

  /// Load the persisted [NightModeOption].
  ///
  /// Returns [NightModeOption.auto] when no value has been saved or on error.
  Future<NightModeOption> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return NightModeOption.values.firstWhere(
        (o) => o.name == raw,
        orElse: () => NightModeOption.auto,
      );
    } catch (_) {
      return NightModeOption.auto;
    }
  }

  /// Persist [option] to device storage.
  Future<void> save(NightModeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }
}

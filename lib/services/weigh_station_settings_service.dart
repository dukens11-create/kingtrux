import 'package:shared_preferences/shared_preferences.dart';
import 'weigh_station_monitor.dart';

// =============================================================================
// WeighStationSettings
// =============================================================================

/// Driver-configurable settings for the weigh-station feature.
class WeighStationSettings {
  const WeighStationSettings({
    this.showOnMap = false,
    this.enableAlerts = false,
    this.alertDistanceMeters = WeighStationMonitor.defaultThresholdMeters,
    this.alertOnUnknownStatus = false,
    this.enableTts = false,
    this.enableSubmissionPrompts = false,
  });

  /// Whether weigh station markers are shown on the map.
  final bool showOnMap;

  /// Whether proximity alerts are enabled at all.
  ///
  /// Disabled by default; requires the user to opt in.
  final bool enableAlerts;

  /// Distance in metres at which the proximity alert fires.
  ///
  /// Preset values are 804.7 m (~0.5 mi), 1609.3 m (~1 mi),
  /// 3218.7 m (~2 mi), and 8046.7 m (~5 mi).
  final double alertDistanceMeters;

  /// Whether to alert when station status is [WeighStationStatus.unknown].
  ///
  /// When `false`, alerts only fire for stations explicitly marked as active.
  final bool alertOnUnknownStatus;

  /// Whether the proximity alert should also be spoken aloud via TTS.
  final bool enableTts;

  /// Whether to show a crowdsourcing prompt when the driver is within
  /// [WeighStationMonitor.submissionProximityMeters] of a station.
  final bool enableSubmissionPrompts;

  /// Return a copy with specified fields overridden.
  WeighStationSettings copyWith({
    bool? showOnMap,
    bool? enableAlerts,
    double? alertDistanceMeters,
    bool? alertOnUnknownStatus,
    bool? enableTts,
    bool? enableSubmissionPrompts,
  }) {
    return WeighStationSettings(
      showOnMap: showOnMap ?? this.showOnMap,
      enableAlerts: enableAlerts ?? this.enableAlerts,
      alertDistanceMeters: alertDistanceMeters ?? this.alertDistanceMeters,
      alertOnUnknownStatus: alertOnUnknownStatus ?? this.alertOnUnknownStatus,
      enableTts: enableTts ?? this.enableTts,
      enableSubmissionPrompts:
          enableSubmissionPrompts ?? this.enableSubmissionPrompts,
    );
  }
}

// =============================================================================
// WeighStationSettingsService
// =============================================================================

/// Persists [WeighStationSettings] to device storage via [SharedPreferences].
class WeighStationSettingsService {
  static const _keyShowOnMap = 'weigh_station_show_on_map';
  static const _keyEnable = 'weigh_station_enable_alerts';
  static const _keyDistance = 'weigh_station_alert_distance';
  static const _keyUnknown = 'weigh_station_alert_on_unknown';
  static const _keyTts = 'weigh_station_enable_tts';
  static const _keySubmissionPrompts = 'weigh_station_enable_submission_prompts';

  /// Load persisted settings.
  ///
  /// Returns all-defaults ([WeighStationSettings()]) when no saved values are
  /// found or on error.  All alert-related toggles default to `false` so the
  /// feature is opt-in and respects notification permissions.
  Future<WeighStationSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return WeighStationSettings(
        showOnMap: prefs.getBool(_keyShowOnMap) ?? false,
        enableAlerts: prefs.getBool(_keyEnable) ?? false,
        alertDistanceMeters: prefs.getDouble(_keyDistance) ??
            WeighStationMonitor.defaultThresholdMeters,
        alertOnUnknownStatus: prefs.getBool(_keyUnknown) ?? false,
        enableTts: prefs.getBool(_keyTts) ?? false,
        enableSubmissionPrompts:
            prefs.getBool(_keySubmissionPrompts) ?? false,
      );
    } catch (_) {
      return const WeighStationSettings();
    }
  }

  /// Persist [settings] to device storage.
  Future<void> save(WeighStationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowOnMap, settings.showOnMap);
    await prefs.setBool(_keyEnable, settings.enableAlerts);
    await prefs.setDouble(_keyDistance, settings.alertDistanceMeters);
    await prefs.setBool(_keyUnknown, settings.alertOnUnknownStatus);
    await prefs.setBool(_keyTts, settings.enableTts);
    await prefs.setBool(
        _keySubmissionPrompts, settings.enableSubmissionPrompts);
  }
}

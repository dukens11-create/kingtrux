import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings for the Weigh Station feature.
class WeighStationSettings {
  const WeighStationSettings({
    this.showOnMap = true,
    this.alertsEnabled = false,
    this.alertThresholdMeters = 4828.0,
  });

  /// Whether weigh station markers are shown on the map.
  final bool showOnMap;

  /// Whether proximity alerts are enabled.
  ///
  /// Defaults to `false` so drivers are not surprised by alerts before
  /// granting notification permission.
  final bool alertsEnabled;

  /// Distance in metres at which a proximity alert fires.
  ///
  /// Default: ~3 miles (4 828 m).
  final double alertThresholdMeters;

  WeighStationSettings copyWith({
    bool? showOnMap,
    bool? alertsEnabled,
    double? alertThresholdMeters,
  }) =>
      WeighStationSettings(
        showOnMap: showOnMap ?? this.showOnMap,
        alertsEnabled: alertsEnabled ?? this.alertsEnabled,
        alertThresholdMeters:
            alertThresholdMeters ?? this.alertThresholdMeters,
      );
}

/// Persists [WeighStationSettings] in [SharedPreferences].
class WeighStationSettingsService {
  static const _keyShowOnMap = 'ws_show_on_map';
  static const _keyAlertsEnabled = 'ws_alerts_enabled';
  static const _keyThreshold = 'ws_alert_threshold_meters';

  /// Load saved settings, returning defaults when no values are stored.
  Future<WeighStationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WeighStationSettings(
      showOnMap: prefs.getBool(_keyShowOnMap) ?? true,
      alertsEnabled: prefs.getBool(_keyAlertsEnabled) ?? false,
      alertThresholdMeters:
          prefs.getDouble(_keyThreshold) ?? 4828.0,
    );
  }

  /// Persist [settings].
  Future<void> save(WeighStationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowOnMap, settings.showOnMap);
    await prefs.setBool(_keyAlertsEnabled, settings.alertsEnabled);
    await prefs.setDouble(
        _keyThreshold, settings.alertThresholdMeters);
  }
}

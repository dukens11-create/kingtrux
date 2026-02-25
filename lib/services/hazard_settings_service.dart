import 'package:shared_preferences/shared_preferences.dart';

/// In-navigation hazard alert settings.
class HazardSettings {
  const HazardSettings({
    this.enableLowBridgeWarnings = true,
    this.enableSharpCurveWarnings = true,
    this.enableDowngradeHillWarnings = true,
    this.enableWorkZoneWarnings = true,
    this.enableTruckCrossingWarnings = true,
    this.enableWildAnimalCrossingWarnings = true,
    this.enableSchoolZoneWarnings = true,
    this.enableStopSignWarnings = true,
    this.enableRailroadCrossingWarnings = true,
    this.enableSlipperyRoadWarnings = true,
    this.enableMergingTrafficWarnings = true,
    this.enableFallingRocksWarnings = true,
    this.enableNarrowBridgeWarnings = true,
    this.enableTruckRolloverWarnings = true,
    this.enableTunnelWarnings = true,
    this.enableHazardTts = true,
  });

  /// Whether to show alerts for low bridges / height restrictions.
  final bool enableLowBridgeWarnings;

  /// Whether to show alerts for sharp curves.
  final bool enableSharpCurveWarnings;

  /// Whether to show alerts for steep downgrade hills.
  final bool enableDowngradeHillWarnings;

  /// Whether to show alerts for road work zones.
  final bool enableWorkZoneWarnings;

  /// Whether to show alerts for truck crossing signs.
  final bool enableTruckCrossingWarnings;

  /// Whether to show alerts for deer/wild animal migration crossings.
  final bool enableWildAnimalCrossingWarnings;

  /// Whether to show alerts for school zones and crosswalks.
  final bool enableSchoolZoneWarnings;

  /// Whether to show alerts for stop signs on the route.
  final bool enableStopSignWarnings;

  /// Whether to show alerts for railroad/train crossings.
  final bool enableRailroadCrossingWarnings;

  /// Whether to show alerts for slippery road conditions.
  final bool enableSlipperyRoadWarnings;

  /// Whether to show alerts for merging traffic.
  final bool enableMergingTrafficWarnings;

  /// Whether to show alerts for falling rocks zones.
  final bool enableFallingRocksWarnings;

  /// Whether to show alerts for narrow bridges.
  final bool enableNarrowBridgeWarnings;

  /// Whether to show alerts for truck rollover warning signs (sharp turns, steep ramps).
  final bool enableTruckRolloverWarnings;

  /// Whether to show alerts for tunnels (height restrictions, hazmat, etc.).
  final bool enableTunnelWarnings;

  /// Whether hazard alerts should be spoken aloud.
  ///
  /// Both this flag **and** the global voice-guidance toggle must be true for
  /// TTS to fire.
  final bool enableHazardTts;

  /// Return a copy with the specified fields overridden.
  HazardSettings copyWith({
    bool? enableLowBridgeWarnings,
    bool? enableSharpCurveWarnings,
    bool? enableDowngradeHillWarnings,
    bool? enableWorkZoneWarnings,
    bool? enableTruckCrossingWarnings,
    bool? enableWildAnimalCrossingWarnings,
    bool? enableSchoolZoneWarnings,
    bool? enableStopSignWarnings,
    bool? enableRailroadCrossingWarnings,
    bool? enableSlipperyRoadWarnings,
    bool? enableMergingTrafficWarnings,
    bool? enableFallingRocksWarnings,
    bool? enableNarrowBridgeWarnings,
    bool? enableTruckRolloverWarnings,
    bool? enableTunnelWarnings,
    bool? enableHazardTts,
  }) {
    return HazardSettings(
      enableLowBridgeWarnings:
          enableLowBridgeWarnings ?? this.enableLowBridgeWarnings,
      enableSharpCurveWarnings:
          enableSharpCurveWarnings ?? this.enableSharpCurveWarnings,
      enableDowngradeHillWarnings:
          enableDowngradeHillWarnings ?? this.enableDowngradeHillWarnings,
      enableWorkZoneWarnings:
          enableWorkZoneWarnings ?? this.enableWorkZoneWarnings,
      enableTruckCrossingWarnings:
          enableTruckCrossingWarnings ?? this.enableTruckCrossingWarnings,
      enableWildAnimalCrossingWarnings: enableWildAnimalCrossingWarnings ??
          this.enableWildAnimalCrossingWarnings,
      enableSchoolZoneWarnings:
          enableSchoolZoneWarnings ?? this.enableSchoolZoneWarnings,
      enableStopSignWarnings:
          enableStopSignWarnings ?? this.enableStopSignWarnings,
      enableRailroadCrossingWarnings:
          enableRailroadCrossingWarnings ?? this.enableRailroadCrossingWarnings,
      enableSlipperyRoadWarnings:
          enableSlipperyRoadWarnings ?? this.enableSlipperyRoadWarnings,
      enableMergingTrafficWarnings:
          enableMergingTrafficWarnings ?? this.enableMergingTrafficWarnings,
      enableFallingRocksWarnings:
          enableFallingRocksWarnings ?? this.enableFallingRocksWarnings,
      enableNarrowBridgeWarnings:
          enableNarrowBridgeWarnings ?? this.enableNarrowBridgeWarnings,
      enableTruckRolloverWarnings:
          enableTruckRolloverWarnings ?? this.enableTruckRolloverWarnings,
      enableTunnelWarnings:
          enableTunnelWarnings ?? this.enableTunnelWarnings,
      enableHazardTts: enableHazardTts ?? this.enableHazardTts,
    );
  }
}

/// Persists [HazardSettings] to device storage via [SharedPreferences].
class HazardSettingsService {
  static const _keyLowBridge = 'hazard_enable_low_bridge';
  static const _keySharpCurve = 'hazard_enable_sharp_curve';
  static const _keyDowngradeHill = 'hazard_enable_downgrade_hill';
  static const _keyWorkZone = 'hazard_enable_work_zone';
  static const _keyTruckCrossing = 'hazard_enable_truck_crossing';
  static const _keyWildAnimalCrossing = 'hazard_enable_wild_animal_crossing';
  static const _keySchoolZone = 'hazard_enable_school_zone';
  static const _keyStopSign = 'hazard_enable_stop_sign';
  static const _keyRailroadCrossing = 'hazard_enable_railroad_crossing';
  static const _keySlipperyRoad = 'hazard_enable_slippery_road';
  static const _keyMergingTraffic = 'hazard_enable_merging_traffic';
  static const _keyFallingRocks = 'hazard_enable_falling_rocks';
  static const _keyNarrowBridge = 'hazard_enable_narrow_bridge';
  static const _keyTruckRollover = 'hazard_enable_truck_rollover';
  static const _keyTunnel = 'hazard_enable_tunnel';
  static const _keyHazardTts = 'hazard_enable_tts';

  /// Load persisted hazard settings.
  ///
  /// Returns all-defaults ([HazardSettings()]) when no saved values are found
  /// or on error.
  Future<HazardSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return HazardSettings(
        enableLowBridgeWarnings: prefs.getBool(_keyLowBridge) ?? true,
        enableSharpCurveWarnings: prefs.getBool(_keySharpCurve) ?? true,
        enableDowngradeHillWarnings: prefs.getBool(_keyDowngradeHill) ?? true,
        enableWorkZoneWarnings: prefs.getBool(_keyWorkZone) ?? true,
        enableTruckCrossingWarnings: prefs.getBool(_keyTruckCrossing) ?? true,
        enableWildAnimalCrossingWarnings:
            prefs.getBool(_keyWildAnimalCrossing) ?? true,
        enableSchoolZoneWarnings: prefs.getBool(_keySchoolZone) ?? true,
        enableStopSignWarnings: prefs.getBool(_keyStopSign) ?? true,
        enableRailroadCrossingWarnings:
            prefs.getBool(_keyRailroadCrossing) ?? true,
        enableSlipperyRoadWarnings: prefs.getBool(_keySlipperyRoad) ?? true,
        enableMergingTrafficWarnings: prefs.getBool(_keyMergingTraffic) ?? true,
        enableFallingRocksWarnings: prefs.getBool(_keyFallingRocks) ?? true,
        enableNarrowBridgeWarnings: prefs.getBool(_keyNarrowBridge) ?? true,
        enableTruckRolloverWarnings: prefs.getBool(_keyTruckRollover) ?? true,
        enableTunnelWarnings: prefs.getBool(_keyTunnel) ?? true,
        enableHazardTts: prefs.getBool(_keyHazardTts) ?? true,
      );
    } catch (_) {
      return const HazardSettings();
    }
  }

  /// Persist [settings] to device storage.
  Future<void> save(HazardSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowBridge, settings.enableLowBridgeWarnings);
    await prefs.setBool(_keySharpCurve, settings.enableSharpCurveWarnings);
    await prefs.setBool(_keyDowngradeHill, settings.enableDowngradeHillWarnings);
    await prefs.setBool(_keyWorkZone, settings.enableWorkZoneWarnings);
    await prefs.setBool(_keyTruckCrossing, settings.enableTruckCrossingWarnings);
    await prefs.setBool(
        _keyWildAnimalCrossing, settings.enableWildAnimalCrossingWarnings);
    await prefs.setBool(_keySchoolZone, settings.enableSchoolZoneWarnings);
    await prefs.setBool(_keyStopSign, settings.enableStopSignWarnings);
    await prefs.setBool(
        _keyRailroadCrossing, settings.enableRailroadCrossingWarnings);
    await prefs.setBool(_keySlipperyRoad, settings.enableSlipperyRoadWarnings);
    await prefs.setBool(
        _keyMergingTraffic, settings.enableMergingTrafficWarnings);
    await prefs.setBool(_keyFallingRocks, settings.enableFallingRocksWarnings);
    await prefs.setBool(_keyNarrowBridge, settings.enableNarrowBridgeWarnings);
    await prefs.setBool(_keyTruckRollover, settings.enableTruckRolloverWarnings);
    await prefs.setBool(_keyTunnel, settings.enableTunnelWarnings);
    await prefs.setBool(_keyHazardTts, settings.enableHazardTts);
  }
}

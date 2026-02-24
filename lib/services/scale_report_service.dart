import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scale_report.dart';

/// Persists driver-submitted scale status reports to device storage.
class ScaleReportService {
  static const _key = 'scale_reports';

  /// Load all persisted scale reports.
  ///
  /// Returns an empty list if no reports are saved or if data is corrupt.
  Future<List<ScaleReport>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScaleReport.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist [reports] to device storage.
  Future<void> save(List<ScaleReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(reports.map((r) => r.toJson()).toList()),
    );
  }
}

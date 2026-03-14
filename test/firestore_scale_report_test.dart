import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/scale_report.dart';

// ---------------------------------------------------------------------------
// FirestoreScaleReportService logic tests
//
// Tests that exercise the pure status-mapping logic without requiring a live
// Firebase connection. Firebase-dependent integration tests require a real
// (or emulated) Firestore instance and are run separately.
// ---------------------------------------------------------------------------

void main() {
  group('ScaleStatus string mapping', () {
    // The mapping is exercised indirectly through ScaleReport.fromJson and
    // the status name property since FirestoreScaleReportService uses the same
    // mapping internally.

    test('ScaleStatus.open serialises to "open"', () {
      expect(ScaleStatus.open.name, 'open');
    });

    test('ScaleStatus.monitoring serialises to "monitoring"', () {
      expect(ScaleStatus.monitoring.name, 'monitoring');
    });

    test('ScaleStatus.closed serialises to "closed"', () {
      expect(ScaleStatus.closed.name, 'closed');
    });

    test('fromJson maps "open" to ScaleStatus.open', () {
      final r = ScaleReport.fromJson({
        'poiId': 'x',
        'poiName': 'X',
        'status': 'open',
        'lat': 0.0,
        'lng': 0.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.status, ScaleStatus.open);
    });

    test('fromJson maps "closed" to ScaleStatus.closed', () {
      final r = ScaleReport.fromJson({
        'poiId': 'x',
        'poiName': 'X',
        'status': 'closed',
        'lat': 0.0,
        'lng': 0.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.status, ScaleStatus.closed);
    });

    test('fromJson maps "monitoring" to ScaleStatus.monitoring', () {
      final r = ScaleReport.fromJson({
        'poiId': 'x',
        'poiName': 'X',
        'status': 'monitoring',
        'lat': 0.0,
        'lng': 0.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.status, ScaleStatus.monitoring);
    });

    test('fromJson falls back to monitoring for unknown status string', () {
      final r = ScaleReport.fromJson({
        'poiId': 'x',
        'poiName': 'X',
        'status': 'unknown_status',
        'lat': 0.0,
        'lng': 0.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.status, ScaleStatus.monitoring);
    });
  });
}

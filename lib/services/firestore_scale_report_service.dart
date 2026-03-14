import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scale_report.dart';

/// Firestore-backed service for sharing weigh-scale status reports across
/// drivers.
///
/// Schema
/// ──────
/// Collection: `scale_reports`
///
/// Convenience doc (latest status, cheap to query):
///   `scale_reports/{scaleId}`
///   Fields:
///     status      – 'open' | 'monitoring' | 'closed'
///     reportedAt  – server timestamp
///     lat, lng    – scale coordinates
///     userId      – (optional) submitting user's UID
///     poiName     – human-readable scale name
///
/// Full-history sub-collection (one doc per submission):
///   `scale_reports/{scaleId}/reports/{autoId}`
///   Same fields as above.
///
/// This design lets callers get the latest status in one read while
/// preserving the full history for analytics.
class FirestoreScaleReportService {
  FirestoreScaleReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  // Lazy accessors so Firebase is only accessed when methods are actually
  // called (avoids failures in unit tests where Firebase is not initialised).
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const _collection = 'scale_reports';

  // ---------------------------------------------------------------------------
  // Watch latest report for a scale
  // ---------------------------------------------------------------------------

  /// Returns a [Stream] that emits the most recent [ScaleReport] for
  /// [scaleId], or `null` when no report has been submitted yet.
  ///
  /// The stream stays open and re-emits whenever another driver submits a new
  /// status for the same scale.
  Stream<ScaleReport?> watchLatest(String scaleId) {
    return _firestore
        .collection(_collection)
        .doc(scaleId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      try {
        return _fromDoc(scaleId, data);
      } catch (_) {
        return null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Submit a new report
  // ---------------------------------------------------------------------------

  /// Saves a driver-reported [status] for [scaleId] to Firestore.
  ///
  /// Two writes occur atomically in a batch:
  ///  1. Updates the convenience doc `scale_reports/{scaleId}` with the
  ///     latest status so other drivers get a cheap single-doc read.
  ///  2. Appends a new document to the `reports` sub-collection for history.
  ///
  /// [pos] is used to record the driver's location at the time of submission.
  /// If no user is signed in, [userId] is omitted.
  Future<void> submit(
    String scaleId,
    String poiName,
    ScaleStatus status,
    double lat,
    double lng,
  ) async {
    final uid = _auth.currentUser?.uid;
    final statusStr = _statusToString(status);
    final now = FieldValue.serverTimestamp();

    final latest = _firestore.collection(_collection).doc(scaleId);
    final historyRef = latest.collection('reports').doc();

    final payload = <String, dynamic>{
      'status': statusStr,
      'reportedAt': now,
      'lat': lat,
      'lng': lng,
      'poiName': poiName,
      if (uid != null) 'userId': uid,
    };

    final batch = _firestore.batch();
    batch.set(latest, payload);
    batch.set(historyRef, payload);
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ScaleReport _fromDoc(String scaleId, Map<String, dynamic> data) {
    final statusStr = data['status'] as String? ?? 'monitoring';
    final ts = data['reportedAt'];
    DateTime reportedAt;
    if (ts is Timestamp) {
      reportedAt = ts.toDate();
    } else {
      reportedAt = DateTime.now();
    }

    return ScaleReport(
      poiId: scaleId,
      poiName: (data['poiName'] as String?) ?? scaleId,
      status: _statusFromString(statusStr),
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      reportedAt: reportedAt,
    );
  }

  static String _statusToString(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return 'open';
      case ScaleStatus.monitoring:
        return 'monitoring';
      case ScaleStatus.closed:
        return 'closed';
    }
  }

  static ScaleStatus _statusFromString(String s) {
    switch (s) {
      case 'open':
        return ScaleStatus.open;
      case 'closed':
        return ScaleStatus.closed;
      default:
        return ScaleStatus.monitoring;
    }
  }
}

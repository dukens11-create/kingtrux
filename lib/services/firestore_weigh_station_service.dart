import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weigh_station.dart';

// =============================================================================
// FirestoreWeighStationService
// =============================================================================
//
// Reads crowdsourced weigh-station status reports from Firestore and writes
// new reports submitted by drivers.
//
// FIRESTORE SCHEMA
// ----------------
// Collection: weigh_station_reports
//   Document ID: auto-generated
//   Fields:
//     stationId  : String   – matches WeighStation.id
//     status     : String   – WeighStationStatus.firestoreValue
//     timestamp  : Timestamp – server timestamp (FieldValue.serverTimestamp)
//     userId     : String?  – Firebase UID or anonymous ID (may be null)
//
// SECURITY
// --------
// Recommended Firestore rules (see docs/FIREBASE_SETUP.md):
//   - Anyone authenticated (including anonymous) can write a new report.
//   - Anyone can read reports (public crowdsource data).
//   - Documents are immutable once written (only append; no edits).
//

/// Firestore-backed service for crowdsourced weigh-station status reports.
///
/// Call [getLatestStatusPerStation] to retrieve a snapshot of the most-recent
/// report for each station ID, and [submitReport] to write a new driver report.
///
/// All Firestore calls are wrapped in try-catch so that the app continues to
/// function gracefully when Firebase is unavailable or not yet configured.
class FirestoreWeighStationService {
  FirestoreWeighStationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _collection = 'weigh_station_reports';

  /// Freshness window: only consider reports newer than this duration.
  static const Duration freshnessWindow =
      Duration(minutes: kWeighStationFreshnessMinutes);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns a map of `stationId → WeighStationStatusOverride` built from the
  /// most-recent Firestore report per station.
  ///
  /// Only reports within [freshnessWindow] are considered.  Stations with no
  /// recent report are omitted from the returned map (caller keeps
  /// [WeighStationStatus.unknown]).
  ///
  /// Returns an empty map on any error so the app remains functional without
  /// Firebase.
  Future<Map<String, WeighStationStatusOverride>> getLatestStatusPerStation() async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(freshnessWindow),
      );
      final snap = await _firestore
          .collection(_collection)
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .get();

      final result = <String, WeighStationStatusOverride>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final stationId = data['stationId'] as String?;
        if (stationId == null || result.containsKey(stationId)) continue;

        final status =
            weighStationStatusFromFirestore(data['status'] as String?);
        final ts = data['timestamp'] as Timestamp?;
        result[stationId] = WeighStationStatusOverride(
          status: status,
          updatedAt: ts?.toDate(),
        );
      }
      return result;
    } catch (e) {
      debugPrint('FirestoreWeighStationService.getLatestStatusPerStation: $e');
      return {};
    }
  }

  /// Returns a real-time [Stream] of the most-recent status override for
  /// [stationId].  The stream emits `null` when no fresh report exists.
  ///
  /// Use this in the station detail UI for live updates.
  Stream<WeighStationStatusOverride?> watchStation(String stationId) {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(freshnessWindow),
      );
      return _firestore
          .collection(_collection)
          .where('stationId', isEqualTo: stationId)
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        final data = snap.docs.first.data();
        final status =
            weighStationStatusFromFirestore(data['status'] as String?);
        final ts = data['timestamp'] as Timestamp?;
        return WeighStationStatusOverride(
          status: status,
          updatedAt: ts?.toDate(),
        );
      });
    } catch (e) {
      debugPrint('FirestoreWeighStationService.watchStation: $e');
      return Stream.value(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Submit a crowdsourced status report for [stationId].
  ///
  /// Uses a server timestamp so reports are consistently ordered regardless
  /// of device clock skew.  Includes the driver's Firebase UID (or anonymous
  /// session ID) for basic deduplication; no PII is required or stored.
  ///
  /// Returns `true` on success, `false` on any error.
  Future<bool> submitReport({
    required String stationId,
    required WeighStationStatus status,
  }) async {
    try {
      final uid = await _getOrCreateAnonymousUid();
      await _firestore.collection(_collection).add({
        'stationId': stationId,
        'status': status.firestoreValue,
        'timestamp': FieldValue.serverTimestamp(),
        if (uid != null) 'userId': uid,
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreWeighStationService.submitReport: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the current user's UID, signing in anonymously if needed.
  ///
  /// Returns `null` when anonymous sign-in is unavailable (e.g. Auth not
  /// configured) – the report is still written without a userId field.
  Future<String?> _getOrCreateAnonymousUid() async {
    try {
      final user = _auth.currentUser;
      if (user != null) return user.uid;
      final cred = await _auth.signInAnonymously();
      return cred.user?.uid;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Public value type
// ---------------------------------------------------------------------------

/// Lightweight overlay carrying just the status + timestamp from Firestore.
class WeighStationStatusOverride {
  const WeighStationStatusOverride({required this.status, this.updatedAt});

  final WeighStationStatus status;
  final DateTime? updatedAt;
}

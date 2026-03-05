import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Manages user profile documents in the Firestore `user` collection.
///
/// Each document uses the Firebase Auth UID as its document ID and is created
/// automatically after a successful sign-up (see [createUserDocument]).
///
/// ## Document schema
///
/// | Field          | Type      | Notes                                      |
/// |----------------|-----------|--------------------------------------------|
/// | `email`        | String    | From Firebase Auth                         |
/// | `name`         | String    | From signup form; empty when not provided  |
/// | `createdAt`    | Timestamp | Server-generated creation time             |
/// | `photoUrl`     | String    | Profile photo URL; defaults to `'Avatar'`  |
/// | `role`         | String    | Access role; defaults to `'user'`          |
/// | `phoneNumber`  | String    | From signup form; empty when not provided  |
/// | `lastLoginAt`  | Timestamp | Server-generated; set at creation time     |
/// | `isActive`     | bool      | Always `true` at creation                  |
class UserService {
  FirebaseFirestore? _storeInstance;

  UserService({FirebaseFirestore? firestore}) : _storeInstance = firestore;

  FirebaseFirestore get _store =>
      _storeInstance ??= FirebaseFirestore.instance;

  /// Creates a Firestore document in the `user` collection for [user].
  ///
  /// Before writing, the method checks whether a document for [user.uid]
  /// already exists. If it does, the call is a no-op (idempotent). Use
  /// [updateLastLogin] to refresh `lastLoginAt` on subsequent sign-ins.
  ///
  /// All parameters are optional; sensible defaults are applied when omitted:
  /// - [name] defaults to `''`
  /// - [photoUrl] defaults to `'Avatar'`
  /// - [role] defaults to `'user'`
  /// - [phoneNumber] defaults to `''`
  ///
  /// Errors are caught and logged rather than propagated so that a Firestore
  /// write failure never blocks the sign-up flow from completing.
  Future<void> createUserDocument(
    User user, {
    String name = '',
    String photoUrl = 'Avatar',
    String role = 'user',
    String phoneNumber = '',
  }) async {
    try {
      final doc = _store.collection('user').doc(user.uid);
      final snapshot = await doc.get();
      if (snapshot.exists) return; // document already created; skip

      await doc.set({
        'email': user.email ?? '',
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'photoUrl': photoUrl,
        'role': role,
        'phoneNumber': phoneNumber,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e, stack) {
      debugPrint('[UserService] Failed to create user document: $e');
      debugPrintStack(stackTrace: stack, label: '[UserService]');
    }
  }

  /// Updates the `lastLoginAt` field for an existing user document.
  ///
  /// Call this after a successful sign-in (not sign-up) to keep the field
  /// current. Errors are caught and logged rather than propagated.
  Future<void> updateLastLogin(User user) async {
    try {
      await _store.collection('user').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      debugPrint('[UserService] Failed to update lastLoginAt: $e');
      debugPrintStack(stackTrace: stack, label: '[UserService]');
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/user_service.dart';

// ---------------------------------------------------------------------------
// Manual lightweight mocks (no code generation required).
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;

  _FakeUser({required this.uid, this.email});
}

class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final bool _exists;
  _FakeDocumentSnapshot({required bool exists}) : _exists = exists;

  @override
  bool get exists => _exists;
}

class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  bool getCalled = false;
  bool setCalled = false;
  Map<String, dynamic>? lastSetData;
  final bool _docExists;

  _FakeDocumentReference({bool docExists = false}) : _docExists = docExists;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get() async {
    getCalled = true;
    return _FakeDocumentSnapshot(exists: _docExists);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    setCalled = true;
    lastSetData = data;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {}
}

class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final _FakeDocumentReference _docRef;
  _FakeCollectionReference(this._docRef);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _docRef;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final _FakeDocumentReference docRef;
  _FakeFirestore({required bool docExists})
      : docRef = _FakeDocumentReference(docExists: docExists);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(docRef);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UserService', () {
    test('can be constructed', () {
      expect(() => UserService(), returnsNormally);
    });

    test('createUserDocument writes document for new user', () async {
      final fakeStore = _FakeFirestore(docExists: false);
      final service = UserService(firestore: fakeStore);
      final user = _FakeUser(uid: 'uid123', email: 'test@example.com');

      await service.createUserDocument(user,
          name: 'John', phoneNumber: '+10000000000');

      expect(fakeStore.docRef.getCalled, isTrue);
      expect(fakeStore.docRef.setCalled, isTrue);

      final data = fakeStore.docRef.lastSetData!;
      expect(data['email'], 'test@example.com');
      expect(data['name'], 'John');
      expect(data['photoUrl'], 'Avatar');
      expect(data['role'], 'user');
      expect(data['phoneNumber'], '+10000000000');
      expect(data['isActive'], isTrue);
      expect(data['createdAt'], isNotNull);
      expect(data['lastLoginAt'], isNotNull);
    });

    test('createUserDocument skips write when document already exists',
        () async {
      final fakeStore = _FakeFirestore(docExists: true);
      final service = UserService(firestore: fakeStore);
      final user = _FakeUser(uid: 'existing', email: 'old@example.com');

      await service.createUserDocument(user);

      expect(fakeStore.docRef.getCalled, isTrue);
      expect(fakeStore.docRef.setCalled, isFalse);
    });

    test('createUserDocument uses custom role and photoUrl', () async {
      final fakeStore = _FakeFirestore(docExists: false);
      final service = UserService(firestore: fakeStore);
      final user = _FakeUser(uid: 'admin1', email: 'admin@example.com');

      await service.createUserDocument(user,
          role: 'admin', photoUrl: 'https://example.com/photo.jpg');

      final data = fakeStore.docRef.lastSetData!;
      expect(data['role'], 'admin');
      expect(data['photoUrl'], 'https://example.com/photo.jpg');
    });

    test('createUserDocument defaults photoUrl to Avatar and role to user',
        () async {
      final fakeStore = _FakeFirestore(docExists: false);
      final service = UserService(firestore: fakeStore);
      final user = _FakeUser(uid: 'uid456', email: 'user@example.com');

      await service.createUserDocument(user);

      final data = fakeStore.docRef.lastSetData!;
      expect(data['photoUrl'], 'Avatar');
      expect(data['role'], 'user');
      expect(data['name'], '');
      expect(data['phoneNumber'], '');
    });
  });
}

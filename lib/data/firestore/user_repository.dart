import 'package:cloud_firestore/cloud_firestore.dart';

/// Top-level `users/{uid}` document — currently just the Drive app-folder
/// reference. See docs/ARCHITECTURE.md#data-architecture.
class UserRepository {
  UserRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid);

  Future<void> setDriveFolderId(String folderId) {
    return _doc.set({'driveFolderId': folderId}, SetOptions(merge: true));
  }
}

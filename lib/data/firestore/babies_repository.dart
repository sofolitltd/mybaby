import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/baby.dart';

/// CRUD for the flat top-level `babies` collection, scoped by a `uid` field
/// on each document — see docs/ARCHITECTURE.md#firestore-schema and
/// firestore.rules for the matching per-user isolation rule.
class BabiesRepository {
  BabiesRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _babies =>
      _firestore.collection('babies');

  Query<Map<String, dynamic>> get _scoped =>
      _babies.where('uid', isEqualTo: _uid);

  Stream<List<Baby>> watchBabies() {
    return _scoped
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Baby.fromFirestore).toList());
  }

  Future<Baby> createBaby({
    required String name,
    required DateTime dob,
    String? sex,
  }) async {
    final draft = Baby(id: '', name: name, dob: dob, sex: sex);
    final ref = await _babies.add({...draft.toFirestore(), 'uid': _uid});
    return Baby(id: ref.id, name: name, dob: dob, sex: sex);
  }

  Future<void> setAvatarDriveFileId(String babyId, String fileId) {
    return _babies.doc(babyId).update({'avatarDriveFileId': fileId});
  }

  Future<void> updateBaby({
    required String id,
    required String name,
    required DateTime dob,
    String? sex,
  }) {
    return _babies.doc(id).update({
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'sex': sex,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic CRUD over a flat top-level `{collectionName}` collection, scoped
/// by `uid` + `babyId` fields on each document — see
/// docs/ARCHITECTURE.md#firestore-schema. Each entity gets a thin subclass
/// supplying [fromDoc]/[toMap].
abstract class FlatBabyEntityRepository<T> {
  FlatBabyEntityRepository(
    FirebaseFirestore firestore,
    this.uid,
    this.babyId,
    String collectionName,
  ) : collection = firestore.collection(collectionName);

  final String uid;
  final String babyId;
  final CollectionReference<Map<String, dynamic>> collection;

  T fromDoc(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toMap(T value);

  /// Every read must filter by both `uid` and `babyId` — never a bare
  /// collection query. Requires the composite indexes declared in
  /// firestore.indexes.json.
  Query<Map<String, dynamic>> get scoped =>
      collection.where('uid', isEqualTo: uid).where('babyId', isEqualTo: babyId);

  Stream<List<T>> watchAll({String orderBy = 'date', bool descending = false}) {
    return scoped
        .orderBy(orderBy, descending: descending)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromDoc).toList());
  }

  Future<String> add(T value) async {
    final ref = await collection.add({
      ...toMap(value),
      'uid': uid,
      'babyId': babyId,
    });
    return ref.id;
  }

  Future<void> updateFields(String id, Map<String, dynamic> fields) {
    return collection.doc(id).update(fields);
  }

  Future<void> delete(String id) => collection.doc(id).delete();
}

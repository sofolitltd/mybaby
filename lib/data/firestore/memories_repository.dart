import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/memory.dart';
import 'flat_baby_entity_repository.dart';

class MemoriesRepository extends FlatBabyEntityRepository<Memory> {
  MemoriesRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'memories');

  @override
  Memory fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Memory.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(Memory value) => value.toFirestore();

  Stream<List<Memory>> watchMemories() =>
      watchAll(orderBy: 'date', descending: true);
}

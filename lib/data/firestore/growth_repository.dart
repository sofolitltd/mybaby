import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/growth_entry.dart';
import 'flat_baby_entity_repository.dart';

class GrowthRepository extends FlatBabyEntityRepository<GrowthEntry> {
  GrowthRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'growthEntries');

  @override
  GrowthEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      GrowthEntry.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(GrowthEntry value) => value.toFirestore();

  Stream<List<GrowthEntry>> watchEntries() => watchAll(orderBy: 'date');
}

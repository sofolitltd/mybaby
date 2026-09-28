import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/medication.dart';
import 'flat_baby_entity_repository.dart';

class MedicationsRepository extends FlatBabyEntityRepository<Medication> {
  MedicationsRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'medications');

  @override
  Medication fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Medication.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(Medication value) => value.toFirestore();

  Stream<List<Medication>> watchMedications() =>
      watchAll(orderBy: 'startDate', descending: true);
}

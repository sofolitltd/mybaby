import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor_visit.dart';
import 'flat_baby_entity_repository.dart';

class DoctorVisitsRepository extends FlatBabyEntityRepository<DoctorVisit> {
  DoctorVisitsRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'doctorVisits');

  @override
  DoctorVisit fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      DoctorVisit.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(DoctorVisit value) => value.toFirestore();

  Stream<List<DoctorVisit>> watchVisits() =>
      watchAll(orderBy: 'date', descending: true);
}

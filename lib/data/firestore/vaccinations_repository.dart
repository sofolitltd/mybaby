import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vaccination.dart';
import 'flat_baby_entity_repository.dart';

class VaccinationsRepository extends FlatBabyEntityRepository<Vaccination> {
  VaccinationsRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'vaccinations');

  @override
  Vaccination fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Vaccination.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(Vaccination value) => value.toFirestore();

  Stream<List<Vaccination>> watchVaccinations() =>
      watchAll(orderBy: 'scheduledDate');

  Future<void> markAdministered(String id) {
    return updateFields(id, {'administeredDate': Timestamp.now()});
  }

  /// Attaches a photo of the physical vaccine card/certificate — optional,
  /// per docs/PRD.md.
  Future<void> setCard(String id, String driveFileId, String mimeType) {
    return updateFields(id, {
      'cardDriveFileId': driveFileId,
      'cardMimeType': mimeType,
    });
  }

  /// Seeds the standard schedule for a newly created baby — see
  /// docs/PRD.md#open-decision-points for the region-customization caveat.
  Future<void> seedStandardSchedule(DateTime dob) async {
    final existing = await scoped.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = collection.firestore.batch();
    for (final item in standardVaccinationSchedule) {
      final scheduledDate = dob.add(Duration(days: item.weeksFromBirth * 7));
      final vaccination = Vaccination(
        id: '',
        name: item.name,
        dose: item.dose,
        scheduledDate: scheduledDate,
      );
      batch.set(collection.doc(), {
        ...vaccination.toFirestore(),
        'uid': uid,
        'babyId': babyId,
      });
    }
    await batch.commit();
  }
}

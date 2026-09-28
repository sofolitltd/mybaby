import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/care_log_entry.dart';
import 'flat_baby_entity_repository.dart';

class CareLogRepository extends FlatBabyEntityRepository<CareLogEntry> {
  CareLogRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'careLogs');

  @override
  CareLogEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CareLogEntry.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(CareLogEntry value) => value.toFirestore();

  Stream<List<CareLogEntry>> watchRecent() =>
      watchAll(orderBy: 'startTime', descending: true);

  Future<void> stop(String id, DateTime endTime) =>
      updateFields(id, {'endTime': Timestamp.fromDate(endTime)});

  Future<void> resume(String id) => updateFields(id, {'endTime': null});

  Future<void> updateDetails(
    String id, {
    required DateTime startTime,
    DateTime? endTime,
    String? subtype,
    String? note,
  }) {
    return updateFields(id, {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime == null ? null : Timestamp.fromDate(endTime),
      'subtype': subtype,
      'note': note,
    });
  }
}

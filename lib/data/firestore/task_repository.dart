import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import 'flat_baby_entity_repository.dart';

class TaskRepository extends FlatBabyEntityRepository<Task> {
  TaskRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'tasks');

  @override
  Task fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Task.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(Task value) => value.toFirestore();

  Stream<List<Task>> watchTasks() =>
      watchAll(orderBy: 'createdAt', descending: true);

  Future<void> toggleComplete(String id, bool completed) => updateFields(id, {
    'completedAt': completed ? Timestamp.fromDate(DateTime.now()) : null,
  });

  Future<void> updateDetails(
    String id, {
    required String title,
    String? note,
    DateTime? dueDate,
    bool notify = true,
  }) {
    return updateFields(id, {
      'title': title,
      'note': note,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'notify': notify,
    });
  }
}

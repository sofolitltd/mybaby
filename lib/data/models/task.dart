import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String? note;
  final DateTime? dueDate;
  final bool notify;
  final DateTime? completedAt;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.note,
    this.dueDate,
    this.notify = true,
    this.completedAt,
    required this.createdAt,
  });

  bool get completed => completedAt != null;

  static Task fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Task(
      id: doc.id,
      title: data['title'] as String,
      note: data['note'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      notify: data['notify'] as bool? ?? true,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'note': note,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'notify': notify,
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

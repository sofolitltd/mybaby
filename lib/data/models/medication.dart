import 'package:cloud_firestore/cloud_firestore.dart';

/// A prescribed medication course — e.g. "5 days of fever medicine". The
/// course is "running" while today falls in [startDate, endDate) and moves
/// to history once it's past its [durationDays]; there's no separate
/// active/inactive flag to keep in sync.
class Medication {
  final String id;
  final String name;
  final String dosage;
  final DateTime startDate;
  final int durationDays;
  final List<String> reminderTimes;
  final String? notes;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.startDate,
    required this.durationDays,
    this.reminderTimes = const [],
    this.notes,
  });

  /// First day the course no longer applies — the active window is
  /// `[startDate, endDate)`.
  DateTime get endDate {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return start.add(Duration(days: durationDays));
  }

  bool get isActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return !today.isBefore(start) && today.isBefore(endDate);
  }

  static Medication fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Medication(
      id: doc.id,
      name: data['name'] as String,
      dosage: data['dosage'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      durationDays: data['durationDays'] as int,
      reminderTimes:
          (data['reminderTimes'] as List<dynamic>?)?.cast<String>() ??
          const [],
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'dosage': dosage,
    'startDate': Timestamp.fromDate(startDate),
    'durationDays': durationDays,
    'reminderTimes': reminderTimes,
    'notes': notes,
  };
}

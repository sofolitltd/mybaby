import 'package:cloud_firestore/cloud_firestore.dart';

class GrowthEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final double heightCm;
  final double? headCircumferenceCm;
  final String? note;

  const GrowthEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.heightCm,
    this.headCircumferenceCm,
    this.note,
  });

  static GrowthEntry fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GrowthEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      weightKg: (data['weightKg'] as num).toDouble(),
      heightCm: (data['heightCm'] as num).toDouble(),
      headCircumferenceCm: (data['headCircumferenceCm'] as num?)?.toDouble(),
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'weightKg': weightKg,
    'heightCm': heightCm,
    'headCircumferenceCm': headCircumferenceCm,
    'note': note,
  };
}

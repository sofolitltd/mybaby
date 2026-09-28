import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorVisit {
  final String id;
  final DateTime date;
  final String doctorName;
  final String reason;
  final String? notes;
  final List<String> prescriptionDriveFileIds;

  const DoctorVisit({
    required this.id,
    required this.date,
    required this.doctorName,
    required this.reason,
    this.notes,
    this.prescriptionDriveFileIds = const [],
  });

  static DoctorVisit fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DoctorVisit(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      doctorName: data['doctorName'] as String,
      reason: data['reason'] as String,
      notes: data['notes'] as String?,
      prescriptionDriveFileIds:
          (data['prescriptionDriveFileIds'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'doctorName': doctorName,
    'reason': reason,
    'notes': notes,
    'prescriptionDriveFileIds': prescriptionDriveFileIds,
  };
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum VaccinationStatus { done, dueSoon, overdue }

/// A minimal standard schedule seeded for every new baby — offsets are weeks
/// from date of birth. Region customization is an open decision in
/// docs/PRD.md#open-decision-points; this is a reasonable v1 default.
const standardVaccinationSchedule = [
  (name: 'Hepatitis B', dose: 1, weeksFromBirth: 0),
  (name: 'DTaP', dose: 1, weeksFromBirth: 8),
  (name: 'Rotavirus', dose: 1, weeksFromBirth: 8),
  (name: 'Hepatitis B', dose: 2, weeksFromBirth: 8),
  (name: 'DTaP', dose: 2, weeksFromBirth: 16),
  (name: 'Rotavirus', dose: 2, weeksFromBirth: 16),
];

class Vaccination {
  final String id;
  final String name;
  final int dose;
  final DateTime scheduledDate;
  final DateTime? administeredDate;
  final String? cardDriveFileId;
  final String? cardMimeType;

  const Vaccination({
    required this.id,
    required this.name,
    required this.dose,
    required this.scheduledDate,
    this.administeredDate,
    this.cardDriveFileId,
    this.cardMimeType,
  });

  VaccinationStatus get status {
    if (administeredDate != null) return VaccinationStatus.done;
    if (scheduledDate.isBefore(DateTime.now())) {
      return VaccinationStatus.overdue;
    }
    return VaccinationStatus.dueSoon;
  }

  static Vaccination fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Vaccination(
      id: doc.id,
      name: data['name'] as String,
      dose: data['dose'] as int,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      administeredDate: (data['administeredDate'] as Timestamp?)?.toDate(),
      cardDriveFileId: data['cardDriveFileId'] as String?,
      cardMimeType: data['cardMimeType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'dose': dose,
    'scheduledDate': Timestamp.fromDate(scheduledDate),
    'administeredDate': administeredDate == null
        ? null
        : Timestamp.fromDate(administeredDate!),
    'cardDriveFileId': cardDriveFileId,
    'cardMimeType': cardMimeType,
  };
}

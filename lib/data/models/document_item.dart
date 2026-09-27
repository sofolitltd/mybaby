import 'package:cloud_firestore/cloud_firestore.dart';

const documentCategories = [
  'Vaccine Card',
  'Growth Report',
  'Prescription',
  'Other',
];

class DocumentItem {
  final String id;
  final DateTime date;
  final String title;
  final String category;
  final String driveFileId;
  final String mimeType;

  const DocumentItem({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    required this.driveFileId,
    required this.mimeType,
  });

  static DocumentItem fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DocumentItem(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] as String,
      category: data['category'] as String,
      driveFileId: data['driveFileId'] as String,
      mimeType: data['mimeType'] as String,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'title': title,
    'category': category,
    'driveFileId': driveFileId,
    'mimeType': mimeType,
  };
}

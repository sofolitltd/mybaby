import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final DateTime date;
  final String caption;
  final String? driveFileId;
  final String? mimeType;

  const Memory({
    required this.id,
    required this.date,
    required this.caption,
    this.driveFileId,
    this.mimeType,
  });

  static Memory fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Memory(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      caption: data['caption'] as String,
      driveFileId: data['driveFileId'] as String?,
      mimeType: data['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'caption': caption,
    'driveFileId': driveFileId,
    'mimeType': mimeType,
  };
}

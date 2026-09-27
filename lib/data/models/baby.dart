import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `babies/{babyId}` in docs/ARCHITECTURE.md.
class Baby {
  final String id;
  final String name;
  final DateTime dob;
  final String? sex;
  final String? avatarDriveFileId;

  const Baby({
    required this.id,
    required this.name,
    required this.dob,
    this.sex,
    this.avatarDriveFileId,
  });

  int get ageInWeeks => DateTime.now().difference(dob).inDays ~/ 7;

  String get avatarEmoji => switch (sex) {
    'Girl' => '👧',
    'Boy' => '👦',
    _ => '👶',
  };

  factory Baby.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Baby(
      id: doc.id,
      name: data['name'] as String,
      dob: (data['dob'] as Timestamp).toDate(),
      sex: data['sex'] as String?,
      avatarDriveFileId: data['avatarDriveFileId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'dob': Timestamp.fromDate(dob),
    'sex': sex,
    'avatarDriveFileId': avatarDriveFileId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

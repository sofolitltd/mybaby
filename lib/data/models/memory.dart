import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final DateTime date;
  final String title;
  final String caption;
  final List<String> mediaDriveFileIds;
  final List<String> mediaMimeTypes;
  final String? milestoneLabel;
  final String? location;
  final List<String> tags;

  const Memory({
    required this.id,
    required this.date,
    required this.title,
    required this.caption,
    this.mediaDriveFileIds = const [],
    this.mediaMimeTypes = const [],
    this.milestoneLabel,
    this.location,
    this.tags = const [],
  });

  static Memory fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Memory(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      mediaDriveFileIds: List<String>.from(
        data['mediaDriveFileIds'] as List? ?? const [],
      ),
      mediaMimeTypes: List<String>.from(
        data['mediaMimeTypes'] as List? ?? const [],
      ),
      milestoneLabel: data['milestoneLabel'] as String?,
      location: data['location'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'title': title,
    'caption': caption,
    'mediaDriveFileIds': mediaDriveFileIds,
    'mediaMimeTypes': mediaMimeTypes,
    'milestoneLabel': milestoneLabel,
    'location': location,
    'tags': tags,
  };
}

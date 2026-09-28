import 'package:cloud_firestore/cloud_firestore.dart';

enum CareLogType { feed, sleep, diaper, bath }

class CareLogEntry {
  final String id;
  final CareLogType type;
  final DateTime startTime;
  final DateTime? endTime;
  final String? subtype;
  final String? note;

  const CareLogEntry({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    this.subtype,
    this.note,
  });

  Duration? get duration => endTime?.difference(startTime);

  String get summary {
    if (type == CareLogType.diaper) return subtype ?? '';
    final d = duration;
    if (d == null) return subtype ?? '';
    final minutes = d.inMinutes;
    final label = '${minutes}m';
    return subtype == null ? label : '$label, $subtype';
  }

  static CareLogEntry fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return CareLogEntry(
      id: doc.id,
      type: CareLogType.values.byName(data['type'] as String),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      subtype: data['subtype'] as String?,
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'type': type.name,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
    'subtype': subtype,
    'note': note,
  };
}

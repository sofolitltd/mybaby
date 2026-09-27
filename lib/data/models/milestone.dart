import 'package:cloud_firestore/cloud_firestore.dart';

/// The preset checklist from docs/PRD.md — doc id is the slugified label, so
/// toggling "achieved" is a deterministic set/delete rather than a search.
const presetMilestoneLabels = [
  'Smiles',
  'Holds head up',
  'Rolls over',
  'Sits up',
  'First tooth',
  'Crawls',
  'First steps',
  'First words',
];

String milestoneSlug(String label) =>
    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

class Milestone {
  final String label;
  final DateTime? achievedDate;

  const Milestone({required this.label, this.achievedDate});

  bool get achieved => achievedDate != null;

  static Milestone fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Milestone(
      label: data['label'] as String,
      achievedDate: (data['achievedDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'label': label,
    'achievedDate': achievedDate == null
        ? null
        : Timestamp.fromDate(achievedDate!),
  };
}

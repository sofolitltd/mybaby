import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/milestone.dart';
import 'flat_baby_entity_repository.dart';

class MilestonesRepository extends FlatBabyEntityRepository<Milestone> {
  MilestonesRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'milestones');

  @override
  Milestone fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Milestone.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(Milestone value) => value.toFirestore();

  /// Doc id is `{babyId}_{slug}` — in the flat top-level `milestones`
  /// collection, the slug alone would collide across different babies.
  String _docId(String label) => '${babyId}_${milestoneSlug(label)}';

  /// Keyed by label so achieved-state is shown even for milestones that
  /// don't have a document yet.
  Stream<Map<String, Milestone>> watchByLabel() {
    return scoped.snapshots().map((snapshot) {
      final map = <String, Milestone>{};
      for (final doc in snapshot.docs) {
        final milestone = fromDoc(doc);
        map[milestone.label] = milestone;
      }
      return map;
    });
  }

  Future<void> setAchieved(String label, DateTime? achievedDate) {
    return collection.doc(_docId(label)).set({
      ...Milestone(label: label, achievedDate: achievedDate).toFirestore(),
      'uid': uid,
      'babyId': babyId,
    });
  }
}

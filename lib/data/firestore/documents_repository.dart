import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/document_item.dart';
import 'flat_baby_entity_repository.dart';

class DocumentsRepository extends FlatBabyEntityRepository<DocumentItem> {
  DocumentsRepository(FirebaseFirestore firestore, String uid, String babyId)
    : super(firestore, uid, babyId, 'documents');

  @override
  DocumentItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      DocumentItem.fromFirestore(doc);

  @override
  Map<String, dynamic> toMap(DocumentItem value) => value.toFirestore();

  Stream<List<DocumentItem>> watchDocuments() =>
      watchAll(orderBy: 'date', descending: true);
}

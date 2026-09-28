import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drive/drive_image_cache.dart';
import '../data/drive/drive_repository.dart';
import '../data/firestore/babies_repository.dart';
import '../data/firestore/care_log_repository.dart';
import '../data/firestore/doctor_visits_repository.dart';
import '../data/firestore/documents_repository.dart';
import '../data/firestore/growth_repository.dart';
import '../data/firestore/medications_repository.dart';
import '../data/firestore/memories_repository.dart';
import '../data/firestore/milestones_repository.dart';
import '../data/firestore/task_repository.dart';
import '../data/firestore/user_repository.dart';
import '../data/firestore/vaccinations_repository.dart';
import '../data/models/baby.dart';
import '../data/models/care_log_entry.dart';
import '../data/models/doctor_visit.dart';
import '../data/models/document_item.dart';
import '../data/models/growth_entry.dart';
import '../data/models/medication.dart';
import '../data/models/memory.dart';
import '../data/models/milestone.dart';
import '../data/models/task.dart';
import '../data/models/vaccination.dart';
import '../features/auth/auth_repository.dart';
import 'notifications/notification_service.dart';

// Cross-cutting providers. These are the shared building blocks: who's
// signed in, which babies they have, which is active — every feature-level
// provider below is scoped to the current uid + active baby. See
// docs/ARCHITECTURE.md#layering.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final authStateProvider = StreamProvider<fb.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final uidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  return DriveRepository(ref.watch(authRepositoryProvider));
});

/// Cached per fileId so scrolling past an image and back doesn't
/// re-download it — see DriveRepository.downloadBytes.
final driveImageBytesProvider = FutureProvider.family<Uint8List, String>((
  ref,
  fileId,
) async {
  final cache = DriveImageCache.instance;
  final cached = await cache.read(fileId);
  if (cached != null) return cached;

  final bytes = await ref.watch(driveRepositoryProvider).downloadBytes(fileId);
  await cache.write(fileId, bytes);
  return bytes;
});

final babiesRepositoryProvider = Provider<BabiesRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return null;
  return BabiesRepository(FirebaseFirestore.instance, uid);
});

final userRepositoryProvider = Provider<UserRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return null;
  return UserRepository(FirebaseFirestore.instance, uid);
});

final babiesStreamProvider = StreamProvider<List<Baby>>((ref) {
  final repo = ref.watch(babiesRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchBabies();
});

class ActiveBabyIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final activeBabyIdProvider = NotifierProvider<ActiveBabyIdNotifier, String?>(
  ActiveBabyIdNotifier.new,
);

/// The baby currently shown across Home/Growth/Memories/etc. Falls back to
/// the first baby if none explicitly selected yet.
final activeBabyProvider = Provider<Baby?>((ref) {
  final babies = ref.watch(babiesStreamProvider).value ?? const [];
  if (babies.isEmpty) return null;
  final selectedId = ref.watch(activeBabyIdProvider);
  return babies.firstWhere(
    (b) => b.id == selectedId,
    orElse: () => babies.first,
  );
});

// --- Per-baby subcollection repositories & streams -------------------------
// Each pair follows the same shape: a nullable repository (null until both a
// uid and an active baby exist) and a stream provider that falls back to an
// empty list rather than erroring while that's the case.

final growthRepositoryProvider = Provider<GrowthRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return GrowthRepository(FirebaseFirestore.instance, uid, baby.id);
});

final growthEntriesProvider = StreamProvider<List<GrowthEntry>>((ref) {
  final repo = ref.watch(growthRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchEntries();
});

final milestonesRepositoryProvider = Provider<MilestonesRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return MilestonesRepository(FirebaseFirestore.instance, uid, baby.id);
});

final milestonesByLabelProvider = StreamProvider<Map<String, Milestone>>((ref) {
  final repo = ref.watch(milestonesRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchByLabel();
});

final memoriesRepositoryProvider = Provider<MemoriesRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return MemoriesRepository(FirebaseFirestore.instance, uid, baby.id);
});

final memoriesProvider = StreamProvider<List<Memory>>((ref) {
  final repo = ref.watch(memoriesRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchMemories();
});

final vaccinationsRepositoryProvider = Provider<VaccinationsRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return VaccinationsRepository(FirebaseFirestore.instance, uid, baby.id);
});

final vaccinationsProvider = StreamProvider<List<Vaccination>>((ref) {
  final repo = ref.watch(vaccinationsRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchVaccinations();
});

final doctorVisitsRepositoryProvider = Provider<DoctorVisitsRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return DoctorVisitsRepository(FirebaseFirestore.instance, uid, baby.id);
});

final doctorVisitsProvider = StreamProvider<List<DoctorVisit>>((ref) {
  final repo = ref.watch(doctorVisitsRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchVisits();
});

final medicationsRepositoryProvider = Provider<MedicationsRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return MedicationsRepository(FirebaseFirestore.instance, uid, baby.id);
});

final medicationsProvider = StreamProvider<List<Medication>>((ref) {
  final repo = ref.watch(medicationsRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchMedications();
});

final documentsRepositoryProvider = Provider<DocumentsRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return DocumentsRepository(FirebaseFirestore.instance, uid, baby.id);
});

final documentsProvider = StreamProvider<List<DocumentItem>>((ref) {
  final repo = ref.watch(documentsRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchDocuments();
});

final careLogRepositoryProvider = Provider<CareLogRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return CareLogRepository(FirebaseFirestore.instance, uid, baby.id);
});

final careLogProvider = StreamProvider<List<CareLogEntry>>((ref) {
  final repo = ref.watch(careLogRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchRecent();
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final uid = ref.watch(uidProvider);
  final baby = ref.watch(activeBabyProvider);
  if (uid == null || baby == null) return null;
  return TaskRepository(FirebaseFirestore.instance, uid, baby.id);
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchTasks();
});

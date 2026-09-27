import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mime_utils.dart';
import '../../core/picked_file.dart';
import '../../core/providers.dart';
import '../../data/firestore/babies_repository.dart';
import '../../data/firestore/growth_repository.dart';
import '../../data/models/growth_entry.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'widgets/add_baby_form.dart';
import 'widgets/baby_screen_header.dart';

class AddBabyScreen extends ConsumerStatefulWidget {
  const AddBabyScreen({super.key});

  @override
  ConsumerState<AddBabyScreen> createState() => _AddBabyScreenState();
}

class _AddBabyScreenState extends ConsumerState<AddBabyScreen> {
  bool _saving = false;

  Future<void> _save(AddBabyFormResult result) async {
    final repo = ref.read(babiesRepositoryProvider);
    final uid = ref.read(uidProvider);
    if (repo == null || uid == null) return;
    setState(() => _saving = true);
    try {
      final baby = await repo.createBaby(
        name: result.name,
        dob: result.dob,
        sex: result.sex,
      );
      ref.read(activeBabyIdProvider.notifier).select(baby.id);

      if (result.birthWeightKg != null ||
          result.birthHeightCm != null ||
          result.birthHeadCircumferenceCm != null) {
        await GrowthRepository(FirebaseFirestore.instance, uid, baby.id).add(
          GrowthEntry(
            id: '',
            date: result.dob,
            weightKg: result.birthWeightKg ?? 0,
            heightCm: result.birthHeightCm ?? 0,
            headCircumferenceCm: result.birthHeadCircumferenceCm,
            note: 'Birth measurement',
          ),
        );
      }

      if (result.driveBackupEnabled && result.photo != null) {
        await _uploadAvatar(repo, baby.id, result.photo!);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar(
    BabiesRepository repo,
    String babyId,
    PickedFile photo,
  ) async {
    try {
      final drive = ref.read(driveRepositoryProvider);
      final folderId = await drive.ensureAppFolder();
      final fileId = await drive.uploadBytes(
        bytes: photo.bytes,
        filename: photo.name,
        mimeType: guessMimeType(photo.name),
        folderId: folderId,
      );
      await repo.setAvatarDriveFileId(babyId, fileId);
    } catch (_) {
      // Non-fatal — the avatar can be added again later.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          const BabyScreenHeader(title: 'Add Baby'),
          Expanded(
            child: AddBabyForm(onSubmit: _save, submitting: _saving),
          ),
        ],
      ),
    );
  }
}

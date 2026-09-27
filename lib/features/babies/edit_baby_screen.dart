import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mime_utils.dart';
import '../../core/providers.dart';
import '../../data/firestore/babies_repository.dart';
import '../../data/models/baby.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'baby_form.dart';
import 'widgets/baby_screen_header.dart';

class EditBabyScreen extends ConsumerStatefulWidget {
  const EditBabyScreen({super.key, required this.baby});

  final Baby baby;

  @override
  ConsumerState<EditBabyScreen> createState() => _EditBabyScreenState();
}

class _EditBabyScreenState extends ConsumerState<EditBabyScreen> {
  bool _saving = false;

  Future<void> _save({
    required String name,
    required DateTime dob,
    String? sex,
    PlatformFile? photo,
  }) async {
    final repo = ref.read(babiesRepositoryProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      await repo.updateBaby(id: widget.baby.id, name: name, dob: dob, sex: sex);
      if (photo?.bytes != null) {
        await _uploadAvatar(repo, widget.baby.id, photo!);
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
    PlatformFile photo,
  ) async {
    try {
      final drive = ref.read(driveRepositoryProvider);
      final folderId = await drive.ensureAppFolder();
      final fileId = await drive.uploadBytes(
        bytes: photo.bytes!,
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
          BabyScreenHeader(title: 'Edit ${widget.baby.name}'),
          Expanded(
            child: BabyForm(
              onSubmit: _save,
              submitting: _saving,
              submitLabel: 'Save changes',
              initialName: widget.baby.name,
              initialDob: widget.baby.dob,
              initialSex: widget.baby.sex,
            ),
          ),
        ],
      ),
    );
  }
}

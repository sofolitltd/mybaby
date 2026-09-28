import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mime_utils.dart';
import '../../core/picked_file.dart';
import '../../core/providers.dart';
import '../../data/firestore/babies_repository.dart';
import '../../data/models/baby.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'widgets/baby_screen_header.dart';
import 'widgets/edit_baby_form.dart';

class EditBabyScreen extends ConsumerStatefulWidget {
  const EditBabyScreen({super.key, required this.baby});

  final Baby baby;

  @override
  ConsumerState<EditBabyScreen> createState() => _EditBabyScreenState();
}

class _EditBabyScreenState extends ConsumerState<EditBabyScreen> {
  bool _saving = false;

  Future<void> _save(EditBabyFormResult result) async {
    final repo = ref.read(babiesRepositoryProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      await repo.updateBaby(
        id: widget.baby.id,
        name: result.name,
        dob: result.dob,
        sex: result.sex,
      );
      if (result.photo != null) {
        await _uploadAvatar(repo, widget.baby.id, result.photo!);
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
          BabyScreenHeader(title: 'Edit ${widget.baby.name}'),
          Expanded(
            child: EditBabyForm(
              onSubmit: _save,
              submitting: _saving,
              initialName: widget.baby.name,
              initialDob: widget.baby.dob,
              initialSex: widget.baby.sex,
              initialAvatarDriveFileId: widget.baby.avatarDriveFileId,
            ),
          ),
        ],
      ),
    );
  }
}

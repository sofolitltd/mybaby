import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Renders an image stored in the app's Drive folder inline — a `drive.file`
/// file has no public URL, so this downloads and decodes the bytes itself
/// rather than linking out to Drive. Tap opens a full-screen zoomable view,
/// the way a chat app shows a photo you sent.
class DriveImage extends ConsumerWidget {
  const DriveImage({super.key, required this.fileId, this.height = 200});

  final String fileId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(driveImageBytesProvider(fileId));

    return bytesAsync.when(
      loading: () => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: height,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppTheme.of(context).colors.status.overdue,
          ),
        ),
      ),
      data: (bytes) => GestureDetector(
        onTap: () => showDriveImageViewer(context, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.s),
          child: Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Opens the same in-app zoomable full-screen viewer [DriveImage] uses on
/// tap — shared so other widgets (e.g. a document card's "View" action) show
/// Drive-backed images without ever leaving the app.
void showDriveImageViewer(BuildContext context, Uint8List bytes) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => _FullScreenImage(bytes: bytes),
    ),
  );
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
    );
  }
}

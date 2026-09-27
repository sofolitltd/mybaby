import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A file selected via [FilePicker], with its bytes already read into
/// memory. `file_picker` 13 dropped [PlatformFile]'s synchronous `bytes`
/// getter in favor of async `readAsBytes()`, so callers that need bytes
/// for a preview ([Image.memory]) or a later upload read them once, right
/// after picking, and carry them in this immutable pair instead.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedFile?> pickSingleFile({FileType type = FileType.any}) async {
  final file = await FilePicker.pickFile(type: type);
  if (file == null) return null;
  return PickedFile(name: file.name, bytes: await file.readAsBytes());
}

Future<List<PickedFile>> pickMultipleFiles({
  FileType type = FileType.any,
}) async {
  final files = await FilePicker.pickFiles(type: type);
  return Future.wait(
    files.map(
      (f) async => PickedFile(name: f.name, bytes: await f.readAsBytes()),
    ),
  );
}

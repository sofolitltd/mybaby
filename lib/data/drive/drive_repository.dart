import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import '../../features/auth/auth_repository.dart';

const _appFolderName = 'MyBaby App';

/// Files/photos/documents live in this Drive folder, in the parent's own
/// Google account — never Firebase Storage. See
/// docs/ARCHITECTURE.md#data-architecture and
/// docs/PRIVACY_SECURITY.md for why (`drive.file` scope only — this app can
/// only ever see files it created itself).
class DriveRepository {
  DriveRepository(this._authRepository);

  final AuthRepository _authRepository;

  drive.DriveApi _api() {
    final client = _authRepository.driveHttpClient();
    if (client == null) {
      throw StateError('Drive access not authorized — sign in again.');
    }
    return drive.DriveApi(client);
  }

  /// Returns the id of the app's Drive folder, creating it on first use.
  Future<String> ensureAppFolder() async {
    final api = _api();
    final existing = await api.files.list(
      q: "name = '$_appFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final files = existing.files;
    if (files != null && files.isNotEmpty) {
      return files.first.id!;
    }

    final folder = drive.File()
      ..name = _appFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  Future<String> uploadBytes({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String folderId,
    void Function(double progress)? onProgress,
  }) async {
    final api = _api();
    final media = drive.Media(
      _chunkedProgressStream(bytes, onProgress),
      bytes.length,
      contentType: mimeType,
    );
    final metadata = drive.File()
      ..name = filename
      ..parents = [folderId];
    final uploaded = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: 'id',
    );
    onProgress?.call(1);
    return uploaded.id!;
  }

  /// Re-chunks [bytes] so upload progress can be reported as the request
  /// body is read — the closest approximation of send progress available
  /// through `package:googleapis`, which does not expose it directly.
  Stream<List<int>> _chunkedProgressStream(
    List<int> bytes,
    void Function(double progress)? onProgress,
  ) async* {
    const chunkSize = 64 * 1024;
    var sent = 0;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      yield bytes.sublist(offset, end);
      sent = end;
      onProgress?.call(sent / bytes.length);
    }
  }

  /// Downloads a file's raw bytes — used to render images inline (a
  /// `drive.file`-scoped file has no public URL, so we fetch and decode it
  /// ourselves rather than linking out to Drive).
  Future<Uint8List> downloadBytes(String fileId) async {
    final api = _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final chunks = await media.stream.toList();
    final bytes = BytesBuilder();
    for (final chunk in chunks) {
      bytes.add(chunk);
    }
    return bytes.toBytes();
  }
}

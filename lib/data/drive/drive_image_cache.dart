import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'dart:convert';
import 'dart:io';

/// Caches downloaded/uploaded Drive image bytes by file id, so a photo shown
/// once (or just uploaded) never needs a second round trip to Drive — see
/// docs/ARCHITECTURE.md#offline-strategy. In-memory for this run everywhere;
/// also persisted to disk on non-web platforms so it survives app restarts.
class DriveImageCache {
  DriveImageCache._();
  static final DriveImageCache instance = DriveImageCache._();

  final Map<String, Uint8List> _memory = {};

  Uint8List? readMemory(String fileId) => _memory[fileId];

  Future<Uint8List?> read(String fileId) async {
    final cached = _memory[fileId];
    if (cached != null) return cached;
    if (kIsWeb) return null;

    try {
      final file = await _diskFile(fileId);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      _memory[fileId] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String fileId, Uint8List bytes) async {
    _memory[fileId] = bytes;
    if (kIsWeb) return;

    try {
      final file = await _diskFile(fileId);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Disk cache is best-effort — memory cache above still serves this run.
    }
  }

  Future<File> _diskFile(String fileId) async {
    final dir = await getApplicationSupportDirectory();
    final name = sha1.convert(utf8.encode(fileId)).toString();
    return File('${dir.path}/drive_image_cache/$name');
  }
}

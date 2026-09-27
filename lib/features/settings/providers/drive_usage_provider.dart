import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Total bytes MyBaby has uploaded into its own Drive app-folder — see
/// `DriveRepository.appFolderUsageBytes` for why this (not account-wide
/// quota) is what `drive.file` scope actually allows reading. Re-fetched
/// whenever a sync completes via `ref.invalidate(driveUsageProvider)`.
final driveUsageProvider = FutureProvider<int>((ref) {
  return ref.watch(driveRepositoryProvider).appFolderUsageBytes();
});

/// Formats a byte count the way this screen displays it — "124 MB", "3.2 GB"
/// — no fixed unit ladder assumption beyond what actually fits.
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

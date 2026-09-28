import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/drive/drive_repository.dart';

/// Shows an error SnackBar for a failed Drive operation. Silent token
/// refresh (see AuthRepository.driveHttpClient) has already been tried and
/// failed by the time a [DriveAuthException] reaches here, so this offers a
/// one-tap interactive reconnect instead of a raw error message.
void showDriveErrorSnackBar(
  BuildContext context,
  WidgetRef ref,
  Object error,
) {
  final messenger = ScaffoldMessenger.of(context);
  if (error is! DriveAuthException) {
    messenger.showSnackBar(SnackBar(content: Text('Drive error: $error')));
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: const Text('Google Drive access expired.'),
      action: SnackBarAction(
        label: 'Reconnect',
        onPressed: () async {
          try {
            await ref.read(authRepositoryProvider).reauthorizeDrive();
            messenger.showSnackBar(
              const SnackBar(content: Text('Reconnected — try again.')),
            );
          } catch (_) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Reconnect failed — try signing out and back in.'),
              ),
            );
          }
        },
      ),
    ),
  );
}

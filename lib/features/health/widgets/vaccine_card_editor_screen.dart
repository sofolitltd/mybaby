import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart'
    show CircularProgressIndicator, ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_scaffold.dart';

const _kMaskColor = Color(0x99000000);
const _kBaseColor = Color(0xFF000000);
const _kOnMask = Color(0xFFFFFFFF);

/// Full-screen crop + compress step for a vaccine card photo, before it goes
/// into the pending-upload flow. Pops with the final JPEG bytes, or `null`
/// if the user backs out.
class VaccineCardEditorScreen extends StatefulWidget {
  const VaccineCardEditorScreen({super.key, required this.sourceBytes});

  final Uint8List sourceBytes;

  @override
  State<VaccineCardEditorScreen> createState() =>
      _VaccineCardEditorScreenState();
}

class _VaccineCardEditorScreenState extends State<VaccineCardEditorScreen> {
  final _cropController = CropController();
  bool _isProcessing = false;

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        setState(() => _isProcessing = true);
        final compressed = await compute(_compressJpeg, croppedImage);
        if (mounted) Navigator.of(context).pop(compressed);
      case CropFailure(:final cause):
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not crop photo: $cause')));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppScaffold(
      appBar: _EditorTopBar(onCancel: () => Navigator.of(context).pop()),
      body: Stack(
        children: [
          Crop(
            controller: _cropController,
            image: widget.sourceBytes,
            onCropped: _onCropped,
            interactive: true,
            fixCropRect: false,
            baseColor: _kBaseColor,
            maskColor: _kMaskColor,
          ),
          if (_isProcessing)
            ColoredBox(
              color: _kMaskColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _kOnMask),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Compressing…',
                      style: theme.typography.body.copyWith(color: _kOnMask),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _isProcessing ? null : () => _cropController.crop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.check, color: theme.colors.onPrimary),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Use this photo',
                    style: theme.typography.label.copyWith(
                      color: theme.colors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditorTopBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Crop vaccine card',
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            TapScale(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s),
                child: Text(
                  'Cancel',
                  style: theme.typography.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Downscales and re-encodes as JPEG so vaccine card photos don't eat the
/// parent's Drive quota — runs off the UI thread via [compute].
Uint8List _compressJpeg(Uint8List bytes) {
  const maxDimension = 1600;
  const quality = 82;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  var image = decoded;
  if (image.width > maxDimension || image.height > maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxDimension)
        : img.copyResize(image, height: maxDimension);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

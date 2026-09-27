import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mime_utils.dart';
import '../../core/providers.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../data/firestore/babies_repository.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../babies/baby_form.dart';

/// The sign-up flow: sign in → Drive permission explainer → first baby
/// profile. See docs/UX.md "Onboarding". Which step shows is driven by real
/// state (app.dart's AuthGate), not local flags: no user → step 0; signed in
/// with no babies yet → step 1; the app only reaches step 2 (main app) once
/// a baby actually exists in Firestore.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.startAtBabyStep});

  final bool startAtBabyStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _controller = PageController(
    initialPage: widget.startAtBabyStep ? 1 : 0,
  );
  bool _signingIn = false;
  bool _creatingBaby = false;

  Future<void> _handleSignIn() async {
    setState(() => _signingIn = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // No manual navigation: once authStateProvider emits a user, app.dart
      // rebuilds this whole screen with startAtBabyStep true.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _goToAddBaby() {
    _controller.animateToPage(
      2,
      duration: AppMotion.durationMedium,
      curve: AppMotion.curveStandard,
    );
  }

  Future<void> _ensureDriveFolder() async {
    try {
      final folderId = await ref
          .read(driveRepositoryProvider)
          .ensureAppFolder();
      await ref.read(userRepositoryProvider)?.setDriveFolderId(folderId);
    } catch (_) {
      // Non-fatal — the Drive folder can be created again later; don't block
      // onboarding on it.
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
      // Non-fatal — the avatar can be added again later; don't block
      // onboarding on it.
    }
  }

  Future<void> _handleBabyCreated({
    required String name,
    required DateTime dob,
    String? sex,
    PlatformFile? photo,
  }) async {
    final repo = ref.read(babiesRepositoryProvider);
    if (repo == null) return;
    setState(() => _creatingBaby = true);
    try {
      final baby = await repo.createBaby(name: name, dob: dob, sex: sex);
      unawaited(_ensureDriveFolder());
      if (photo?.bytes != null) {
        await _uploadAvatar(repo, baby.id, photo!);
      }
      // No manual navigation: once babiesStreamProvider is non-empty,
      // app.dart swaps to the main app automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _creatingBaby = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.m),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _StepDots(
                  current: _controller.hasClients && _controller.page != null
                      ? _controller.page!.round()
                      : (widget.startAtBabyStep ? 1 : 0),
                  count: 3,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _WelcomeStep(
                      signingIn: _signingIn,
                      onSignIn: _handleSignIn,
                    ),
                    _DriveConsentStep(onContinue: _goToAddBaby),
                    BabyForm(
                      onSubmit: _handleBabyCreated,
                      submitting: _creatingBaby,
                      submitLabel: 'Get started',
                      title: 'Add your first baby',
                      subtitle:
                          'Just a name and date of birth to get started — everything else can wait.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.durationMedium,
            curve: AppMotion.curveStandard,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? colors.textPrimary : colors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.signingIn, required this.onSignIn});

  final bool signingIn;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👶', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'MyBaby',
            style: theme.typography.title.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Growth, memories, health records, and daily care — all in one calm place, owned by your family.',
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: signingIn ? null : onSignIn,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  signingIn
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(LucideIcons.log_in, size: 20),
                  const SizedBox(width: AppSpacing.s),
                  Text(signingIn ? 'Signing in…' : 'Continue with Google'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'No separate account to create — sign in with the Google account you already use.',
            textAlign: TextAlign.center,
            style: theme.typography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveConsentStep extends StatelessWidget {
  const _DriveConsentStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.folder_lock,
              size: 34,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Your photos stay in your Drive',
            style: theme.typography.title.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'MyBaby stores your photos and documents in a folder in your own Google Drive — not on our servers. '
            'We only ever access files this app creates, nothing else in your Drive.',
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(onPressed: onContinue, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, Colors, ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mime_utils.dart';
import '../../core/picked_file.dart';
import '../../core/providers.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../data/firestore/babies_repository.dart';
import '../../data/firestore/growth_repository.dart';
import '../../data/models/growth_entry.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../babies/widgets/add_baby_form.dart';
import 'widgets/intro_carousel.dart';

/// The sign-up flow: feature intro → sign in → Drive permission explainer →
/// first baby profile. See docs/UX.md "Onboarding". Which step shows is
/// driven by real state (app.dart's AuthGate), not local flags: no user →
/// intro then sign-in; signed in with no babies yet → skips straight to the
/// baby step; the app only reaches the main app once a baby actually exists
/// in Firestore. The intro carousel itself is local-only UI state — it never
/// needs to persist, since app.dart stops building this screen at all once
/// the user is signed in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.startAtBabyStep});

  final bool startAtBabyStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late bool _showIntro = !widget.startAtBabyStep;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
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
      // Non-fatal — the avatar can be added again later; don't block
      // onboarding on it.
    }
  }

  Future<void> _handleBabyCreated(AddBabyFormResult result) async {
    final repo = ref.read(babiesRepositoryProvider);
    final uid = ref.read(uidProvider);
    if (repo == null || uid == null) return;
    setState(() => _creatingBaby = true);
    try {
      final baby = await repo.createBaby(
        name: result.name,
        dob: result.dob,
        sex: result.sex,
      );
      unawaited(_ensureDriveFolder());

      if (result.birthWeightKg != null ||
          result.birthHeightCm != null ||
          result.birthHeadCircumferenceCm != null) {
        await GrowthRepository(FirebaseFirestore.instance, uid, baby.id).add(
          GrowthEntry(
            id: '',
            date: result.dob,
            weightKg: result.birthWeightKg ?? 0,
            heightCm: result.birthHeightCm ?? 0,
            headCircumferenceCm: result.birthHeadCircumferenceCm,
            note: 'Birth measurement',
          ),
        );
      }

      if (result.driveBackupEnabled && result.photo != null) {
        await _uploadAvatar(repo, baby.id, result.photo!);
      }
      // No manual navigation: once babiesStreamProvider is non-empty,
      // app.dart swaps to the main app automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
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
    if (_showIntro) {
      return AppScaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: OnboardingIntro(
                onDone: () => setState(() => _showIntro = false),
              ),
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.m),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _StepDots(
                    current:
                        _controller.hasClients && _controller.page != null
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
                      AddBabyForm(
                        onSubmit: _handleBabyCreated,
                        submitting: _creatingBaby,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          const _HeroGlow(),
          const SizedBox(height: AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.shield_check,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Why sign in with Google?',
                        style: theme.typography.subtitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
                _FeatureRow(
                  icon: LucideIcons.zap,
                  title: 'Instant Setup',
                  description: 'No new passwords to create, memorize, or reset during late nights.',
                ),
                const SizedBox(height: AppSpacing.l),
                _FeatureRow(
                  icon: LucideIcons.folder_lock,
                  title: 'Private Google Drive Backup',
                  description: "Your baby's photos, charts, and health notes stay in your own Drive — never on our servers.",
                ),
                const SizedBox(height: AppSpacing.l),
                _FeatureRow(
                  icon: LucideIcons.refresh_cw,
                  title: 'Synced Everywhere',
                  description: 'Log from your phone, check in from the web — always up to date.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.primary,
              onPressed: signingIn ? null : onSignIn,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  signingIn
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.surface,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: .circle,
                            color: Colors.white,
                          ),
                          width: 20,
                          height: 20,
                          child: _GoogleLogo(),
                        ),
                  const SizedBox(width: AppSpacing.m),
                  Text(
                    signingIn ? 'Signing in…' : 'Continue with Google',
                    style: theme.typography.subtitle.copyWith(
                      color: colors.surface,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            crossAxisAlignment: .start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.lock, size: 14, color: colors.textTertiary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'No separate password needed — secure one-tap sign-in with your Google account.',
                  textAlign: TextAlign.center,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return SizedBox(
      width: 132,
      height: 132,
      child: Center(
        child: Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.secondary.withValues(alpha: 0.28),
                colors.secondary.withValues(alpha: 0),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.secondary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('👶', style: TextStyle(fontSize: 40)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.typography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Standalone vector rendering of the Google "G" mark (traced from Google's
/// published sign-in button asset paths) — avoids pulling in `flutter_svg`
/// just for one static logo.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFFFC107);
    canvas.drawPath(_yellow, paint);
    paint.color = const Color(0xFFFF3D00);
    canvas.drawPath(_red, paint);
    paint.color = const Color(0xFF4CAF50);
    canvas.drawPath(_green, paint);
    paint.color = const Color(0xFF1976D2);
    canvas.drawPath(_blue, paint);

    canvas.restore();
  }

  Path get _yellow => Path()
    ..moveTo(43.611, 20.083)
    ..lineTo(42, 20.083)
    ..lineTo(42, 20)
    ..lineTo(24, 20)
    ..relativeLineTo(0, 8)
    ..relativeLineTo(11.303, 0)
    ..relativeCubicTo(-1.649, 4.657, -6.08, 8, -11.303, 8)
    ..relativeCubicTo(-6.627, 0, -12, -5.373, -12, -12)
    ..relativeCubicTo(0, -6.627, 5.373, -12, 12, -12)
    ..relativeCubicTo(3.059, 0, 5.842, 1.154, 7.961, 3.039)
    ..relativeLineTo(5.657, -5.657)
    ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
    ..cubicTo(12.955, 4, 4, 12.955, 4, 24)
    ..relativeCubicTo(0, 11.045, 8.955, 20, 20, 20)
    ..relativeCubicTo(11.045, 0, 20, -8.955, 20, -20)
    ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
    ..close();

  Path get _red => Path()
    ..moveTo(6.306, 14.691)
    ..relativeLineTo(6.571, 4.819)
    ..cubicTo(14.655, 15.108, 18.961, 12, 24, 12)
    ..relativeCubicTo(3.059, 0, 5.842, 1.154, 7.961, 3.039)
    ..relativeLineTo(5.657, -5.657)
    ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
    ..cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691)
    ..close();

  Path get _green => Path()
    ..moveTo(24, 44)
    ..relativeCubicTo(5.166, 0, 9.86, -1.977, 13.409, -5.192)
    ..relativeLineTo(-6.19, -5.238)
    ..cubicTo(29.211, 35.091, 26.715, 36, 24, 36)
    ..relativeCubicTo(-5.202, 0, -9.619, -3.317, -11.283, -7.946)
    ..relativeLineTo(-6.522, 5.025)
    ..cubicTo(9.505, 39.556, 16.227, 44, 24, 44)
    ..close();

  Path get _blue => Path()
    ..moveTo(43.611, 20.083)
    ..lineTo(42, 20.083)
    ..lineTo(42, 20)
    ..lineTo(24, 20)
    ..relativeLineTo(0, 8)
    ..relativeLineTo(11.303, 0)
    ..relativeCubicTo(-0.792, 2.237, -2.231, 4.166, -4.087, 5.571)
    ..relativeCubicTo(0.001, -0.001, 0.002, -0.001, 0.003, -0.002)
    ..relativeLineTo(6.19, 5.238)
    ..cubicTo(36.971, 39.205, 44, 34, 44, 24)
    ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
    ..close();

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
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
            child: AppButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

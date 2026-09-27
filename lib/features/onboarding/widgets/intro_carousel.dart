import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/app_motion.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';

/// The marketing-style intro shown before sign-in — three feature slides
/// with a "Skip" escape hatch, purely illustrative (no real data). See
/// docs/UX.md "Onboarding". Only ever built while the user is signed out;
/// once `authStateProvider` emits a user, app.dart stops building
/// [OnboardingScreen] entirely, so this never shows to a logged-in user.
class OnboardingIntro extends StatefulWidget {
  const OnboardingIntro({super.key, required this.onDone});

  /// Called on "Skip", the final slide's CTA, or "Already have an account?
  /// Sign in" — all three land the user on the same sign-in step.
  final VoidCallback onDone;

  @override
  State<OnboardingIntro> createState() => _OnboardingIntroState();
}

class _OnboardingIntroState extends State<OnboardingIntro> {
  final _controller = PageController();
  int _page = 0;

  static final _slides = [
    _Slide(
      eyebrow: null,
      title: 'Cherish every tiny milestone',
      subtitle:
          'Track sleep, feeds, growth curves, and precious moments all in '
          'one calm, private family sanctuary.',
      preview: _TodayStatsPreview(),
    ),
    _Slide(
      eyebrow: 'STEP 2 OF 3 · GROWTH & MILESTONES',
      title: 'Track healthy growth with pediatric precision',
      subtitle:
          'Real-time WHO percentile curves for weight, height, and head '
          'circumference — validated by clinical standards.',
      preview: _GrowthPreview(),
    ),
    _Slide(
      eyebrow: 'STEP 3 OF 3 · FAMILY & SECURITY',
      title: 'Keep family close & every memory safe',
      subtitle:
          'Store photos, audio firsts, and precious milestones in your '
          'private encrypted vault.',
      preview: _MemoryPreview(),
    ),
  ];

  void _next() {
    if (_page == _slides.length - 1) {
      widget.onDone();
      return;
    }
    _controller.animateToPage(
      _page + 1,
      duration: AppMotion.durationMedium,
      curve: AppMotion.curveStandard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final isLast = _page == _slides.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.m,
            AppSpacing.xl,
            0,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('👶', style: theme.typography.label),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'MyBaby',
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (!isLast)
                GestureDetector(
                  onTap: widget.onDone,
                  child: Text(
                    'Skip',
                    style: theme.typography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: _slides,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: AppMotion.durationMedium,
                curve: AppMotion.curveStandard,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? colors.primary : colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            AppSpacing.l,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _next,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLast ? 'Start Your Journey' : 'Continue'),
                      const SizedBox(width: AppSpacing.s),
                      const Icon(LucideIcons.arrow_right, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              GestureDetector(
                onTap: widget.onDone,
                child: Text.rich(
                  TextSpan(
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.preview,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.l),
          preview,
          const SizedBox(height: AppSpacing.xl),
          if (eyebrow != null) ...[
            AppChip(label: eyebrow!, selected: true, onTap: () {}),
            const SizedBox(height: AppSpacing.m),
          ],
          Text(
            title,
            style: theme.typography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            subtitle,
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TodayStatsPreview extends StatelessWidget {
  const _TodayStatsPreview();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return AppCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.m),
                ),
                alignment: Alignment.center,
                child: const Text('👶', style: TextStyle(fontSize: 44)),
              ),
              Positioned(
                bottom: -14,
                child: AppChip(
                  label: 'Day 42',
                  selected: true,
                  icon: LucideIcons.star,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.moon,
                  iconColor: colors.info,
                  value: '3h 40m',
                  label: 'Last Nap',
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.milk,
                  iconColor: colors.secondary,
                  value: '120 ml',
                  label: 'Feeding',
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.trending_up,
                  iconColor: colors.tertiary,
                  value: '78th',
                  label: 'Percentile',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowthPreview extends StatelessWidget {
  const _GrowthPreview();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERENCE CHART',
                      style: theme.typography.label.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    Text(
                      'Boys 0–12 M',
                      style: theme.typography.subtitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              AppChip(
                label: '52nd %ile',
                selected: true,
                icon: LucideIcons.trending_up,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 88,
            width: double.infinity,
            child: CustomPaint(painter: _GrowthCurvePainter(color: colors.primary)),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.weight,
                  iconColor: colors.primary,
                  value: '3.8 kg',
                  label: 'Weight',
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.ruler,
                  iconColor: colors.secondary,
                  value: '35 cm',
                  label: 'Height',
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _StatTile(
                  icon: LucideIcons.circle,
                  iconColor: colors.tertiary,
                  value: '36 cm',
                  label: 'Head',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowthCurvePainter extends CustomPainter {
  const _GrowthCurvePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.82),
      Offset(size.width * 0.45, size.height * 0.42),
      Offset(size.width, size.height * 0.06),
    ];

    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.12));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthCurvePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MemoryPreview extends StatelessWidget {
  const _MemoryPreview();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.s),
                ),
                alignment: Alignment.center,
                child: const Text('😄', style: TextStyle(fontSize: 48)),
              ),
              Positioned(
                left: AppSpacing.m,
                bottom: AppSpacing.m,
                child: Text(
                  'FIRST BABY LAUGH',
                  style: theme.typography.label.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.s,
                right: AppSpacing.s,
                child: Icon(LucideIcons.heart, size: 16, color: colors.tertiary),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Icon(LucideIcons.volume_2, size: 18, color: colors.primary),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    "Baby's first babble recorded",
                    style: theme.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '0:14s',
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.m,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.s),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.typography.subtitle.copyWith(
              color: colors.textPrimary,
            ),
          ),
          Text(
            label,
            style: theme.typography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

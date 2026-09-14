import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/energy.dart';
import '../../domain/patch.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/choice_list.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';
import 'onboarding_controller.dart';

/// Character creation.
///
/// Five pages, ending on the one that matters most: choosing the day the week
/// closes, and being told plainly that until then the app will not say whether
/// the user is losing or gaining. Better to set that expectation here than to
/// have it read as a bug on Wednesday.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.onComplete, super.key});

  /// Called once the profile has been written.
  final VoidCallback? onComplete;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;

  final _height = TextEditingController();
  final _birthYear = TextEditingController();
  final _weight = TextEditingController();
  final _target = TextEditingController();
  final _stride = TextEditingController();
  final _stepGoal = TextEditingController(text: '10000');

  static const int _lastPage = 4;

  @override
  void dispose() {
    _pages.dispose();
    for (final c in [_height, _birthYear, _weight, _target, _stride, _stepGoal]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Whether the page currently on screen has everything it needs.
  bool _canAdvance(OnboardingDraft draft) => switch (_page) {
        0 => true,
        1 => draft.hasIdentity,
        2 => draft.hasBody,
        3 => draft.hasRoad,
        _ => draft.isComplete,
      };

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingDraftProvider.notifier).commit();
      widget.onComplete?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Hue.surfaceRaised,
          content: Text(
            'Could not begin the Path: $error',
            style: Type.prose(size: 13, color: Hue.vitality),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepTrail(current: _page, total: _lastPage + 1),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _WelcomePage(),
                  _IdentityPage(
                    height: _height,
                    birthYear: _birthYear,
                    stride: _stride,
                  ),
                  _BodyPage(weight: _weight, target: _target),
                  _RoadPage(stride: _stride, stepGoal: _stepGoal, height: _height),
                  const _ReckoningPage(),
                ],
              ),
            ),
            _Footer(
              page: _page,
              lastPage: _lastPage,
              canAdvance: _canAdvance(draft),
              saving: _saving,
              onBack: _page == 0 ? null : () => _go(_page - 1),
              onNext: _page == _lastPage ? _finish : () => _go(_page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diamond nodes showing how far through creation the user is.
class _StepTrail extends StatelessWidget {
  const _StepTrail({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++) ...[
            _TrailNode(state: switch (i.compareTo(current)) {
              < 0 => _NodeState.done,
              0 => _NodeState.current,
              _ => _NodeState.todo,
            }),
            if (i < total - 1)
              Container(
                width: 26,
                height: 1,
                color: i < current ? Hue.goldDim : Hue.steelDim,
              ),
          ],
        ],
      ),
    );
  }
}

enum _NodeState { done, current, todo }

class _TrailNode extends StatelessWidget {
  const _TrailNode({required this.state});

  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final size = state == _NodeState.current ? 13.0 : 9.0;
    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: Transform.rotate(
          angle: 0.785398, // 45 degrees, so the square reads as a diamond
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: state == _NodeState.todo ? Colors.transparent : Hue.gold,
              border: Border.all(
                color: state == _NodeState.todo ? Hue.steel : Hue.gold,
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.lastPage,
    required this.canAdvance,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final bool canAdvance;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        children: [
          if (onBack != null) ...[
            WitcherButton(label: 'Back', onPressed: onBack),
            const SizedBox(width: Space.sm),
          ],
          Expanded(
            child: WitcherButton(
              label: saving
                  ? 'Beginning...'
                  : (page == lastPage ? 'Begin the Path' : 'Continue'),
              tone: ButtonTone.primary,
              expand: true,
              onPressed: canAdvance && !saving ? onNext : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared page chrome: a title, a lore line, and a scrolling body.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.lore, required this.child});

  final String title;
  final String lore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      children: [
        const SizedBox(height: Space.lg),
        Text(title, style: Type.heading(size: 26), textAlign: TextAlign.center),
        const SizedBox(height: Space.sm),
        Text(lore, style: Type.lore(), textAlign: TextAlign.center),
        const RunicDivider(color: Hue.goldDim),
        const SizedBox(height: Space.md),
        child,
        const SizedBox(height: Space.huge),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: "The Witcher's Diet",
      lore: 'Before the Path, the contract.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrnatePanel(
            title: 'The terms',
            accent: Hue.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your weight swings a kilo or two a day on water, salt and '
                  'what is still in your gut. That is larger than any real '
                  'change in a week, so a daily reading mostly measures '
                  'yesterday.',
                  style: Type.prose(size: 14),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'So this app will not tell you whether you are losing or '
                  'gaining until the week is done.',
                  style: Type.prose(size: 14, weight: 600),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Every day you will see what you ate, what it was made of, '
                  'and how far you walked. On the day you choose, the seal '
                  'breaks and you get the whole account at once.',
                  style: Type.prose(size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Nothing here is medical advice.',
            textAlign: TextAlign.center,
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

class _IdentityPage extends ConsumerWidget {
  const _IdentityPage({
    required this.height,
    required this.birthYear,
    required this.stride,
  });

  final TextEditingController height;
  final TextEditingController birthYear;
  final TextEditingController stride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);

    return _Page(
      title: 'Who walks the Path',
      lore: 'Only what the arithmetic needs.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceList<Sex>(
            choices: [
              for (final s in Sex.values) Choice(value: s, title: s.label),
            ],
            selected: draft.sex,
            onSelected: (s) => notifier.update((d) => d.copyWith(sex: s)),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'This only picks a constant in the metabolic-rate formula, which '
            'offers two. "Prefer not to say" uses the midpoint.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
          const SizedBox(height: Space.xl),
          MeasureField(
            label: 'Born',
            unit: 'year',
            hint: '1995',
            controller: birthYear,
            min: 1900,
            max: 2020,
            onChanged: (v) {
              final parsed = MeasureField.parse(v);
              notifier.update((d) => d.copyWith(birthYear: parsed?.round()));
            },
          ),
          const SizedBox(height: Space.xl),
          MeasureField(
            label: 'Height',
            unit: 'cm',
            hint: '178',
            decimal: true,
            controller: height,
            min: 100,
            max: 250,
            helper: 'Your step length is estimated from this; you can correct '
                'it later.',
            onChanged: (v) {
              final parsed = MeasureField.parse(v);
              notifier.update((d) => d.copyWith(heightCm: parsed));
              // Keep the derived stride in step with height until the user
              // overrides it themselves.
              if (parsed != null && draft.strideCm == null) {
                stride.text =
                    EnergyModel.strideFromHeight(parsed).toStringAsFixed(0);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _BodyPage extends ConsumerWidget {
  const _BodyPage({required this.weight, required this.target});

  final TextEditingController weight;
  final TextEditingController target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);

    return _Page(
      title: 'The Body',
      lore: 'Where you stand today, and where you would rather stand.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeasureField(
            label: 'Weight today',
            unit: 'kg',
            hint: '78.4',
            decimal: true,
            controller: weight,
            min: 25,
            max: 400,
            onChanged: (v) => notifier.update(
              (d) => d.copyWith(weightKg: MeasureField.parse(v)),
            ),
          ),
          const SizedBox(height: Space.xl),
          Text('THE AIM', style: Type.label()),
          const SizedBox(height: Space.sm),
          ChoiceList<Goal>(
            choices: [
              for (final g in Goal.values)
                Choice(
                  value: g,
                  title: g.title,
                  blurb: switch (g) {
                    Goal.loseFat => 'About 500 kcal under maintenance a day.',
                    Goal.maintain => 'Eat at maintenance.',
                    Goal.gainMuscle =>
                      'About 250 kcal over. A bigger surplus mostly adds fat.',
                  },
                ),
            ],
            selected: draft.goal,
            onSelected: (g) => notifier.update((d) => d.copyWith(goal: g)),
          ),
          const SizedBox(height: Space.xl),
          MeasureField(
            label: 'Target weight (optional)',
            unit: 'kg',
            hint: '74',
            decimal: true,
            controller: target,
            min: 25,
            max: 400,
            helper: 'Leave empty to just be told what happened, without a '
                'finish line.',
            onChanged: (v) => notifier.update(
              (d) => d.copyWith(targetWeightKg: Patch(MeasureField.parse(v))),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadPage extends ConsumerWidget {
  const _RoadPage({
    required this.stride,
    required this.stepGoal,
    required this.height,
  });

  final TextEditingController stride;
  final TextEditingController stepGoal;
  final TextEditingController height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);

    return _Page(
      title: 'The Road',
      lore: 'How much ground you cover when nothing is hunting you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceList<ActivityLevel>(
            choices: [
              for (final level in ActivityLevel.values)
                Choice(value: level, title: level.title, blurb: level.blurb),
            ],
            selected: draft.activityLevel,
            onSelected: (l) =>
                notifier.update((d) => d.copyWith(activityLevel: l)),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Only used on days with no step data. Once your steps are '
            'flowing, movement is measured rather than guessed.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
          const SizedBox(height: Space.xl),
          MeasureField(
            label: 'Daily step goal',
            unit: 'steps',
            controller: stepGoal,
            min: 1000,
            max: 50000,
            onChanged: (v) => notifier.update(
              (d) => d.copyWith(
                dailyStepGoal: MeasureField.parse(v)?.round() ?? 10000,
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          MeasureField(
            label: 'Step length',
            unit: 'cm',
            decimal: true,
            controller: stride,
            min: 20,
            max: 150,
            helper: 'Estimated from your height. Walk ten steps, measure the '
                'distance, divide by ten if you want it exact.',
            onChanged: (v) => notifier.update(
              (d) => d.copyWith(strideCm: Patch(MeasureField.parse(v))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReckoningPage extends ConsumerWidget {
  const _ReckoningPage();

  static const _weekdays = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final chosen = _weekdays[draft.weekEndsOn]!;

    return _Page(
      title: 'The Reckoning',
      lore: 'Name the day the seal breaks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceList<int>(
            choices: [
              for (final entry in _weekdays.entries)
                Choice(value: entry.key, title: entry.value),
            ],
            selected: draft.weekEndsOn,
            onSelected: (d) => notifier.update((x) => x.copyWith(weekEndsOn: d)),
          ),
          const SizedBox(height: Space.xl),
          OrnatePanel(
            title: 'What this means',
            accent: Hue.gold,
            child: Text(
              'Every other day you will see what you ate and how far you '
              'walked, and nothing about the direction you are travelling. '
              'On $chosen the week closes and you get all of it: energy in '
              'and out, what your weight actually did, and an account of the '
              'week.',
              style: Type.prose(size: 14),
            ),
          ),
          const SizedBox(height: Space.lg),
          _Summary(draft: draft),
        ],
      ),
    );
  }
}

/// The figures the profile implies, shown once before committing.
///
/// Maintenance lives here and in Settings, never on the daily screens — see
/// CLAUDE.md §1. Knowing your maintenance is knowing your body; seeing it
/// printed next to today's intake is being handed the verdict.
class _Summary extends StatelessWidget {
  const _Summary({required this.draft});

  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final bmr = draft.bmr;
    final maintenance = draft.maintenance;
    final target = draft.dailyTarget;

    if (bmr == null || maintenance == null || target == null) {
      return OrnatePanel(
        child: Text(
          'Fill in the earlier pages and your figures will appear here.',
          style: Type.lore(),
        ),
      );
    }

    return OrnatePanel(
      title: 'Your figures',
      child: Column(
        children: [
          _Row(label: 'At rest', value: '${bmr.round()} kcal'),
          const RunicDivider(height: 14),
          _Row(label: 'Maintenance', value: '${maintenance.round()} kcal'),
          const RunicDivider(height: 14),
          _Row(
            label: 'Daily target',
            value: '${target.round()} kcal',
            emphasised: true,
          ),
          const SizedBox(height: Space.md),
          Text(
            'Estimates, not measurements. The weekly reckoning corrects them '
            'against what actually happened.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Engraved labels carry wide letter spacing, so a long one can outrun
        // a narrow panel. Let the label tighten before the value does.
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Type.label(),
          ),
        ),
        const SizedBox(width: Space.sm),
        Text(
          value,
          style: Type.prose(
            size: emphasised ? 17 : 15,
            weight: emphasised ? 600 : 400,
            color: emphasised ? Hue.gold : Hue.parchment,
          ),
        ),
      ],
    );
  }
}

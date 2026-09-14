import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/energy.dart';
import '../../domain/patch.dart';
import '../../providers/app_providers.dart';

/// Everything collected during character creation, before it is committed.
///
/// Held as one immutable value so a step can be revisited without losing what
/// later steps already captured.
class OnboardingDraft {
  const OnboardingDraft({
    this.sex,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.targetWeightKg,
    this.activityLevel,
    this.dailyStepGoal = 10000,
    this.strideCm,
    this.weekEndsOn = DateTime.sunday,
  });

  final Sex? sex;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final Goal? goal;
  final double? targetWeightKg;
  final ActivityLevel? activityLevel;
  final int dailyStepGoal;

  /// Null until the user overrides it; otherwise derived from height.
  final double? strideCm;

  final int weekEndsOn;

  /// Step length to use, measured if given and estimated from height if not.
  double? get effectiveStrideCm =>
      strideCm ?? (heightCm == null ? null : EnergyModel.strideFromHeight(heightCm!));

  /// Fields that can be *cleared* take a [Patch]; the rest take the value.
  ///
  /// Clearing an optional target weight or a typed-then-deleted stride is a
  /// real action, and `value ?? this.value` reads an explicit null as "no
  /// change". See [Patch] for why this is not an `Object?` sentinel.
  OnboardingDraft copyWith({
    Sex? sex,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    Goal? goal,
    Patch<double>? targetWeightKg,
    ActivityLevel? activityLevel,
    int? dailyStepGoal,
    Patch<double>? strideCm,
    int? weekEndsOn,
  }) {
    return OnboardingDraft(
      sex: sex ?? this.sex,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      targetWeightKg: applyPatch(targetWeightKg, this.targetWeightKg),
      activityLevel: activityLevel ?? this.activityLevel,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      strideCm: applyPatch(strideCm, this.strideCm),
      weekEndsOn: weekEndsOn ?? this.weekEndsOn,
    );
  }

  // --- per-step completeness ---

  bool get hasIdentity =>
      sex != null &&
      birthYear != null &&
      heightCm != null &&
      _plausibleBirthYear(birthYear!) &&
      heightCm! >= 100 &&
      heightCm! <= 250;

  bool get hasBody =>
      weightKg != null && goal != null && weightKg! >= 25 && weightKg! <= 400;

  bool get hasRoad => activityLevel != null && (effectiveStrideCm ?? 0) > 20;

  bool get isComplete => hasIdentity && hasBody && hasRoad;

  static bool _plausibleBirthYear(int year) {
    final age = EnergyModel.ageFromBirthYear(year);
    return age >= 13 && age <= 120;
  }

  // --- derived figures, shown on the final page ---

  double? get bmr {
    if (!hasIdentity || weightKg == null) return null;
    return EnergyModel.basalMetabolicRate(
      sex: sex!,
      weightKg: weightKg!,
      heightCm: heightCm!,
      ageYears: EnergyModel.ageFromBirthYear(birthYear!),
    );
  }

  double? get maintenance {
    final base = bmr;
    if (base == null || activityLevel == null) return null;
    return EnergyModel.estimatedExpenditure(bmr: base, level: activityLevel!);
  }

  double? get dailyTarget {
    final m = maintenance;
    if (m == null || goal == null) return null;
    return EnergyModel.dailyTarget(maintenance: m, goal: goal!);
  }
}

/// Holds the draft while character creation is in progress.
final onboardingDraftProvider =
    NotifierProvider.autoDispose<OnboardingDraftNotifier, OnboardingDraft>(
  OnboardingDraftNotifier.new,
);

class OnboardingDraftNotifier extends AutoDisposeNotifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void update(OnboardingDraft Function(OnboardingDraft) change) {
    state = change(state);
  }

  /// Commits the draft, creating the profile and the first weigh-in.
  Future<void> commit() async {
    final draft = state;
    if (!draft.isComplete) {
      throw StateError('Cannot commit an incomplete profile');
    }

    await ref.read(databaseProvider).profileDao.create(
          sex: draft.sex!,
          birthYear: draft.birthYear!,
          heightCm: draft.heightCm!,
          weightKg: draft.weightKg!,
          activityLevel: draft.activityLevel!,
          goal: draft.goal!,
          targetWeightKg: draft.targetWeightKg,
          weekEndsOn: draft.weekEndsOn,
          strideCm: draft.effectiveStrideCm,
          dailyStepGoal: draft.dailyStepGoal,
        );
  }
}

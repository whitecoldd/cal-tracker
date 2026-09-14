import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../domain/day.dart';
import '../../domain/energy.dart';
import '../database.dart';
import '../tables.dart';

part 'profile_dao.g.dart';

/// The user's profile. One row, but a table so migrations stay uniform.
@DriftAccessor(tables: [Profiles, Weights])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// The profile, or null if onboarding has not run.
  Future<Profile?> get() =>
      (select(profiles)..limit(1)).getSingleOrNull();

  Stream<Profile?> watch() => (select(profiles)..limit(1)).watchSingleOrNull();

  Future<bool> exists() async => await get() != null;

  /// Writes the profile and the first weigh-in together.
  ///
  /// The two must land atomically: a profile with no starting weight cannot
  /// produce a BMR, and the app would be stuck in a half-configured state.
  Future<void> create({
    required Sex sex,
    required int birthYear,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    double? targetWeightKg,
    int weekEndsOn = DateTime.sunday,
    double? strideCm,
    int dailyStepGoal = 10000,
  }) async {
    final now = clock.now();
    final stamp = now.toIso8601String();

    await transaction(() async {
      await delete(profiles).go();
      await into(profiles).insert(
        ProfilesCompanion.insert(
          sex: sex,
          birthYear: birthYear,
          heightCm: heightCm,
          activityLevel: activityLevel,
          goal: goal,
          targetWeightKg: Value(targetWeightKg),
          weekEndsOn: Value(weekEndsOn),
          strideCm: Value(strideCm ?? EnergyModel.strideFromHeight(heightCm)),
          dailyStepGoal: Value(dailyStepGoal),
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
      await into(weights).insertOnConflictUpdate(
        WeightsCompanion.insert(
          day: Day.from(now),
          kg: weightKg,
          createdAt: stamp,
        ),
      );
    });
  }

  /// Applies a partial update, stamping [Profiles.updatedAt].
  Future<void> edit(ProfilesCompanion changes) async {
    final current = await get();
    if (current == null) return;

    await (update(profiles)..where((p) => p.id.equals(current.id))).write(
      changes.copyWith(updatedAt: Value(clock.now().toIso8601String())),
    );
  }
}

/// A profile plus the weight it should be evaluated against.
///
/// Energy figures need a current weight, which lives in a different table; this
/// pairs them so callers do not have to remember to fetch both.
extension ProfileEnergy on Profile {
  int get ageYears => EnergyModel.ageFromBirthYear(birthYear);

  double bmrAt(double weightKg) => EnergyModel.basalMetabolicRate(
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        ageYears: ageYears,
      );

  /// Maintenance estimated from the self-described lifestyle. Used when there
  /// is no step data for the day.
  double estimatedMaintenanceAt(double weightKg) =>
      EnergyModel.estimatedExpenditure(
        bmr: bmrAt(weightKg),
        level: activityLevel,
      );

  /// Maintenance from measured movement.
  double measuredMaintenanceAt(
    double weightKg, {
    required int steps,
    double? reportedActiveKcal,
  }) =>
      EnergyModel.totalExpenditure(
        bmr: bmrAt(weightKg),
        steps: steps,
        strideCm: strideCm,
        weightKg: weightKg,
        reportedActiveKcal: reportedActiveKcal,
      );

  /// The daily energy target implied by the goal.
  double dailyTargetAt(double weightKg) => EnergyModel.dailyTarget(
        maintenance: estimatedMaintenanceAt(weightKg),
        goal: goal,
      );
}

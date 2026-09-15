import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/health/activity_sync.dart';
import '../../data/health/step_reader.dart';
import '../../domain/activity.dart';
import '../../providers/app_providers.dart';
import '../journal/journal_providers.dart';

/// Health Connect. Overridden in tests, which have no device.
final stepReaderProvider =
    Provider<StepReader>((ref) => HealthConnectReader());

final activitySyncProvider = Provider<ActivitySync>(
  (ref) => ActivitySync(
    reader: ref.watch(stepReaderProvider),
    tracking: ref.watch(databaseProvider).trackingDao,
  ),
);

/// Bumped after a sync or a manual entry, so the day re-reads.
final activityTickProvider =
    NotifierProvider<ActivityTick, int>(ActivityTick.new);

class ActivityTick extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

/// Whether movement can be read on this device at all.
final healthAvailabilityProvider = FutureProvider<HealthAvailability>(
  (ref) => ref.watch(stepReaderProvider).availability(),
);

/// Whether permission has been granted.
final healthPermissionProvider = FutureProvider<bool>((ref) {
  ref.watch(activityTickProvider);
  return ref.watch(stepReaderProvider).hasPermission();
});

/// The selected day's movement, in the form the UI is allowed to see.
///
/// Returns an [ActivityView], which has nowhere to put an energy figure. The
/// stored row carries one — the weekly reckoning needs it — but it does not
/// cross into a widget. See CLAUDE.md §1.
final dayActivityProvider = FutureProvider<ActivityView>((ref) async {
  ref.watch(activityTickProvider);

  final day = ref.watch(journalDayProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final stepGoal = profile?.dailyStepGoal ?? 10000;

  final row = await ref.watch(databaseProvider).trackingDao.activityFor(day);
  if (row == null) {
    return ActivityView(
      steps: 0,
      distanceM: 0,
      stepGoal: stepGoal,
      stamina: 0,
    );
  }

  return ActivityView.of(ActivitySync.fromRow(row), stepGoal: stepGoal);
});

/// Whether the selected day's figures were typed rather than measured.
final dayActivityIsManualProvider = FutureProvider<bool>((ref) async {
  ref.watch(activityTickProvider);
  final day = ref.watch(journalDayProvider);
  final row = await ref.watch(databaseProvider).trackingDao.activityFor(day);
  return row != null && ActivitySync.fromRow(row).isManual;
});

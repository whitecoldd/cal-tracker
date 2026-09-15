import 'package:health/health.dart';

import '../../domain/activity.dart';
import '../../domain/day.dart';

/// Whether movement data can be read on this device at all.
enum HealthAvailability {
  /// Health Connect is installed and usable.
  ready,

  /// The device has Health Connect but it needs updating.
  needsUpdate,

  /// Health Connect is not installed. The user can still type step counts.
  notInstalled,

  /// Not Android — the web build, or a desktop run.
  unsupported,
}

/// Reads movement from the platform.
///
/// An interface because the implementation is a platform channel talking to
/// another app: no unit test can run it, and a test that needed one would need
/// a device with Health Connect installed and populated. The sync logic and
/// the merge rules are worth testing without any of that.
abstract interface class StepReader {
  Future<HealthAvailability> availability();

  /// Whether permission has already been granted.
  Future<bool> hasPermission();

  /// Asks for permission. Returns whether it was granted.
  ///
  /// The request is made by the `health` plugin itself — there is no
  /// `permission_handler` in this project, and `MainActivity` extends
  /// `FlutterFragmentActivity` precisely so the plugin can run its permission
  /// contract. See CLAUDE.md §3.
  Future<bool> requestPermission();

  /// Sends the user to install Health Connect.
  Future<void> promptInstall();

  /// Movement for each day in an inclusive range.
  ///
  /// Days with nothing recorded are simply absent rather than returned as
  /// zeros: a day the device did not see is unknown, and writing a zero would
  /// claim the user did not move.
  Future<List<DayActivity>> read({required Day from, required Day to});
}

/// Health Connect, via the `health` plugin.
class HealthConnectReader implements StepReader {
  HealthConnectReader({Health? health}) : _health = health ?? Health();

  final Health _health;

  /// Only what the app actually uses.
  ///
  /// Asking for more would widen the permission dialog for data that is never
  /// read, and a permission screen that over-asks is one people decline.
  static const List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static final List<HealthDataAccess> _access =
      List.filled(types.length, HealthDataAccess.READ);

  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    await _configure();
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.ready,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthAvailability.needsUpdate,
        HealthConnectSdkStatus.sdkUnavailable => HealthAvailability.notInstalled,
        null => HealthAvailability.unsupported,
      };
    } on Exception {
      // The plugin throws on a non-Android platform rather than answering.
      return HealthAvailability.unsupported;
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _configure();
    return await _health.hasPermissions(types, permissions: _access) ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _configure();
    return _health.requestAuthorization(types, permissions: _access);
  }

  @override
  Future<void> promptInstall() async {
    await _configure();
    await _health.installHealthConnect();
  }

  @override
  Future<List<DayActivity>> read({required Day from, required Day to}) async {
    await _configure();

    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: from.toDateTime(),
      // The whole of the last day, not its midnight.
      endTime: to.addDays(1).toDateTime(),
    );

    return foldPoints(points);
  }

  /// Folds raw points into one row per day.
  ///
  /// Static and pure over the plugin's own type, so the awkward part — a day
  /// boundary, three data types and a pile of short intervals — is testable
  /// without a device.
  static List<DayActivity> foldPoints(List<HealthDataPoint> points) {
    final steps = <Day, double>{};
    final distance = <Day, double>{};
    final energy = <Day, double>{};

    for (final point in points) {
      final value = point.value;
      if (value is! NumericHealthValue) continue;

      final amount = value.numericValue.toDouble();
      if (amount.isNaN || amount < 0) continue;

      // Attributed to the day the interval *started*.
      //
      // A walk that crosses midnight is rare and a sleep-tracking record that
      // does so is not; splitting the interval proportionally would be more
      // correct and less predictable, and the user reads these numbers against
      // a calendar day they remember.
      final day = Day.from(point.dateFrom);

      switch (point.type) {
        case HealthDataType.STEPS:
          steps.update(day, (v) => v + amount, ifAbsent: () => amount);
        case HealthDataType.DISTANCE_DELTA:
          distance.update(day, (v) => v + amount, ifAbsent: () => amount);
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          energy.update(day, (v) => v + amount, ifAbsent: () => amount);
        default:
          break;
      }
    }

    final days = <Day>{...steps.keys, ...distance.keys, ...energy.keys};

    return [
      for (final day in days.toList()..sort())
        DayActivity(
          day: day,
          steps: (steps[day] ?? 0).round(),
          distanceM: distance[day] ?? 0,
          activeKcal: energy[day],
        ),
    ];
  }
}

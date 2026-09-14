import 'package:clock/clock.dart';

/// A calendar day, independent of time and timezone.
///
/// Everything in this app is keyed by day: what you ate, how far you walked,
/// what you weighed, and — crucially — which week a value belongs to. Storing
/// those as `DateTime` invites a timezone shift to move a log across a day
/// boundary and silently move it into a different week, which would corrupt the
/// one number the whole product is built around.
///
/// So a day is stored as a plain `yyyymmdd` integer: timezone-free, sorts
/// correctly, and readable when you open the database by hand.
class Day implements Comparable<Day> {
  const Day(this.value);

  /// The calendar day [dt] falls on, in local time.
  factory Day.from(DateTime dt) =>
      Day(dt.year * 10000 + dt.month * 100 + dt.day);

  /// Today, per `package:clock` so tests can freeze the calendar.
  factory Day.today() => Day.from(clock.now());

  factory Day.of(int year, int month, int dayOfMonth) =>
      Day.from(DateTime(year, month, dayOfMonth));

  /// `yyyymmdd`, e.g. 20260914.
  final int value;

  int get year => value ~/ 10000;
  int get month => (value ~/ 100) % 100;
  int get dayOfMonth => value % 100;

  /// Midnight local time on this day.
  DateTime toDateTime() => DateTime(year, month, dayOfMonth);

  /// ISO weekday: Monday is 1, Sunday is 7.
  int get weekday => toDateTime().weekday;

  Day addDays(int days) {
    final d = toDateTime();
    // Reconstructing through DateTime handles month lengths and DST for us.
    return Day.from(DateTime(d.year, d.month, d.day + days));
  }

  /// Whole days from this day to [other]. Negative if [other] is earlier.
  int daysUntil(Day other) =>
      other.toDateTime().difference(toDateTime()).inDays;

  /// The last day of the week containing this day, given a week that ends on
  /// [weekEndsOn] (ISO weekday, Monday 1 .. Sunday 7).
  ///
  /// A day that *is* the week-end day is the last day of its own week, not the
  /// first day of the next one — the reveal happens on that day, about the week
  /// it closes.
  Day endOfWeek({required int weekEndsOn}) {
    assert(weekEndsOn >= DateTime.monday && weekEndsOn <= DateTime.sunday);
    final delta = (weekEndsOn - weekday + 7) % 7;
    return addDays(delta);
  }

  /// The first day of the week containing this day. See [endOfWeek].
  Day startOfWeek({required int weekEndsOn}) =>
      endOfWeek(weekEndsOn: weekEndsOn).addDays(-6);

  /// Every day of the week containing this day, in order.
  List<Day> weekDays({required int weekEndsOn}) {
    final start = startOfWeek(weekEndsOn: weekEndsOn);
    return [for (var i = 0; i < 7; i++) start.addDays(i)];
  }

  bool isBefore(Day other) => value < other.value;
  bool isAfter(Day other) => value > other.value;

  @override
  int compareTo(Day other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Day && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// ISO-8601 date, e.g. `2026-09-14`.
  @override
  String toString() => '$year-${_pad(month)}-${_pad(dayOfMonth)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

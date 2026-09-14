import 'package:cal_tracker/domain/day.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Day', () {
    test('stores a date as yyyymmdd', () {
      expect(Day.of(2026, 9, 14).value, 20260914);
      expect(Day.of(2026, 1, 1).value, 20260101);
      expect(const Day(20261231).toString(), '2026-12-31');
    });

    test('reads today through package:clock so tests can freeze it', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14, 23, 59)), () {
        expect(Day.today(), Day.of(2026, 9, 14));
      });
    });

    test('day arithmetic crosses months, years and leap days', () {
      expect(Day.of(2026, 1, 31).addDays(1), Day.of(2026, 2, 1));
      expect(Day.of(2026, 12, 31).addDays(1), Day.of(2027, 1, 1));
      expect(Day.of(2026, 3, 1).addDays(-1), Day.of(2026, 2, 28));
      // 2028 is a leap year.
      expect(Day.of(2028, 3, 1).addDays(-1), Day.of(2028, 2, 29));
    });

    test('daysUntil counts whole days in both directions', () {
      expect(Day.of(2026, 9, 14).daysUntil(Day.of(2026, 9, 21)), 7);
      expect(Day.of(2026, 9, 21).daysUntil(Day.of(2026, 9, 14)), -7);
      expect(Day.of(2026, 9, 14).daysUntil(Day.of(2026, 9, 14)), 0);
    });

    test('sorts and compares by calendar order', () {
      final days = [
        Day.of(2026, 10, 1),
        Day.of(2026, 9, 30),
        Day.of(2027, 1, 1),
      ]..sort();

      expect(days, [
        Day.of(2026, 9, 30),
        Day.of(2026, 10, 1),
        Day.of(2027, 1, 1),
      ]);
      expect(Day.of(2026, 9, 30).isBefore(Day.of(2026, 10, 1)), isTrue);
      expect(Day.of(2027, 1, 1).isAfter(Day.of(2026, 10, 1)), isTrue);
    });
  });

  group('week boundaries', () {
    // 2026-09-14 is a Monday; 2026-09-20 is the Sunday that closes its week.
    final monday = Day.of(2026, 9, 14);
    final wednesday = Day.of(2026, 9, 16);
    final sunday = Day.of(2026, 9, 20);

    test('a mid-week day resolves to the surrounding Monday-Sunday week', () {
      expect(wednesday.startOfWeek(weekEndsOn: DateTime.sunday), monday);
      expect(wednesday.endOfWeek(weekEndsOn: DateTime.sunday), sunday);
    });

    test('the week-end day closes its own week rather than opening the next',
        () {
      // This is the case that matters: the reveal happens on Sunday, about the
      // week Sunday finishes. Getting this wrong would reveal a week early.
      expect(sunday.endOfWeek(weekEndsOn: DateTime.sunday), sunday);
      expect(sunday.startOfWeek(weekEndsOn: DateTime.sunday), monday);
    });

    test('the day after the week-end starts a fresh week', () {
      final nextMonday = Day.of(2026, 9, 21);
      expect(nextMonday.startOfWeek(weekEndsOn: DateTime.sunday), nextMonday);
      expect(
        nextMonday.endOfWeek(weekEndsOn: DateTime.sunday),
        Day.of(2026, 9, 27),
      );
    });

    test('honours a week that closes on a weekday other than Sunday', () {
      // Week ends Wednesday, so the week containing Monday the 14th runs
      // Thursday the 10th to Wednesday the 16th.
      expect(monday.endOfWeek(weekEndsOn: DateTime.wednesday), wednesday);
      expect(
        monday.startOfWeek(weekEndsOn: DateTime.wednesday),
        Day.of(2026, 9, 10),
      );
    });

    test('every weekday in a week maps to the same boundaries', () {
      for (var i = 0; i < 7; i++) {
        final day = monday.addDays(i);
        expect(
          day.startOfWeek(weekEndsOn: DateTime.sunday),
          monday,
          reason: 'failed for $day (weekday ${day.weekday})',
        );
        expect(day.endOfWeek(weekEndsOn: DateTime.sunday), sunday);
      }
    });

    test('weekDays lists exactly seven consecutive days, start to end', () {
      final days = wednesday.weekDays(weekEndsOn: DateTime.sunday);
      expect(days, hasLength(7));
      expect(days.first, monday);
      expect(days.last, sunday);
      for (var i = 1; i < days.length; i++) {
        expect(days[i - 1].addDays(1), days[i]);
      }
    });

    test('week boundaries hold across a year boundary', () {
      // 2026-12-31 is a Thursday, so its week runs Mon 28 Dec to Sun 3 Jan.
      final newYearsEve = Day.of(2026, 12, 31);
      expect(newYearsEve.weekday, DateTime.thursday);
      expect(
        newYearsEve.startOfWeek(weekEndsOn: DateTime.sunday),
        Day.of(2026, 12, 28),
      );
      expect(
        newYearsEve.endOfWeek(weekEndsOn: DateTime.sunday),
        Day.of(2027, 1, 3),
      );
    });
  });
}

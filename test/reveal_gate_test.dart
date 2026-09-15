import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 14 September 2026 through Sunday 20 September 2026.
///
/// A real, contiguous week written out by hand so the weekday arithmetic is
/// checked against the calendar rather than against itself.
const _week = <int, Day>{
  DateTime.monday: Day(20260914),
  DateTime.tuesday: Day(20260915),
  DateTime.wednesday: Day(20260916),
  DateTime.thursday: Day(20260917),
  DateTime.friday: Day(20260918),
  DateTime.saturday: Day(20260919),
  DateTime.sunday: Day(20260920),
};

String _name(int weekday) => const {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    }[weekday]!;

void main() {
  test('the fixture week really is the weekdays it claims', () {
    // If this drifts, every test below is measuring the wrong thing.
    _week.forEach((weekday, day) {
      expect(day.weekday, weekday, reason: '$day should be ${_name(weekday)}');
    });
  });

  group('the current week is sealed on every day but its last', () {
    // The invariant, stated across every configuration the app allows: seven
    // possible week-end days times seven days of the week. See CLAUDE.md §1.
    for (final weekEndsOn in [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ]) {
      group('week ending ${_name(weekEndsOn)}', () {
        final gate = RevealGate(weekEndsOn: weekEndsOn);

        for (final entry in _week.entries) {
          final today = entry.value;
          final isRevealDay = entry.key == weekEndsOn;

          test('on ${_name(entry.key)} the live week is '
              '${isRevealDay ? "revealed" : "sealed"}', () {
            expect(
              gate.isRevealed(today, today: today),
              isRevealDay,
              reason: 'week ending ${_name(weekEndsOn)}, '
                  'read on ${_name(entry.key)}',
            );
          });
        }
      });
    }
  });

  group('a closed week is history', () {
    const gate = RevealGate(weekEndsOn: DateTime.sunday);

    test('last week reads on any day of this one', () {
      final lastWeek = _week[DateTime.wednesday]!.addDays(-7);

      for (final today in _week.values) {
        expect(
          gate.isRevealed(lastWeek, today: today),
          isTrue,
          reason: 'a week that has already closed must stay readable',
        );
      }
    });

    test('a week far in the past reads', () {
      expect(
        gate.isRevealed(const Day(20250101), today: _week[DateTime.tuesday]!),
        isTrue,
      );
    });
  });

  group('a future week is never readable', () {
    const gate = RevealGate(weekEndsOn: DateTime.sunday);

    test('not even on a reveal day', () {
      final nextWeek = _week[DateTime.monday]!.addDays(7);

      expect(
        gate.isRevealed(nextWeek, today: _week[DateTime.sunday]!),
        isFalse,
        reason: 'the reveal opens the week it closes, not the one after',
      );
    });
  });

  group('the boundary between weeks', () {
    test('the week-end day closes its own week, not the next one', () {
      const gate = RevealGate(weekEndsOn: DateTime.sunday);
      final sunday = _week[DateTime.sunday]!;
      final mondayBefore = _week[DateTime.monday]!;

      // Sunday's reveal is about the week that Monday began — otherwise the
      // reveal would describe a week that had only just started.
      expect(gate.isRevealed(mondayBefore, today: sunday), isTrue);
    });

    test('the day after a reveal seals the new week immediately', () {
      const gate = RevealGate(weekEndsOn: DateTime.sunday);
      final monday = _week[DateTime.sunday]!.addDays(1);

      expect(gate.isRevealed(monday, today: monday), isFalse);
      // But last week is still readable.
      expect(gate.isRevealed(_week[DateTime.sunday]!, today: monday), isTrue);
    });

    test('a mid-week weekEndsOn splits the calendar week correctly', () {
      const gate = RevealGate(weekEndsOn: DateTime.wednesday);
      final wednesday = _week[DateTime.wednesday]!;

      // Thursday..Wednesday is the week. Thursday of the *previous* calendar
      // week belongs to the week Wednesday closes.
      expect(gate.isRevealed(wednesday.addDays(-6), today: wednesday), isTrue);
      // The day after belongs to the next week and stays sealed.
      expect(gate.isRevealed(wednesday.addDays(1), today: wednesday), isFalse);
    });
  });

  group('isRevealDay', () {
    test('is true only on the configured weekday', () {
      const gate = RevealGate(weekEndsOn: DateTime.friday);

      for (final entry in _week.entries) {
        expect(
          gate.isRevealDay(entry.value),
          entry.key == DateTime.friday,
          reason: _name(entry.key),
        );
      }
    });
  });

  group('daysUntilReveal', () {
    const gate = RevealGate(weekEndsOn: DateTime.sunday);

    test('counts down across the week', () {
      expect(
        gate.daysUntilReveal(
          _week[DateTime.monday]!,
          today: _week[DateTime.monday]!,
        ),
        6,
      );
      expect(
        gate.daysUntilReveal(
          _week[DateTime.friday]!,
          today: _week[DateTime.friday]!,
        ),
        2,
      );
    });

    test('is zero on the day itself', () {
      expect(
        gate.daysUntilReveal(
          _week[DateTime.sunday]!,
          today: _week[DateTime.sunday]!,
        ),
        0,
      );
    });

    test('never goes negative for a week already closed', () {
      final lastWeek = _week[DateTime.monday]!.addDays(-7);
      expect(
        gate.daysUntilReveal(lastWeek, today: _week[DateTime.wednesday]!),
        0,
      );
    });
  });

  group('gate()', () {
    const gate = RevealGate(weekEndsOn: DateTime.sunday);

    test('does not compute a sealed value at all', () {
      // The point of taking a callback. A sealed verdict is never calculated,
      // so there is no number in memory for a log line, a toString or a later
      // refactor to reach past the type and find.
      var calls = 0;

      final result = gate.gate<int>(
        _week[DateTime.wednesday]!,
        today: _week[DateTime.wednesday]!,
        compute: () {
          calls++;
          return 42;
        },
      );

      expect(result, isA<Sealed<int>>());
      expect(calls, 0, reason: 'a sealed verdict must never be computed');
    });

    test('computes exactly once when revealed', () {
      var calls = 0;

      final result = gate.gate<int>(
        _week[DateTime.sunday]!,
        today: _week[DateTime.sunday]!,
        compute: () {
          calls++;
          return 42;
        },
      );

      expect(result, const Revealed(42));
      expect(calls, 1);
    });
  });

  group('the gate rejects a nonsense configuration', () {
    test('weekEndsOn outside 1..7 trips an assertion', () {
      expect(() => RevealGate(weekEndsOn: 0), throwsA(isA<AssertionError>()));
      expect(() => RevealGate(weekEndsOn: 8), throwsA(isA<AssertionError>()));
    });
  });
}

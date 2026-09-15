import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/activity.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/features/activity/activity_panel.dart';
import 'package:cal_tracker/features/activity/activity_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _today = Day(20260915);
const _now = '2026-09-15T10:00:00.000';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  /// Pumps the panel with a settled view.
  ///
  /// The provider awaits a drift query, and a widget-test body runs in fake
  /// async that never turns the real event loop. See CLAUDE.md §2.
  Future<void> pump(
    WidgetTester tester, {
    required ActivityView view,
    bool isManual = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dayActivityProvider.overrideWith((ref) async => view),
            dayActivityIsManualProvider.overrideWith((ref) async => isManual),
          ],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: ActivityPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

  group('what the panel shows', () {
    testWidgets('steps, distance and stamina', (tester) async {
      await pump(
        tester,
        view: const ActivityView(
          steps: 8240,
          distanceM: 6100,
          stepGoal: 10000,
          stamina: 82.4,
        ),
      );

      final text = visibleText(tester);
      expect(text, contains('8,240'));
      expect(text, contains('6.1 km'));
      expect(text, contains('stamina'));
    });

    testWidgets('says plainly when nothing was recorded', (tester) async {
      await pump(tester, view: ActivityView.empty);

      expect(visibleText(tester), contains('no movement recorded'));
    });

    testWidgets('marks a day that was typed by hand', (tester) async {
      await pump(
        tester,
        view: const ActivityView(
          steps: 12000,
          distanceM: 8900,
          stepGoal: 10000,
          stamina: 100,
        ),
        isManual: true,
      );

      expect(visibleText(tester), contains('entered by hand'));
      expect(visibleText(tester), contains('will not overwrite'));
    });
  });

  group('the blackout', () {
    testWidgets('never shows an energy figure', (tester) async {
      // The stored row carries active energy — the weekly reckoning needs it —
      // but it is a term of expenditure, and intake beside expenditure is the
      // verdict. The guard is ActivityView, which has nowhere to put it.
      // See CLAUDE.md §1.
      await real(tester, () async {
        await db.trackingDao.upsertActivity(
          ActivityDaysCompanion.insert(
            day: _today,
            steps: const Value(8240),
            distanceM: const Value(6100),
            // A figure that must not reach the glass.
            activeKcal: const Value(437),
            source: ActivitySource.healthConnect,
            updatedAt: _now,
          ),
        );
      });

      final stored = await real(
        tester,
        () => db.trackingDao.activityFor(_today),
      );
      expect(stored!.activeKcal, 437, reason: 'it is stored...');

      await pump(
        tester,
        view: ActivityView.of(
          DayActivity(
            day: _today,
            steps: stored.steps,
            distanceM: stored.distanceM,
            activeKcal: stored.activeKcal,
          ),
          stepGoal: 10000,
        ),
      );

      final text = visibleText(tester);
      // ...and never rendered.
      expect(text, isNot(contains('437')));
      for (final banned in const [
        'kcal',
        'burned',
        'calories',
        'energy',
        'deficit',
        'surplus',
        'remaining',
      ]) {
        expect(
          text.contains(banned),
          isFalse,
          reason: 'the activity panel showed "$banned": $text',
        );
      }
    });
  });

  group('step formatting', () {
    testWidgets('groups thousands, because five digits are unreadable',
        (tester) async {
      await pump(
        tester,
        view: const ActivityView(
          steps: 12345,
          distanceM: 9000,
          stepGoal: 10000,
          stamina: 100,
        ),
      );

      expect(visibleText(tester), contains('12,345'));
    });
  });
}

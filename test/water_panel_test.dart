import 'package:cal_tracker/data/daos/journal_dao.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/features/journal/water_panel.dart';
import 'package:cal_tracker/features/journal/water_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-14T10:00:00.000';
final _today = Day.of(2026, 9, 14);

/// Runs [body] on the real event loop.
///
/// A widget test body runs in fake async, which never turns the real loop, so
/// an awaited drift query never completes. See CLAUDE.md §2.
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
  late T result;
  await tester.runAsync(() async => result = await body());
  return result;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<LoggedItem> drink(
    String name, {
    required double ml,
    double alcoholPer100 = 0,
  }) async {
    final id = await db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: name,
        searchKey: name.toLowerCase(),
        kcal: 40,
        alcoholG: Value(alcoholPer100),
        source: FoodSource.seed,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    final food = (await db.foodsDao.findById(id))!;
    return LoggedItem(
      entry: Entry(
        id: 1,
        foodId: id,
        day: _today,
        mealSlot: MealSlot.snack,
        quantity: ml,
        unit: PortionUnit.millilitres,
        grams: ml,
        confidence: 1,
        createdAt: _now,
      ),
      food: food,
    );
  }

  /// Pumps the panel against settled snapshots.
  ///
  /// Both providers are overridden with settled values rather than live drift
  /// streams: a query stream schedules a zero-duration timer on cancel that the
  /// binding reports as a leak. See CLAUDE.md §2.
  Future<void> pump(
    WidgetTester tester, {
    int? loggedMl,
    List<LoggedItem> items = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          journalDayProvider.overrideWith(() => _FixedDay()),
          journalEntriesProvider.overrideWith((ref) => Stream.value(items)),
          waterLogProvider.overrideWith(
            (ref) => Stream.value(
              loggedMl == null
                  ? null
                  : WaterLog(day: _today, ml: loggedMl, updatedAt: _now),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: WaterPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an untouched waterskin reads empty', (tester) async {
    await pump(tester);

    expect(find.text('0 of 2,000 ml'), findsOneWidget);
  });

  testWidgets('the figure is phrased as lore, never as a ratio',
      (tester) async {
    await pump(tester, loggedMl: 1500);

    expect(find.text('1,500 of 2,000 ml'), findsOneWidget);
    // An `x / y` ring is the progress framing the whole app refuses, and the
    // Journal has a test that fails outright if a slash appears on it.
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('target'), findsNothing);
    expect(find.textContaining('goal'), findsNothing);
  });

  testWidgets('tapping +250 writes it down', (tester) async {
    await pump(tester, loggedMl: 500);

    await tester.tap(find.text('+250'));
    await tester.pumpAndSettle();

    final stored = await real(tester, () => db.trackingDao.waterFor(_today));
    expect(stored!.ml, 750);
  });

  testWidgets('the minus button undoes exactly the last add', (tester) async {
    await pump(tester, loggedMl: 1000);

    // Before anything is added it offers the smaller step.
    expect(find.text('−250'), findsOneWidget);

    await tester.tap(find.text('+500'));
    await tester.pumpAndSettle();

    expect(find.text('−500'), findsOneWidget);
  });

  testWidgets('an empty waterskin cannot go negative', (tester) async {
    await pump(tester);

    // Nothing to take away, so the decrement is not offered at all.
    final minus = tester.widget<InkWell>(
      find.ancestor(of: find.text('−250'), matching: find.byType(InkWell)),
    );
    expect(minus.onTap, isNull);
  });

  testWidgets('a drink logged as food counts towards the day', (tester) async {
    final cola = await real(tester, () => drink('Cola', ml: 400));
    await pump(tester, loggedMl: 1000, items: [cola]);

    expect(find.text('1,400 of 2,000 ml'), findsOneWidget);
    expect(find.textContaining('400 ml of that came from'), findsOneWidget);
  });

  testWidgets('beer is logged, and credits nothing', (tester) async {
    final beer = await real(
      tester,
      () => drink('Beer, 5%', ml: 330, alcoholPer100: 3.9),
    );
    await pump(tester, loggedMl: 1000, items: [beer]);

    expect(find.text('1,000 of 2,000 ml'), findsOneWidget);
    expect(find.textContaining('came from'), findsNothing);
  });
}

/// A day cursor pinned to the test's day.
class _FixedDay extends JournalDayNotifier {
  @override
  Day build() => _today;
}

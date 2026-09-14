import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// database.g.dart is a *part* of this library, so it can only see the imports
// declared here — not the ones tables.dart makes. Every domain type used in a
// column (Day, and the enums behind textEnum) must therefore be imported here
// too, or the app fails to compile while `flutter analyze` stays clean.
import '../domain/day.dart';
import '../domain/energy.dart';
import 'daos/ai_calls_dao.dart';
import 'daos/foods_dao.dart';
import 'daos/journal_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/tracking_dao.dart';
import 'daos/weeks_dao.dart';
import 'tables.dart';

part 'database.g.dart';

/// The on-device database.
///
/// Everything the app knows lives here. It is mirrored to a folder outside the
/// app sandbox (see T13) so an uninstall cannot take it, and it is included in
/// Android Auto Backup.
@DriftDatabase(
  tables: [
    Profiles,
    Foods,
    Entries,
    ActivityDays,
    Weights,
    WaterLogs,
    Weeks,
    AiCalls,
    Achievements,
  ],
  daos: [ProfileDao, FoodsDao, JournalDao, TrackingDao, WeeksDao, AiCallsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // Schema is at version 1; every future migration is added here as an
          // explicit `if (from < n)` step. Never edit an existing step —
          // installed copies have already run it.
          await _createIndexes();
        },
        beforeOpen: (details) async {
          // Drift disables foreign keys by default; entries reference foods and
          // we want a broken reference to fail loudly rather than silently.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Indexes for the reads the app actually does: a day's journal, the week's
  /// aggregates, local food search, and today's AI budget.
  Future<void> _createIndexes() async {
    for (final statement in const [
      'CREATE INDEX IF NOT EXISTS idx_entries_day ON entries (day)',
      'CREATE INDEX IF NOT EXISTS idx_entries_food ON entries (food_id)',
      'CREATE INDEX IF NOT EXISTS idx_foods_search ON foods (search_key)',
      'CREATE INDEX IF NOT EXISTS idx_foods_barcode ON foods (barcode)',
      'CREATE INDEX IF NOT EXISTS idx_ai_calls_day ON ai_calls (day)',
    ]) {
      await customStatement(statement);
    }
  }
}

/// Opens the database file in the app's documents directory.
///
/// Runs on a background isolate so a large query cannot jank the UI.
QueryExecutor _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'witchers_diet.sqlite'));

    // Older Android builds ship a temp directory sqlite3 cannot find on its own.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}

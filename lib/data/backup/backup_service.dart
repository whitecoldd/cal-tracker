import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database.dart';
import 'snapshot.dart';
import 'storage_access.dart';

/// What a backup or restore did.
class BackupOutcome {
  const BackupOutcome({
    required this.ok,
    required this.message,
    this.rows = 0,
    this.path,
  });

  final bool ok;
  final String message;
  final int rows;
  final String? path;
}

/// Reads the database out to a folder, and back in again.
///
/// Layer two of "survives reinstall". Android Auto Backup is layer one and is
/// invisible and unverifiable; this is the one the user can see, copy off the
/// phone, and open on a computer. A backup nobody can inspect is a backup
/// nobody discovers is broken.
class BackupService {
  const BackupService({
    required AppDatabase db,
    required StorageAccess access,
    String? directory,
  })  : _db = db,
        _access = access,
        _directory = directory;

  final AppDatabase _db;
  final StorageAccess _access;
  final String? _directory;

  /// A real, browsable path rather than app-private storage.
  ///
  /// The whole point is that it survives the app being uninstalled, and that
  /// the user can reach it with a file manager or a USB cable.
  static const String defaultDirectory =
      '/storage/emulated/0/Documents/WitcherDiet';

  static const String jsonName = 'witchers-diet-backup.json';
  static const String markdownName = 'Journal.md';

  String get directory => _directory ?? defaultDirectory;

  File get jsonFile => File(p.join(directory, jsonName));
  File get markdownFile => File(p.join(directory, markdownName));

  /// Reads every table into a snapshot.
  Future<BackupSnapshot> snapshot() async {
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in BackupSnapshot.tableOrder) {
      final rows = await _rowsOf(table);
      if (rows != null) tables[table] = rows;
    }

    return BackupSnapshot(
      version: BackupSnapshot.currentVersion,
      takenAt: clock.now(),
      tables: tables,
    );
  }

  /// Writes the mirror.
  ///
  /// Both files are written together and the JSON goes last: if the write is
  /// interrupted, a stale JSON beside a fresh Markdown is recoverable, while a
  /// half-written JSON is not.
  Future<BackupOutcome> writeMirror() async {
    if (!await _access.hasAccess()) {
      return const BackupOutcome(
        ok: false,
        message: 'Storage access has not been granted.',
      );
    }

    try {
      final folder = Directory(directory);
      if (!folder.existsSync()) folder.createSync(recursive: true);

      final taken = await snapshot();

      await markdownFile.writeAsString(BackupMarkdown.render(taken));
      // Written to a temporary name first, then moved: a rename is atomic on
      // the same filesystem, so a backup is never left half-written.
      final temp = File('${jsonFile.path}.part');
      await temp.writeAsString(taken.encode());
      await temp.rename(jsonFile.path);

      return BackupOutcome(
        ok: true,
        message: '${taken.rowCount} rows written.',
        rows: taken.rowCount,
        path: directory,
      );
    } on FileSystemException catch (e) {
      return BackupOutcome(ok: false, message: 'Could not write: ${e.message}');
    }
  }

  /// Whether a backup is sitting in the folder, and what it holds.
  Future<BackupSnapshot?> findExisting() async {
    try {
      if (!jsonFile.existsSync()) return null;
      return BackupSnapshot.decode(await jsonFile.readAsString());
    } on FileSystemException {
      return null;
    }
  }

  /// Replaces everything in the database with a snapshot.
  ///
  /// **Destructive, and all-or-nothing.** Runs in one transaction so a restore
  /// that fails halfway leaves the existing data intact — the worst possible
  /// outcome here is a half-restored database that looks plausible.
  Future<BackupOutcome> restore(BackupSnapshot snapshot) async {
    if (!snapshot.isReadable) {
      return BackupOutcome(
        ok: false,
        message: 'That backup was written by a newer version of the app '
            '(format ${snapshot.version}).',
      );
    }

    if (snapshot.isEmpty) {
      return const BackupOutcome(ok: false, message: 'That backup is empty.');
    }

    try {
      var written = 0;

      await _db.transaction(() async {
        // Cleared in reverse order, so a child table goes before its parent.
        for (final table in BackupSnapshot.tableOrder.reversed) {
          await _clear(table);
        }

        for (final table in BackupSnapshot.tableOrder) {
          written += await _insert(table, snapshot.tables[table] ?? const []);
        }
      });

      return BackupOutcome(
        ok: true,
        message: '$written rows restored.',
        rows: written,
      );
    } on Object catch (e) {
      return BackupOutcome(ok: false, message: 'Restore failed: $e');
    }
  }

  /// Restores from the folder, if there is anything there to restore from.
  Future<BackupOutcome> restoreFromMirror() async {
    if (!await _access.hasAccess()) {
      return const BackupOutcome(
        ok: false,
        message: 'Storage access has not been granted.',
      );
    }

    final found = await findExisting();
    if (found == null) {
      return const BackupOutcome(
        ok: false,
        message: 'No backup found in that folder.',
      );
    }

    return restore(found);
  }

  /// Whether the database has anything in it at all.
  ///
  /// Drives the offer to restore on first launch: an app with a profile
  /// already has a life of its own and must not be quietly overwritten.
  Future<bool> get isFresh async {
    final profiles = await _db.select(_db.profiles).get();
    return profiles.isEmpty;
  }

  /// Whether a table name is one this build knows.
  ///
  /// Checked against a fixed list rather than interpolated straight into SQL:
  /// the names all come from [BackupSnapshot.tableOrder], but a table name
  /// reaching a query string unchecked is the kind of thing that stops being
  /// true after a refactor.
  bool _known(String name) => BackupSnapshot.tableOrder.contains(name);

  /// Reads a table as raw SQL values.
  ///
  /// **Below the type converters on purpose.** `Day` is stored as a yyyymmdd
  /// integer and an enum as its name; drift's own `toJson` hands back the Dart
  /// objects, which do not survive a JSON round trip. More importantly, a
  /// converter is a property of *this build* and a backup has to outlive it —
  /// so the mirror holds what SQLite holds, and nothing else.
  Future<List<Map<String, dynamic>>?> _rowsOf(String name) async {
    if (!_known(name)) return null;

    final rows = await _db.customSelect('SELECT * FROM $name').get();
    return [for (final row in rows) Map<String, dynamic>.from(row.data)];
  }

  Future<void> _clear(String name) async {
    if (!_known(name)) return;
    await _db.customStatement('DELETE FROM $name');
  }

  Future<int> _insert(String name, List<Map<String, dynamic>> rows) async {
    if (!_known(name) || rows.isEmpty) return 0;

    var written = 0;
    for (final row in rows) {
      final columns = row.keys.toList();
      if (columns.isEmpty) continue;

      final placeholders = List.filled(columns.length, '?').join(', ');
      final sql =
          'INSERT INTO $name (${columns.join(', ')}) VALUES ($placeholders)';

      try {
        await _db.customInsert(
          sql,
          variables: [
            for (final column in columns) Variable(row[column]),
          ],
        );
        written++;
      } on Object {
        // One unreadable row must not cost the whole restore. A backup written
        // by an older schema can carry a column this build no longer has, and
        // losing a year of history to one bad row would be the worse failure.
        continue;
      }
    }
    return written;
  }
}

import 'dart:convert';

/// Everything the app holds, in one portable object.
///
/// Deliberately a map of table name to rows rather than a typed object per
/// table. Two reasons:
///
/// - A backup has to outlive the schema that wrote it. A typed snapshot would
///   refuse to load the moment a column was added; a map loads what it
///   recognises and leaves the rest.
/// - It is the shape drift already speaks. Every row has `toJson`, so there is
///   no second description of the data to keep in step with the first.
class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.takenAt,
    required this.tables,
  });

  /// Bumped when the *snapshot format* changes, not when the schema does.
  static const int currentVersion = 1;

  /// The tables carried, in the order they must be restored.
  ///
  /// Order matters: `entries` references `foods`, so foods land first. Getting
  /// this wrong produces a foreign-key failure halfway through a restore, with
  /// the database already half-written.
  static const List<String> tableOrder = [
    'profiles',
    'foods',
    'entries',
    'activity_days',
    'weights',
    'water_logs',
    'weeks',
    'achievements',
    'ai_calls',
  ];

  final int version;
  final DateTime takenAt;
  final Map<String, List<Map<String, dynamic>>> tables;

  int get rowCount =>
      tables.values.fold<int>(0, (sum, rows) => sum + rows.length);

  bool get isEmpty => rowCount == 0;

  int rowsIn(String table) => tables[table]?.length ?? 0;

  Map<String, dynamic> toJson() => {
        'version': version,
        'takenAt': takenAt.toIso8601String(),
        'tables': tables,
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Reads a snapshot back, or null if the file is not one.
  ///
  /// Returns null rather than throwing for anything unreadable: a restore
  /// offered against a corrupt file should decline politely, not crash the
  /// screen the user went to in order to recover their data.
  static BackupSnapshot? decode(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;

      final rawTables = decoded['tables'];
      if (rawTables is! Map) return null;

      final tables = <String, List<Map<String, dynamic>>>{};
      rawTables.forEach((key, value) {
        if (key is! String || value is! List) return;
        tables[key] = [
          for (final row in value)
            if (row is Map<String, dynamic>) row,
        ];
      });

      if (tables.isEmpty) return null;

      return BackupSnapshot(
        version: (decoded['version'] as num?)?.toInt() ?? 0,
        takenAt:
            DateTime.tryParse('${decoded['takenAt']}') ?? DateTime(1970),
        tables: tables,
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether this snapshot is one this build knows how to read.
  bool get isReadable => version > 0 && version <= currentVersion;
}

/// Renders a snapshot as something a person can read.
///
/// The JSON is what restores the app; this is what makes the backup folder
/// worth opening. A file you cannot read is a file you never check, and a
/// backup nobody ever checks is a backup nobody finds out is broken.
abstract final class BackupMarkdown {
  static String render(BackupSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln("# The Witcher's Diet — backup")
      ..writeln()
      ..writeln('Taken ${_stamp(snapshot.takenAt)}.')
      ..writeln()
      ..writeln(
        'This file is for reading. `witchers-diet-backup.json` beside it is '
        'the one the app restores from — keep them together.',
      )
      ..writeln()
      ..writeln('## What is here')
      ..writeln()
      ..writeln('| Table | Rows |')
      ..writeln('|---|---|');

    for (final table in BackupSnapshot.tableOrder) {
      buffer.writeln('| $table | ${snapshot.rowsIn(table)} |');
    }

    buffer
      ..writeln()
      ..writeln('**${snapshot.rowCount} rows in total.**')
      ..writeln();

    _profile(buffer, snapshot);
    _weeks(buffer, snapshot);

    return buffer.toString();
  }

  static void _profile(StringBuffer buffer, BackupSnapshot snapshot) {
    final rows = snapshot.tables['profiles'];
    if (rows == null || rows.isEmpty) return;

    final profile = rows.first;
    buffer
      ..writeln('## The character')
      ..writeln()
      ..writeln('- Height: ${profile['heightCm']} cm')
      ..writeln('- Week ends on: ${_weekday(profile['weekEndsOn'])}')
      ..writeln('- Step goal: ${profile['dailyStepGoal']}')
      ..writeln();
  }

  static void _weeks(StringBuffer buffer, BackupSnapshot snapshot) {
    final rows = snapshot.tables['weeks'];
    if (rows == null || rows.isEmpty) return;

    buffer
      ..writeln('## Weeks closed')
      ..writeln()
      ..writeln('| Week beginning | XP | Account |')
      ..writeln('|---|---|---|');

    // Newest first, which is how anyone opening this file will want to read it.
    final sorted = [...rows]..sort(
        (a, b) => '${b['weekStart']}'.compareTo('${a['weekStart']}'),
      );

    for (final week in sorted) {
      final narrative = '${week['narrative'] ?? ''}'
          .replaceAll('\n', ' ')
          // A pipe would break the table it sits in.
          .replaceAll('|', '/');
      buffer.writeln(
        '| ${_day(week['weekStart'])} | ${week['xpAwarded'] ?? 0} | '
        '${narrative.isEmpty ? '—' : narrative} |',
      );
    }

    buffer.writeln();
  }

  /// `yyyymmdd` back into something readable.
  static String _day(Object? value) {
    final raw = '${value ?? ''}';
    if (raw.length != 8) return raw;
    return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6)}';
  }

  static String _stamp(DateTime at) =>
      '${at.year}-${_two(at.month)}-${_two(at.day)} '
      '${_two(at.hour)}:${_two(at.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _weekday(Object? value) => switch (value) {
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        7 => 'Sunday',
        _ => 'unknown',
      };
}

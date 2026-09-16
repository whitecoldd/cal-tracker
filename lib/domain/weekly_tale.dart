/// The week in words — The Tale. Pure Dart.
///
/// Two sources write it and they share one shape, so the reader sees the same
/// document either way:
///
/// - [TaleSource.written] — a model, once, at the moment the week seals. One
///   OpenRouter call per week and never retried (CLAUDE.md §4).
/// - [TaleSource.told] — the app, from its own figures, when there is no key,
///   no network or no allowance left. The app must stay fully usable without
///   AI, so The Tale is never an empty panel.
///
/// The seal is kept in two different places, deliberately:
///
/// - [tellPattern] takes only a [WeekPattern] and its findings, neither of
///   which has a verdict field, so it is safe to call on any day of the week.
/// - [tellVerdict] takes [NarrativeFacts], which cannot be constructed from a
///   week that has not closed. That is the same guard the AI call uses, so the
///   app's own prose and the model's prose are locked by one rule rather than
///   by two that could drift apart.
library;

import 'dart:convert';

import 'week_findings.dart';
import 'week_pattern.dart';
import 'week_summary.dart';

/// One titled passage of the account.
class TaleSection {
  const TaleSection({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}

/// Who wrote the account.
enum TaleSource {
  /// A model wrote it, once, when the week sealed.
  written('Set down at the week’s end.'),

  /// The app wrote it from its own figures.
  told('Written by the app from its own figures. No model was asked.');

  const TaleSource(this.provenance);

  /// Shown in small type under the account. The reader is entitled to know
  /// which of the two they are reading.
  final String provenance;
}

/// The week's account.
class WeeklyTale {
  const WeeklyTale({required this.sections, required this.source});

  final List<TaleSection> sections;
  final TaleSource source;

  bool get isEmpty => sections.isEmpty;

  static String encode(WeeklyTale tale) => jsonEncode({
        'sections': [for (final s in tale.sections) s.toJson()],
      });

  /// Reads whatever is in the `weeks.narrative` column.
  ///
  /// Accepts three shapes, in this order:
  ///
  /// 1. The structured JSON this version writes.
  /// 2. A **plain paragraph**, which is what every week sealed under 1.0.x
  ///    holds, returned as a single section. This is why the richer account
  ///    needs no migration and no new column.
  /// 3. Null or unreadable, returned as null.
  ///
  /// Anything stored was written by a model at the seal, so a successful
  /// decode is always [TaleSource.written].
  static WeeklyTale? decode(String? stored) {
    final raw = stored?.trim();
    if (raw == null || raw.isEmpty) return null;

    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final sections = _sections(decoded['sections']);
          if (sections.isNotEmpty) {
            return WeeklyTale(sections: sections, source: TaleSource.written);
          }
        }
      } on FormatException {
        // Falls through to the plain-text reading below. A stored account is
        // worth showing imperfectly rather than throwing away.
      }
    }

    return WeeklyTale(
      sections: [TaleSection(title: 'The account', body: raw)],
      source: TaleSource.written,
    );
  }

  static List<TaleSection> _sections(Object? value) {
    if (value is! List) return const [];

    return [
      for (final entry in value)
        if (entry is Map<String, dynamic>)
          if ((entry['body'] as String?)?.trim().isNotEmpty ?? false)
            TaleSection(
              title: (entry['title'] as String?)?.trim().isNotEmpty ?? false
                  ? (entry['title']! as String).trim()
                  : 'The account',
              body: (entry['body']! as String).trim(),
            ),
    ];
  }
}

/// The section titles, shared by both sources so the two read as one document.
abstract final class TaleTitles {
  static const opening = 'The opening';
  static const table = 'The table';
  static const curses = 'The curses';
  static const boons = 'The boons';
  static const reckoning = 'The reckoning';
}

/// The descriptive sections, written from the open half alone.
///
/// Safe on any day: a [WeekPattern] has no verdict in it, and nothing here
/// states a quantity of energy or a weight. See `week_findings.dart` for the
/// wording rules, which this file obeys too.
List<TaleSection> tellPattern(WeekPattern pattern, List<Finding> findings) {
  if (pattern.loggedDays == 0) {
    return const [
      TaleSection(
        title: TaleTitles.opening,
        body: 'Nothing was written down this week. There is no account to '
            'give of a week that left no record.',
      ),
    ];
  }

  return [
    TaleSection(title: TaleTitles.opening, body: _opening(pattern)),
    TaleSection(title: TaleTitles.table, body: _table(pattern)),
    if (topFindings(findings, Tone.warning).isNotEmpty)
      TaleSection(
        title: TaleTitles.curses,
        body: _findings(topFindings(findings, Tone.warning)),
      ),
    if (topFindings(findings, Tone.boon).isNotEmpty)
      TaleSection(
        title: TaleTitles.boons,
        body: _findings(topFindings(findings, Tone.boon)),
      ),
  ];
}

/// The verdict passage.
///
/// Takes [NarrativeFacts] and nothing else, so it cannot be called about a
/// week that has not closed — the type's own `from` returns null until then.
TaleSection tellVerdict(NarrativeFacts facts) {
  final buffer = StringBuffer();

  final balance = facts.energyBalanceKcal.round();
  final daily = facts.averageDailyBalanceKcal.round();

  buffer.write(
    balance < 0
        ? 'Across ${facts.loggedDays} logged days the ledger came out '
            '${balance.abs()} kcal short, about ${daily.abs()} a day. '
        : 'Across ${facts.loggedDays} logged days the ledger came out '
            '$balance kcal over, about $daily a day. ',
  );

  final delta = facts.weightDeltaKg;
  final trend = facts.trend;

  if (delta == null || trend == null) {
    buffer.write(
      'There were not enough weigh-ins to say what the scale did about it.',
    );
  } else {
    buffer.write(
      'The scale read ${delta >= 0 ? '+' : ''}'
      '${delta.toStringAsFixed(2)} kg — ${trend.label.toLowerCase()}. '
      'The ledger predicted '
      '${facts.projectedChangeKg >= 0 ? '+' : ''}'
      '${facts.projectedChangeKg.toStringAsFixed(2)} kg; the gap between the '
      'two is mostly water.',
    );
  }

  return TaleSection(
    title: TaleTitles.reckoning,
    body: buffer.toString().trim(),
  );
}

/// The whole account, told by the app.
///
/// [facts] is null on any day but the reveal, and its absence is what leaves
/// the verdict passage out.
WeeklyTale tellWeek(
  WeekPattern pattern,
  List<Finding> findings, {
  NarrativeFacts? facts,
}) =>
    WeeklyTale(
      sections: [
        ...tellPattern(pattern, findings),
        if (facts != null) tellVerdict(facts),
      ],
      source: TaleSource.told,
    );

// --- the app's own prose ---

String _opening(WeekPattern pattern) {
  final logged = pattern.loggedDays;
  final window = pattern.isPartial
      ? 'so far this week'
      : 'across the week';

  final written = switch (logged) {
    7 => 'Every day of it was written down',
    >= 5 => '$logged of the seven days were written down',
    >= 3 => 'Only $logged days were written down, so this is a partial account',
    _ => 'Just $logged '
        '${logged == 1 ? 'day was' : 'days were'} written down, and very '
        'little rests on that',
  };

  final vitality = pattern.quality.meanVitality.round();

  return '$written. What was eaten $window scored $vitality out of a hundred '
      'for what it was made of.';
}

String _table(WeekPattern pattern) {
  final buffer = StringBuffer();

  final macros = pattern.macros;
  if (macros.isNotEmpty) {
    buffer.write('By energy the week came out ');
    buffer.write(
      macros
          .map((m) => '${(m.share * 100).round()}% ${m.label.toLowerCase()}')
          .join(', '),
    );
    buffer.write('. ');
  }

  buffer.write(
    'Fibre averaged '
    '${pattern.quality.meanFibrePer1000Kcal.toStringAsFixed(1)} g per 1000 '
    'kcal. ',
  );

  final whole = (pattern.quality.wholeFoodShare * 100).round();
  final ultra = (pattern.quality.ultraProcessedShare * 100).round();
  buffer.write(
    '$whole% of the energy came from whole or barely processed food, and '
    '$ultra% from ultra-processed. ',
  );

  final additives = pattern.additiveCount;
  if (additives > 0) {
    final named = pattern.additives.take(3).map((a) => a.code).join(', ');
    buffer.write(
      '$additives distinct ${additives == 1 ? 'additive was' : 'additives '
          'were'} listed across everything eaten'
      '${named.isEmpty ? '' : ' — $named among them'}.',
    );
  } else {
    buffer.write('Nothing eaten this week listed an additive.');
  }

  return buffer.toString().trim();
}

String _findings(List<Finding> findings) => findings
    .map((f) => '${f.title}: ${_unpunctuated(f.detail)}.')
    .join(' ');

String _unpunctuated(String detail) {
  final trimmed = detail.trim();
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

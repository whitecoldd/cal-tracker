import 'dart:convert';

import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/data/week_archive.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_openrouter.dart';

const _monday = Day(20260914);
const _sunday = Day(20260920);

Reckoning _reckoningOn(Day today) => reckon(
      anyDayOfWeek: today,
      today: today,
      gate: const RevealGate(weekEndsOn: DateTime.sunday),
      days: [
        for (var i = 0; i < 7; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 1800,
            expenditureKcal: 2400,
          ),
      ],
      startWeightKg: 82,
      endWeightKg: 81.1,
      heightCm: 180,
      ageYears: 34,
      sex: Sex.male,
    );

const _summary = WeekSummary(
  loggedDays: 7,
  energyBalanceKcal: -4200,
  averageDailyBalanceKcal: -600,
  projectedChangeKg: -0.55,
  averageVitality: 68,
  averageToxicity: 31,
  steps: 58000,
  goalDays: 4,
  xp: 145,
  weightDeltaKg: -0.9,
  trend: WeightTrend.falling,
);

String _narrativeReply(String text) => jsonEncode({
      'choices': [
        {
          'message': {'content': jsonEncode({'text': text})},
        },
      ],
      'usage': {'prompt_tokens': 200, 'completion_tokens': 60},
    });

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ({WeekArchive archive, FakeOpenRouterAdapter adapter}) build({
    List<FakeReply>? replies,
    String? key = 'sk-or-v1-testtesttesttesttest',
  }) {
    final adapter = FakeOpenRouterAdapter(
      replies ?? [FakeReply.ok(_narrativeReply('The week was long.'))],
    );
    final dio = Dio()..httpClientAdapter = adapter;

    return (
      archive: WeekArchive(
        weeks: db.weeksDao,
        ai: OpenRouterClient(
          keys: InMemoryAiKeyStore(key: key),
          calls: db.aiCallsDao,
          dio: dio,
        ),
      ),
      adapter: adapter,
    );
  }

  NarrativeFacts factsFor(Reckoning reckoning) => NarrativeFacts.from(
        reckoning,
        averageVitality: 68,
        steps: 58000,
      )!;

  group('sealing a week', () {
    test('writes the summary and asks for one narrative', () async {
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      final sealed = await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      expect(sealed!.narrative, 'The week was long.');
      expect(sealed.summary.energyBalanceKcal, -4200);
      expect(built.adapter.callCount, 1);
    });

    test('records the XP it awarded', () async {
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      final row = await db.weeksDao.forWeekStart(_monday);
      expect(row!.xpAwarded, 145);
      expect(row.revealed, isTrue);
    });

    test('refuses to seal a week that has not closed', () async {
      final built = build();

      final sealed = await built.archive.seal(
        reckoning: _reckoningOn(_monday),
        summary: _summary,
      );

      expect(sealed, isNull);
      expect(await db.weeksDao.forWeekStart(_monday), isNull);
      expect(built.adapter.callCount, 0);
    });
  });

  group('a sealed week is history', () {
    test('is never recomputed', () async {
      // Later changes to the scoring maths must not rewrite what the user was
      // already told. A history that edits itself is not a history.
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      // A second seal with different figures must change nothing.
      const rewritten = WeekSummary(
        loggedDays: 1,
        energyBalanceKcal: 9999,
        averageDailyBalanceKcal: 9999,
        projectedChangeKg: 9,
        averageVitality: 0,
        averageToxicity: 100,
        steps: 0,
        goalDays: 0,
        xp: 0,
      );

      final again = await built.archive.seal(
        reckoning: reckoning,
        summary: rewritten,
        facts: factsFor(reckoning),
      );

      expect(again!.summary.energyBalanceKcal, -4200);
      expect(again.summary.xp, 145);
    });

    test('the narrative costs exactly one call, once', () async {
      // The fourth permitted use and its entire budget: one per week. Not on a
      // re-open, not after a restart.
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );
      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );
      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      expect(built.adapter.callCount, 1);
      expect(await db.aiCallsDao.usedToday(), 1);
    });

    test('reads back after a restart', () async {
      final first = build();
      final reckoning = _reckoningOn(_sunday);

      await first.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      // A fresh archive over the same database, as if the app were reopened.
      final second = build(replies: []);
      final read = await second.archive.read(_monday);

      expect(read!.summary.energyBalanceKcal, -4200);
      expect(read.narrative, 'The week was long.');
      expect(second.adapter.callCount, 0);
    });

    test('an unsealed week reads as absent', () async {
      expect(await build(replies: []).archive.read(_monday), isNull);
    });
  });

  group('when the narrative cannot be had', () {
    test('the week still seals with all its figures', () async {
      // The account is flavour on top of the numbers. Refusing to seal because
      // a model was unreachable would lose the numbers to save the prose.
      final built = build(key: null);
      final reckoning = _reckoningOn(_sunday);

      final sealed = await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      expect(sealed, isNotNull);
      expect(sealed!.narrative, isNull);
      expect(sealed.summary.energyBalanceKcal, -4200);
    });

    test('a failing model does not block the seal', () async {
      final built = build(replies: [
        const FakeReply.status(500),
        const FakeReply.status(500),
        const FakeReply.status(500),
      ]);
      final reckoning = _reckoningOn(_sunday);

      final sealed = await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      expect(sealed!.narrative, isNull);
      expect(sealed.summary.xp, 145);
    });

    test('a week sealed without a narrative is not retried', () async {
      // Otherwise every re-open of a week that failed once would spend another
      // request, which is exactly how a fifty-a-day budget disappears.
      final failing = build(replies: [
        const FakeReply.status(500),
        const FakeReply.status(500),
        const FakeReply.status(500),
      ]);
      final reckoning = _reckoningOn(_sunday);

      await failing.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      final later = build();
      await later.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      expect(later.adapter.callCount, 0);
    });

    test('no facts means no call at all', () async {
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      final sealed = await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
      );

      expect(sealed!.narrative, isNull);
      expect(built.adapter.callCount, 0);
    });
  });

  group('the narrative request', () {
    test('is the only one carrying verdict data, and says the week closed',
        () async {
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final system = (messages.first as Map)['content'] as String;
      final user = (messages.last as Map)['content'] as String;

      expect(system.toLowerCase(), contains('the week has closed'));
      // The exception is visible in the prompt itself, not only in the code.
      expect(user, contains('Energy balance'));
      expect(user, contains('Measured weight change'));
    });

    test('is attributed to the weekly purpose', () async {
      final built = build();
      final reckoning = _reckoningOn(_sunday);

      await built.archive.seal(
        reckoning: reckoning,
        summary: _summary,
        facts: factsFor(reckoning),
      );

      final calls = await db.aiCallsDao.select(db.aiCalls).get();
      expect(calls.single.purpose, AiPurpose.weeklyNarrative);
    });
  });
}

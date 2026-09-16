import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../domain/day.dart';
import '../database.dart';
import '../tables.dart';

part 'ai_calls_dao.g.dart';

/// How much of the OpenRouter free tier is left right now.
class AiBudget {
  const AiBudget({
    required this.usedToday,
    required this.dailyLimit,
    required this.usedLastMinute,
    required this.perMinuteLimit,
  });

  final int usedToday;
  final int dailyLimit;
  final int usedLastMinute;
  final int perMinuteLimit;

  /// Whether this is the raised cap that credit buys.
  ///
  /// Read from the limit rather than stored a second time, so the badge on
  /// Settings and the number beside it can never disagree.
  bool get onPaidTier => dailyLimit >= AiCallsDao.paidDailyLimit;

  int get remainingToday => (dailyLimit - usedToday).clamp(0, dailyLimit);
  bool get dailyExhausted => usedToday >= dailyLimit;
  bool get rateLimited => usedLastMinute >= perMinuteLimit;

  /// Whether another call may be made at all.
  bool get canCall => !dailyExhausted && !rateLimited;
}

/// Audit trail for AI calls, and the budget counter built on it.
///
/// OpenRouter's free tier allows 20 requests a minute and 50 a day at a zero
/// balance (1,000 after a one-time purchase). Those limits are low enough that
/// hitting one has to be something the app can see coming, not a surprise
/// failure mid-meal.
@DriftAccessor(tables: [AiCalls])
class AiCallsDao extends DatabaseAccessor<AppDatabase> with _$AiCallsDaoMixin {
  AiCallsDao(super.db);

  /// Requests per day on a zero balance. Raised to 1,000 by a $10 purchase.
  static const int freeDailyLimit = 50;
  static const int paidDailyLimit = 1000;
  static const int perMinuteLimit = 20;

  Future<void> record({
    required String model,
    required AiPurpose purpose,
    required bool succeeded,
    int? promptTokens,
    int? completionTokens,
    String? error,
  }) async {
    final now = clock.now();
    await into(aiCalls).insert(
      AiCallsCompanion.insert(
        day: Day.from(now),
        at: now.toIso8601String(),
        model: model,
        purpose: purpose,
        succeeded: succeeded,
        promptTokens: Value(promptTokens),
        completionTokens: Value(completionTokens),
        error: Value(error),
      ),
    );
  }

  /// Calls made today, successful or not.
  ///
  /// Failed calls count: OpenRouter charges the rate limit against the request,
  /// not against the result.
  Future<int> usedToday() async {
    final today = Day.today();
    final row = await (selectOnly(aiCalls)
          ..addColumns([aiCalls.id.count()])
          ..where(aiCalls.day.equals(today.value)))
        .getSingle();
    return row.read(aiCalls.id.count()) ?? 0;
  }

  Future<int> usedLastMinute() async {
    final cutoff = clock.now().subtract(const Duration(minutes: 1));
    final row = await (selectOnly(aiCalls)
          ..addColumns([aiCalls.id.count()])
          ..where(aiCalls.at.isBiggerThanValue(cutoff.toIso8601String())))
        .getSingle();
    return row.read(aiCalls.id.count()) ?? 0;
  }

  Future<AiBudget> budget({bool hasPurchasedCredit = false}) async {
    return AiBudget(
      usedToday: await usedToday(),
      dailyLimit: hasPurchasedCredit ? paidDailyLimit : freeDailyLimit,
      usedLastMinute: await usedLastMinute(),
      perMinuteLimit: perMinuteLimit,
    );
  }

  /// Drops call records older than [keepDays]. The audit trail is for the
  /// budget, not for history.
  Future<int> prune({int keepDays = 30}) {
    final cutoff = Day.today().addDays(-keepDays);
    return (delete(aiCalls)..where((c) => c.day.isSmallerThanValue(cutoff.value)))
        .go();
  }
}

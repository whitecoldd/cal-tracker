import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/signs.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/witcher_button.dart';
import 'journal_providers.dart';
import 'water_providers.dart';

/// What was drunk, on the Journal.
///
/// Plain figures, and safe to show plainly: hydration is a fact about intake,
/// not a verdict about a body, so nothing here is sealed. See CLAUDE.md §1.
///
/// Note what this panel does *not* say. The bar reads "1,500 of 2,000 ml" and
/// never "1500 / 2000": an `x / y` ring is the progress framing the whole app
/// refuses, and there is a test on the Journal that fails if a slash appears.
class WaterPanel extends ConsumerStatefulWidget {
  const WaterPanel({super.key});

  @override
  ConsumerState<WaterPanel> createState() => _WaterPanelState();
}

class _WaterPanelState extends ConsumerState<WaterPanel> {
  /// The last amount added, so the minus button undoes exactly that.
  ///
  /// `water_logs` holds one total per day, not a list of sips — so there is no
  /// log to undo and this is a *decrement*. Remembering the last add makes the
  /// immediate undo exact; after a rebuild it falls back to the smaller step.
  /// Anything better needs a per-sip table, which is not worth a schema version.
  int? _lastAdd;

  Future<void> _change(int delta) async {
    final day = ref.read(journalDayProvider);
    final current = ref.read(hydrationProvider).loggedMl;
    final next = (current + delta).clamp(0, 100000);
    if (next == current) return;

    setState(() => _lastAdd = delta > 0 ? delta : null);

    await ref.read(databaseProvider).trackingDao.upsertWater(
          WaterLogsCompanion(
            day: Value(day),
            ml: Value(next),
            updatedAt: Value(clock.now().toIso8601String()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final hydration = ref.watch(hydrationProvider);
    final step = _lastAdd ?? 250;

    return OrnatePanel(
      title: 'The waterskin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatBar(
            label: 'Yrden',
            value: hydration.totalMl.toDouble(),
            max: waterTargetMl.toDouble(),
            color: Hue.water,
            valueLabel: '${_grouped(hydration.totalMl)} of '
                '${_grouped(waterTargetMl)} ml',
          ),
          if (hydration.fromDrinksMl > 0) ...[
            const SizedBox(height: Space.xs),
            Text(
              '${_grouped(hydration.fromDrinksMl)} ml of that came from what '
              'you logged.',
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: WitcherButton(
                  label: '+250',
                  onPressed: () => _change(250),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: WitcherButton(
                  label: '+500',
                  onPressed: () => _change(500),
                ),
              ),
              const SizedBox(width: Space.sm),
              // Wide enough for "−1000". At 56 the label ellipsised to "−...",
              // which is the one thing a button showing an amount must not do.
              SizedBox(
                width: 88,
                child: WitcherButton(
                  label: '−$step',
                  onPressed:
                      hydration.loggedMl == 0 ? null : () => _change(-step),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Yrden asks for two litres. Lore, not a physician.',
            style: Type.lore(size: 10, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// Thousands separator. `intl` would localise the separator, and every other
/// figure in this app is grouped the same way by hand.
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

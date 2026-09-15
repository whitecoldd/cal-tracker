import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/stat_bar.dart';
import '../journal/journal_providers.dart';
import 'activity_providers.dart';
import 'manual_steps_sheet.dart';

/// The day's movement, on the Journal.
///
/// Steps, distance and Stamina only. The stored row also holds active energy,
/// and this panel is never given it: expenditure is a term of the verdict, and
/// a screen that showed "420 kcal burned" beside the day's intake would let
/// the two be subtracted. See CLAUDE.md §1 — the guard is [ActivityView],
/// which has nowhere to put the figure.
class ActivityPanel extends ConsumerWidget {
  const ActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dayActivityProvider);
    final isManual = ref.watch(dayActivityIsManualProvider).valueOrNull ?? false;
    final day = ref.watch(journalDayProvider);

    return OrnatePanel(
      title: 'The road',
      trailing: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        tooltip: 'Enter steps by hand',
        icon: const Icon(Icons.edit_outlined, size: 15),
        color: Hue.parchmentDim,
        onPressed: () => ManualStepsSheet.show(context, day: day),
      ),
      child: switch (activity) {
        AsyncData(:final value) => _Body(view: value, isManual: isManual),
        AsyncError() => Text(
            'Movement could not be read.',
            style: Type.lore(size: 12),
          ),
        _ => const SizedBox(height: 56),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view, required this.isManual});

  final ActivityView view;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    if (view.steps == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No movement recorded for this day.',
            style: Type.lore(size: 12),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Connect Health Connect in Settings, or tap the pen to enter it.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STEPS', style: Type.label()),
                  Text(
                    _grouped(view.steps),
                    style: Type.numeral(size: 26),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('DISTANCE', style: Type.label()),
                Text(
                  '${view.distanceKm.toStringAsFixed(1)} km',
                  style: Type.numeral(size: 20),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        StatBar(
          label: 'Stamina',
          value: view.stamina,
          color: Hue.stamina,
          valueLabel: '${_grouped(view.steps)} of ${_grouped(view.stepGoal)}',
        ),
        if (isManual) ...[
          const SizedBox(height: Space.sm),
          Row(
            children: [
              const Icon(Icons.edit_outlined, size: 12, color: Hue.goldDim),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  'Entered by hand. A sync will not overwrite it.',
                  style: Type.lore(size: 11, color: Hue.goldDim),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Thousands separator, because a five-digit step count is unreadable
  /// without one.
  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

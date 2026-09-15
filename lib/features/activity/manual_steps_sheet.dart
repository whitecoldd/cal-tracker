import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/day.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/witcher_button.dart';
import 'activity_providers.dart';

/// Type a step count for a day.
///
/// The override exists because step counters are wrong in ordinary ways — a
/// phone left on a desk, a walk with the phone in a bag. Once typed, the
/// figure is permanent for that day: a later Health Connect sync will not
/// replace it, which is the whole point of having typed it.
class ManualStepsSheet extends ConsumerStatefulWidget {
  const ManualStepsSheet({required this.day, super.key});

  final Day day;

  static Future<void> show(BuildContext context, {required Day day}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualStepsSheet(day: day),
    );
  }

  @override
  ConsumerState<ManualStepsSheet> createState() => _ManualStepsSheetState();
}

class _ManualStepsSheetState extends ConsumerState<ManualStepsSheet> {
  final _steps = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = int.tryParse(_steps.text.trim());
    if (steps == null || steps < 0) return;

    setState(() => _saving = true);

    final profile = ref.read(profileProvider).valueOrNull;
    await ref.read(activitySyncProvider).recordManual(
          day: widget.day,
          steps: steps,
          // Distance comes from the user's own stride, measured at character
          // creation. People know roughly how many steps they took and never
          // how many metres.
          strideCm: profile?.strideCm ?? 74,
        );

    ref.read(activityTickProvider.notifier).changed();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Space.huge,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ColoredBox(
        color: Hue.voidBlack,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('STEPS TAKEN', style: Type.heading(size: 16)),
              const SizedBox(height: Space.sm),
              Text(
                'What the counter missed, or what it invented. Distance is '
                'worked out from your stride.',
                style: Type.lore(size: 12),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _steps,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Type.numeral(size: 22),
                cursorColor: Hue.gold,
                decoration: const InputDecoration(hintText: '8000'),
              ),
              const SizedBox(height: Space.lg),
              WitcherButton(
                label: 'Write it down',
                tone: ButtonTone.primary,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: Space.sm),
              Text(
                'A typed figure stays. Health Connect will not overwrite it.',
                style: Type.lore(size: 11, color: Hue.parchmentFaint),
              ),
              const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ),
    );
  }
}

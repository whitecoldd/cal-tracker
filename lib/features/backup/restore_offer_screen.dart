import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/snapshot.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';
import 'backup_providers.dart';

/// Offered on a fresh install when a backup is sitting in the folder.
///
/// This is the moment the whole archive exists for: the app has been
/// reinstalled, the database is empty, and a year of logging is one tap away.
/// Getting the user past onboarding first and *then* mentioning it would mean
/// restoring over a profile they had just finished typing.
class RestoreOfferScreen extends ConsumerStatefulWidget {
  const RestoreOfferScreen({
    required this.found,
    required this.onDecline,
    super.key,
  });

  final BackupSnapshot found;

  /// Carry on to onboarding without restoring.
  final VoidCallback onDecline;

  @override
  ConsumerState<RestoreOfferScreen> createState() =>
      _RestoreOfferScreenState();
}

class _RestoreOfferScreenState extends ConsumerState<RestoreOfferScreen> {
  bool _working = false;
  String? _failure;

  Future<void> _restore() async {
    setState(() {
      _working = true;
      _failure = null;
    });

    final result = await ref.read(backupServiceProvider).restoreFromMirror();
    ref.read(backupTickProvider.notifier).changed();

    if (!mounted) return;

    if (result.ok) {
      // The profile stream will now deliver, and the gate routes onward on its
      // own — there is nothing to navigate to from here.
      ref.invalidate(isFreshInstallProvider);
      return;
    }

    setState(() {
      _working = false;
      _failure = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.found;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: OrnatePanel(
              title: 'A record was found',
              accent: Hue.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'There is a backup in your documents folder, written '
                    '${_stamp(found.takenAt)}.',
                    style: Type.prose(size: 14),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    '${found.rowCount} rows — '
                    '${found.rowsIn('entries')} logged meals, '
                    '${found.rowsIn('weights')} weigh-ins, '
                    '${found.rowsIn('weeks')} closed weeks.',
                    style: Type.lore(size: 12),
                  ),
                  const RunicDivider(),
                  WitcherButton(
                    label: _working ? 'Restoring…' : 'Take up the old record',
                    tone: ButtonTone.primary,
                    onPressed: _working ? null : _restore,
                  ),
                  const SizedBox(height: Space.sm),
                  WitcherButton(
                    label: 'Begin anew',
                    onPressed: _working ? null : widget.onDecline,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Beginning anew leaves the backup untouched. Nothing is '
                    'overwritten until the app next writes one.',
                    style: Type.lore(size: 11, color: Hue.parchmentFaint),
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: Space.md),
                    Text(
                      _failure!,
                      style: Type.prose(size: 12, color: Hue.bloodRed),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}';
  }
}

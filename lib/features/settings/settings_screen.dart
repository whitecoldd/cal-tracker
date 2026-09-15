import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai/ai_key_store.dart';
import '../../data/daos/ai_calls_dao.dart';
import '../../data/health/activity_sync.dart';
import '../../data/health/step_reader.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/witcher_button.dart';
import '../activity/activity_providers.dart';
import '../ai/ai_providers.dart';
import '../backup/backup_providers.dart';

/// Settings — the AI key, the daily allowance, Health Connect, the archive.
///
/// The key is typed here and nowhere else. It goes straight into the Android
/// keystore: never into the repo, never into a `--dart-define`, which would
/// bake it into the APK. See CLAUDE.md §2 and §4.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();

    if (!looksLikeOpenRouterKey(value)) {
      // A shape check, not a network check: verifying against OpenRouter would
      // spend one of fifty daily requests to learn something a prefix reveals.
      setState(() => _error = 'That does not look like an OpenRouter key. '
          'They begin with "sk-or-".');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await ref.read(aiKeyStoreProvider).write(value);
    _controller.clear();
    ref.read(aiCallTickProvider.notifier).spent();

    if (mounted) setState(() => _saving = false);
  }

  Future<void> _forget() async {
    await ref.read(aiKeyStoreProvider).clear();
    ref.read(aiCallTickProvider.notifier).spent();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(aiAvailableProvider);
    final budget = ref.watch(aiBudgetProvider);

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        OrnatePanel(
          title: 'The Oracle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'An OpenRouter key lets the app read a typed meal and guess at '
                'vague portions. Everything else works without one.',
                style: Type.lore(size: 12),
              ),
              const SizedBox(height: Space.md),
              if (available.valueOrNull ?? false)
                _KeyPresent(onForget: _saving ? null : _forget)
              else
                _KeyEntry(
                  controller: _controller,
                  error: _error,
                  onSave: _saving ? null : _save,
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        _Budget(budget: budget),
        const SizedBox(height: Space.lg),
        const _Health(),
        const SizedBox(height: Space.lg),
        const _Backup(),
      ],
    );
  }
}

/// Health Connect: whether it is reachable, and the way in.
///
/// Permission is requested by the `health` plugin itself — there is no
/// `permission_handler` in this project, and `MainActivity` extends
/// `FlutterFragmentActivity` so the plugin can run its permission contract.
/// See CLAUDE.md §3.
class _Health extends ConsumerStatefulWidget {
  const _Health();

  @override
  ConsumerState<_Health> createState() => _HealthState();
}

class _HealthState extends ConsumerState<_Health> {
  bool _working = false;
  String? _outcome;

  Future<void> _connect() async {
    setState(() {
      _working = true;
      _outcome = null;
    });

    final result = await ref.read(activitySyncProvider).connect();
    ref.read(activityTickProvider.notifier).changed();

    if (!mounted) return;
    setState(() {
      _working = false;
      _outcome = switch (result) {
        SyncResult(availability: HealthAvailability.notInstalled) =>
          'Health Connect is not installed on this phone.',
        SyncResult(availability: HealthAvailability.needsUpdate) =>
          'Health Connect needs updating before it can be read.',
        SyncResult(availability: HealthAvailability.unsupported) =>
          'This device cannot read movement data.',
        SyncResult(granted: false) =>
          'Permission was not given. Steps can still be entered by hand.',
        SyncResult(:final daysWritten, :final daysKept) =>
          'Read $daysWritten ${daysWritten == 1 ? "day" : "days"}'
              '${daysKept > 0 ? ", left $daysKept you had typed" : ""}.',
      };
    });
  }

  Future<void> _install() async {
    await ref.read(stepReaderProvider).promptInstall();
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(healthAvailabilityProvider).valueOrNull;
    final permitted = ref.watch(healthPermissionProvider).valueOrNull ?? false;

    return OrnatePanel(
      title: 'The Path walked',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Health Connect supplies steps and distance, including for days '
            'the app was never opened. Without it, steps can be typed in the '
            'Journal.',
            style: Type.lore(size: 12),
          ),
          const SizedBox(height: Space.md),
          if (availability == HealthAvailability.notInstalled) ...[
            Text(
              'Health Connect is not installed.',
              style: Type.prose(size: 13, color: Hue.adrenaline),
            ),
            const SizedBox(height: Space.sm),
            WitcherButton(
              label: 'Install Health Connect',
              onPressed: _working ? null : _install,
            ),
          ] else if (permitted) ...[
            Row(
              children: [
                const Icon(Icons.check, size: 16, color: Hue.toxicity),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text('Connected.', style: Type.prose(size: 14)),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            WitcherButton(
              label: _working ? 'Reading…' : 'Read the last week',
              onPressed: _working ? null : _connect,
            ),
          ] else
            WitcherButton(
              label: _working ? 'Asking…' : 'Connect Health Connect',
              tone: ButtonTone.primary,
              onPressed: _working ? null : _connect,
            ),
          if (_outcome != null) ...[
            const SizedBox(height: Space.sm),
            Text(_outcome!, style: Type.lore(size: 12)),
          ],
          const SizedBox(height: Space.sm),
          // The app reads movement and never writes any. Worth saying on the
          // screen that asks for the permission.
          Text(
            'Read only. Nothing is ever written back to Health Connect.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// The backup mirror: the folder, the files, and the way back.
///
/// Layer two of "survives reinstall" (CLAUDE.md / [[02-Architecture]]). Android
/// Auto Backup is layer one and is invisible; this is the one the user can
/// open, read, and copy off the phone.
class _Backup extends ConsumerStatefulWidget {
  const _Backup();

  @override
  ConsumerState<_Backup> createState() => _BackupState();
}

class _BackupState extends ConsumerState<_Backup> with WidgetsBindingObserver {
  bool _working = false;
  String? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android gives no callback when the user grants all-files access — they
    // leave for Settings and may never come back. Re-checking on resume is the
    // only way to notice.
    if (state == AppLifecycleState.resumed) {
      ref.read(backupTickProvider.notifier).changed();
    }
  }

  Future<void> _grant() async {
    await ref.read(storageAccessProvider).requestAccess();
  }

  Future<void> _write() async {
    setState(() {
      _working = true;
      _outcome = null;
    });

    final result = await ref.read(backupServiceProvider).writeMirror();
    ref.read(backupTickProvider.notifier).changed();

    if (mounted) {
      setState(() {
        _working = false;
        _outcome = result.message;
      });
    }
  }

  Future<void> _restore() async {
    // A restore replaces everything. Asked for explicitly, every time — this
    // is the one button in the app that can destroy a year of logging.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Hue.surface,
        title: Text('Restore from the folder?', style: Type.heading(size: 16)),
        content: Text(
          'Everything currently in the app is replaced by what is in the '
          'backup. This cannot be undone.',
          style: Type.prose(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep what I have', style: Type.label()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Restore', style: Type.label(color: Hue.vitality)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _working = true;
      _outcome = null;
    });

    final result = await ref.read(backupServiceProvider).restoreFromMirror();
    ref.read(backupTickProvider.notifier).changed();

    if (mounted) {
      setState(() {
        _working = false;
        _outcome = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = ref.watch(storageGrantedProvider).valueOrNull ?? false;
    final existing = ref.watch(existingBackupProvider).valueOrNull;
    final service = ref.watch(backupServiceProvider);

    return OrnatePanel(
      title: 'The archive',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A copy of everything, written where you can reach it with a file '
            'manager or a cable. It survives the app being uninstalled.',
            style: Type.lore(size: 12),
          ),
          const SizedBox(height: Space.sm),
          Text(
            service.directory,
            style: Type.prose(size: 11, color: Hue.parchmentFaint),
          ),
          const SizedBox(height: Space.md),
          if (!granted) ...[
            Text(
              'Android needs to be told this app may write there.',
              style: Type.prose(size: 13, color: Hue.adrenaline),
            ),
            const SizedBox(height: Space.sm),
            WitcherButton(
              label: 'Grant file access',
              tone: ButtonTone.primary,
              onPressed: _working ? null : _grant,
            ),
          ] else ...[
            WitcherButton(
              label: _working ? 'Writing…' : 'Write a backup now',
              tone: ButtonTone.primary,
              onPressed: _working ? null : _write,
            ),
            const SizedBox(height: Space.sm),
            WitcherButton(
              label: 'Restore from the folder',
              tone: ButtonTone.danger,
              onPressed: _working || existing == null ? null : _restore,
            ),
          ],
          if (existing != null) ...[
            const RunicDivider(),
            Text(
              'A backup from ${_stamp(existing.takenAt)} is sitting there, '
              'holding ${existing.rowCount} rows.',
              style: Type.lore(size: 12),
            ),
          ] else if (granted) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Nothing written yet.',
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
          if (_outcome != null) ...[
            const SizedBox(height: Space.sm),
            Text(_outcome!, style: Type.prose(size: 12)),
          ],
        ],
      ),
    );
  }

  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _KeyEntry extends StatelessWidget {
  const _KeyEntry({
    required this.controller,
    required this.error,
    required this.onSave,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          // Obscured: a key is a credential, and this screen is as likely to
          // be open in a room with other people as anywhere else.
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: Type.prose(size: 14),
          cursorColor: Hue.gold,
          decoration: const InputDecoration(
            hintText: 'sk-or-v1-...',
            prefixIcon: Icon(Icons.vpn_key_outlined, color: Hue.parchmentDim),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: Space.sm),
          Text(error!, style: Type.lore(size: 12, color: Hue.bloodRed)),
        ],
        const SizedBox(height: Space.md),
        WitcherButton(
          label: 'Bind the key',
          onPressed: onSave,
          tone: ButtonTone.primary,
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Stored in the Android keystore on this device only. It is never '
          'written to the project and never leaves the phone except to '
          'OpenRouter.',
          style: Type.lore(size: 11, color: Hue.parchmentFaint),
        ),
      ],
    );
  }
}

class _KeyPresent extends StatelessWidget {
  const _KeyPresent({required this.onForget});

  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check, size: 16, color: Hue.toxicity),
            const SizedBox(width: Space.sm),
            // Deliberately not shown, not even masked with a few characters
            // revealed: there is nothing to check by eye, and every rendering
            // of a credential is a chance to leak it into a screenshot.
            Expanded(
              child: Text('A key is bound.', style: Type.prose(size: 14)),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        WitcherButton(
          label: 'Forget it',
          onPressed: onForget,
          tone: ButtonTone.danger,
        ),
      ],
    );
  }
}

class _Budget extends StatelessWidget {
  const _Budget({required this.budget});

  final AsyncValue<AiBudget> budget;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: "Today's allowance",
      child: switch (budget) {
        AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatBar(
                label: 'Requests',
                value: value.usedToday.toDouble(),
                max: value.dailyLimit.toDouble(),
                color: value.dailyExhausted ? Hue.bloodRed : Hue.gold,
                valueLabel: '${value.usedToday} of ${value.dailyLimit}',
              ),
              const RunicDivider(),
              Text(
                value.dailyExhausted
                    ? 'Spent for today. The app works as it always does; only '
                        'the typed-meal reading rests until tomorrow.'
                    : '${value.remainingToday} left today. Every food read '
                        'once is remembered, so the same meal never costs a '
                        'second request.',
                style: Type.lore(size: 12),
              ),
              if (value.rateLimited) ...[
                const SizedBox(height: Space.sm),
                Text(
                  'More than ${value.perMinuteLimit} requests in the last '
                  'minute. Wait a moment.',
                  style: Type.lore(size: 12, color: Hue.adrenaline),
                ),
              ],
            ],
          ),
        AsyncError(:final error) =>
          Text('$error', style: Type.lore(size: 12, color: Hue.bloodRed)),
        _ => const SizedBox(height: 40),
      },
    );
  }
}

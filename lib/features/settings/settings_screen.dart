import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai/ai_key_store.dart';
import '../../data/daos/ai_calls_dao.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/witcher_button.dart';
import '../ai/ai_providers.dart';

/// Settings — for now, the AI key and what is left of today's budget.
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
      ],
    );
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

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai/meal_resolver.dart';
import '../../data/ai/openrouter_client.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/witcher_button.dart';
import '../ai/ai_providers.dart';
import 'meal_confirm.dart';

/// Log a meal by describing it.
///
/// One AI call for the whole line, however many foods it names — which is the
/// only reason this is affordable on fifty requests a day. Everything it finds
/// is written into the library, so the same breakfast never costs a second
/// call. See CLAUDE.md §4.
class SpeakMealSheet extends ConsumerStatefulWidget {
  const SpeakMealSheet({required this.day, this.slot, super.key});

  final Day day;
  final MealSlot? slot;

  static Future<bool> show(
    BuildContext context, {
    required Day day,
    MealSlot? slot,
  }) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpeakMealSheet(day: day, slot: slot),
    );
    return logged ?? false;
  }

  @override
  ConsumerState<SpeakMealSheet> createState() => _SpeakMealSheetState();
}

class _SpeakMealSheetState extends ConsumerState<SpeakMealSheet> {
  final _controller = TextEditingController();

  bool _thinking = false;
  String? _failure;
  List<ResolvedItem>? _resolved;
  List<String> _unrecognised = const [];
  MealSlot _slot = MealSlot.lunch;

  @override
  void initState() {
    super.initState();
    _slot = widget.slot ?? _slotForHour(clock.now().hour);
  }

  /// A sensible default, so the common case is one tap fewer.
  static MealSlot _slotForHour(int hour) => switch (hour) {
        < 11 => MealSlot.breakfast,
        < 16 => MealSlot.lunch,
        < 22 => MealSlot.dinner,
        _ => MealSlot.snack,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _thinking = true;
      _failure = null;
    });

    try {
      final meal = await ref.read(openRouterClientProvider).parseMeal(text);
      final resolved = await ref.read(mealResolverProvider).resolve(meal);

      if (!mounted) return;
      setState(() {
        _resolved = resolved;
        _unrecognised = meal.unrecognised;
      });
    } on AiFailure catch (e) {
      // Every failure mode has its own sentence — "add a key" and "you have
      // used today's fifty" and "nothing answered" call for different actions.
      if (mounted) setState(() => _failure = e.message);
    } finally {
      // The call is spent whether or not it worked, so the budget re-reads
      // either way.
      ref.read(aiCallTickProvider.notifier).spent();
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _log() async {
    final items = _resolved;
    if (items == null || items.isEmpty) return;

    final db = ref.read(databaseProvider);
    final stamp = clock.now().toIso8601String();

    for (final item in items) {
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: item.food.id,
          day: widget.day,
          mealSlot: _slot,
          quantity: item.quantity,
          unit: item.unit,
          grams: item.grams,
          // The original phrasing is kept so a bad reading can be argued with
          // later, and so the Journal reads like a journal.
          rawText: Value(_controller.text.trim()),
          confidence: Value(item.confidence),
          createdAt: stamp,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop(true);
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
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          shrinkWrap: true,
          children: [
            Text('SPEAK THE MEAL', style: Type.heading(size: 16)),
            const SizedBox(height: Space.sm),
            Text(
              'Say it as you would to a person. One reading covers the whole '
              'line, however many things it names.',
              style: Type.lore(size: 12),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              style: Type.prose(size: 15),
              cursorColor: Hue.gold,
              decoration: const InputDecoration(
                hintText: 'two eggs, a slice of rye and a coffee',
              ),
            ),
            const SizedBox(height: Space.md),
            if (_resolved == null)
              WitcherButton(
                label: _thinking ? 'Reading…' : 'Read it',
                icon: Icons.auto_awesome,
                tone: ButtonTone.primary,
                onPressed: _thinking ? null : _read,
              ),
            if (_failure != null) ...[
              const SizedBox(height: Space.md),
              OrnatePanel(
                title: 'Not read',
                accent: Hue.bloodRed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_failure!, style: Type.prose(size: 13)),
                    const SizedBox(height: Space.sm),
                    Text(
                      'Search for the food by name instead — that always works '
                      'and costs nothing.',
                      style: Type.lore(size: 12),
                    ),
                  ],
                ),
              ),
            ],
            if (_resolved != null) ...[
              const SizedBox(height: Space.sm),
              MealConfirm(
                items: _resolved!,
                unrecognised: _unrecognised,
                slot: _slot,
                onSlot: (slot) => setState(() => _slot = slot),
                onLog: _log,
                onDiscard: () => setState(() {
                  _resolved = null;
                  _unrecognised = const [];
                }),
              ),
            ],
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}

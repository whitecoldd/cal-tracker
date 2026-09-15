import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/nutrition_adapter.dart';
import '../../data/remote/food_remote.dart';
import '../../data/remote/remote_food.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../domain/rarity.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/food_card.dart';
import '../../widgets/ornate_panel.dart';
import '../ai/ai_providers.dart';
import 'barcode_scanner_screen.dart';
import 'food_lookup_providers.dart';
import 'journal_providers.dart';
import 'portion_sheet.dart';
import 'speak_meal_sheet.dart';

/// Picks a food to log.
///
/// Walks the first three steps of the resolution order in CLAUDE.md §4: the
/// user's own library, the bundled seed table, then Open Food Facts. The first
/// two are one local query and paint immediately; the third arrives underneath
/// them when it arrives, and never blocks them. The model is step four and is
/// wired in T8.
///
/// A barcode is the same order with a stronger key — see [_scan].
class FoodSearchSheet extends ConsumerStatefulWidget {
  const FoodSearchSheet({required this.day, this.slot, super.key});

  final Day day;
  final MealSlot? slot;

  static Future<void> show(
    BuildContext context, {
    required Day day,
    MealSlot? slot,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSearchSheet(day: day, slot: slot),
    );
  }

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  /// True while a food is being written to the library or a barcode resolved.
  /// Both involve a round trip, and a tap that appears to do nothing is how a
  /// user ends up logging the same thing twice.
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Debounced so a fast typist does not issue a query per keystroke. This
    // matters more now than it did when search was purely local: past two
    // characters every settled query can become an Open Food Facts request.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (mounted) setState(() => _query = value);
      },
    );
  }

  Future<void> _pick(Food food) async {
    final logged = await PortionSheet.show(
      context,
      food: food,
      day: widget.day,
      initialSlot: widget.slot,
    );
    if (logged && mounted) Navigator.of(context).pop();
  }

  /// Writes an upstream food into the library, then logs it like any other.
  ///
  /// The write happens before the portion sheet rather than after a successful
  /// log, so a food resolved once stays resolved even if the user backs out of
  /// choosing a portion. That is the write-back rule in CLAUDE.md §4: a given
  /// food costs at most one network call, ever.
  Future<void> _pickRemote(RemoteFood remote) async {
    setState(() => _busy = true);
    try {
      final stored = await saveRemoteFood(ref.read(databaseProvider), remote);
      if (!mounted || stored == null) return;
      await _pick(stored);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Scans a barcode and resolves it: library first, then upstream.
  /// Hands off to the AI sheet, and closes this one if it logged anything.
  Future<void> _speak() async {
    final logged = await SpeakMealSheet.show(
      context,
      day: widget.day,
      slot: widget.slot,
    );
    if (logged && mounted) Navigator.of(context).pop();
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerScreen.scan(context);
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final food = await ref.read(barcodeLookupProvider(code).future);
      if (!mounted) return;
      if (food == null) {
        _say('Nothing answers to that sigil. Search by name instead.');
        return;
      }
      await _pick(food);
    } on RemoteUnavailable {
      if (mounted) {
        _say('Unknown here, and the wider world is out of reach.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Type.prose(size: 13)),
        backgroundColor: Hue.surfaceRaised,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().length >= 2;
    final local = searching
        ? ref.watch(foodSearchProvider(_query))
        : ref.watch(recentFoodsProvider);

    return Padding(
      padding: EdgeInsets.only(
        top: Space.huge,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        color: Hue.voidBlack,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onChanged,
                          autofocus: true,
                          style: Type.prose(size: 16),
                          cursorColor: Hue.gold,
                          decoration: InputDecoration(
                            hintText: 'Name the food',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Hue.parchmentDim,
                            ),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _controller.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      IconButton(
                        onPressed: _busy ? null : _scan,
                        tooltip: 'Scan a barcode',
                        icon: const Icon(Icons.qr_code_scanner),
                        color: Hue.gold,
                        disabledColor: Hue.parchmentFaint,
                      ),
                      // Offered only when a key exists. A button that always
                      // fails is worse than no button, and the app is fully
                      // usable without one.
                      if (ref.watch(aiAvailableProvider).valueOrNull ?? false)
                        IconButton(
                          onPressed: _busy ? null : _speak,
                          tooltip: 'Describe the meal',
                          icon: const Icon(Icons.auto_awesome),
                          color: Hue.gold,
                          disabledColor: Hue.parchmentFaint,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      _SectionHeader(
                        label: searching ? 'IN THE LIBRARY' : 'EATEN LATELY',
                      ),
                      _localSliver(local, searching),
                      if (searching) _remoteSliver(),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: Space.huge),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x990D0B0A),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Hue.gold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _localSliver(AsyncValue<List<Food>> local, bool searching) {
    return switch (local) {
      AsyncData(:final value) when value.isEmpty =>
        SliverToBoxAdapter(child: _Empty(searching: searching)),
      AsyncData(:final value) => SliverList.separated(
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: _Result(
              food: value[i],
              onTap: _busy ? null : () => _pick(value[i]),
            ),
          ),
        ),
      AsyncError(:final error) =>
        SliverToBoxAdapter(child: _Failed(error: error)),
      _ => const SliverToBoxAdapter(child: _Spinner()),
    };
  }

  /// Open Food Facts results, always *below* the local ones.
  ///
  /// Order is the resolution order made visible: something already on the
  /// device is a better answer than something fetched, because the user has
  /// used or corrected it before. A failure here is a footnote, never an error
  /// state — the app stays fully usable with no network (CLAUDE.md §4).
  Widget _remoteSliver() {
    final remote = ref.watch(remoteFoodSearchProvider(_query));

    return switch (remote) {
      AsyncData(:final value) when value.isEmpty =>
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      AsyncData(:final value) => SliverMainAxisGroup(
          slivers: [
            const _SectionHeader(label: 'FROM THE WIDER WORLD'),
            SliverList.separated(
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: _RemoteResult(
                  food: value[i],
                  onTap: _busy ? null : () => _pickRemote(value[i]),
                ),
              ),
            ),
          ],
        ),
      AsyncError() => const SliverToBoxAdapter(child: _Unreachable()),
      _ => const SliverToBoxAdapter(child: _Spinner()),
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.sm,
        ),
        child: Text(label, style: Type.label(color: Hue.gold)),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Space.lg),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Hue.goldDim,
          ),
        ),
      ),
    );
  }
}

/// Shown when Open Food Facts could not be reached.
///
/// Deliberately quiet. Nothing has gone wrong with the app — the local library
/// above is still a complete way to log a meal.
class _Unreachable extends StatelessWidget {
  const _Unreachable();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 14, color: Hue.parchmentFaint),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'The wider world is out of reach. The library still serves.',
              style: Type.lore(size: 12, color: Hue.parchmentFaint),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card, built from a nutrient panel.
///
/// Both the library and the upstream card go through this, so the same food
/// cannot read Epic in one list and Common in the other. Since T6 the ranking
/// and the harm reading both come from `domain/`, which is the only place
/// either rule is written down.
class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.name,
    required this.panel,
    required this.onTap,
    this.brand,
    this.dimmed = false,
  });

  final String name;
  final String? brand;
  final FoodPanel panel;
  final VoidCallback? onTap;

  /// Upstream results are visibly secondary to what is already on the device.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final card = FoodCard(
      name: name,
      brand: brand,
      rarity: rankFood(panel),
      kcal: panel.kcal.round(),
      detail: 'P ${panel.proteinG.round()}g · '
          'C ${panel.carbsG.round()}g · '
          'F ${panel.fatG.round()}g',
      toxicity: readFoodToxins(panel).load,
      onTap: onTap,
    );

    if (!dimmed && onTap != null) return card;
    return Opacity(opacity: onTap == null ? 0.5 : 0.85, child: card);
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.food, required this.onTap});

  final Food food;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      name: food.name,
      brand: food.brand,
      panel: food.panel,
      onTap: onTap,
    );
  }
}

/// A food from Open Food Facts that is not in the library yet.
///
/// Marked as such so the difference is visible before tapping: these numbers
/// are crowd-sourced and may be thin, and tapping one writes it to the device
/// permanently.
class _RemoteResult extends StatelessWidget {
  const _RemoteResult({required this.food, required this.onTap});

  final RemoteFood food;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      name: food.name,
      brand: food.brand,
      panel: food.panel,
      onTap: onTap,
      dimmed: true,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Text(
          searching
              ? 'Nothing by that name in the library yet.'
              : 'Nothing logged yet. Search for a food to begin.',
          textAlign: TextAlign.center,
          style: Type.lore(),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: OrnatePanel(
        title: 'Search failed',
        accent: Hue.bloodRed,
        child: Text('$error', style: Type.lore(size: 12)),
      ),
    );
  }
}

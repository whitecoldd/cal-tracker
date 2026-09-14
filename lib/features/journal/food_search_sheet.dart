import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/food_card.dart';
import '../../widgets/ornate_panel.dart';
import 'journal_providers.dart';
import 'portion_sheet.dart';

/// Picks a food to log.
///
/// Searches only what is already on the device — the user's own library and the
/// bundled staples. Open Food Facts and the model come later in the resolution
/// order (CLAUDE.md §4) and are wired in T5 and T8; until then this is the
/// whole of it, and it is free and instant.
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

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Debounced so a fast typist does not issue a query per keystroke. Cheap
    // now that search is local, but this is the same path a network lookup
    // will take in T5.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 180),
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

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().length >= 2;
    final results = searching
        ? ref.watch(foodSearchProvider(_query))
        : ref.watch(recentFoodsProvider);

    return Padding(
      padding: EdgeInsets.only(
        top: Space.huge,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        color: Hue.voidBlack,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                style: Type.prose(size: 16),
                cursorColor: Hue.gold,
                decoration: InputDecoration(
                  hintText: 'Name the food',
                  prefixIcon: const Icon(Icons.search, color: Hue.parchmentDim),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Row(
                children: [
                  Text(
                    searching ? 'FOUND' : 'EATEN LATELY',
                    style: Type.label(color: Hue.gold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: switch (results) {
                AsyncData(:final value) when value.isEmpty =>
                  _Empty(searching: searching),
                AsyncData(:final value) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      0,
                      Space.lg,
                      Space.huge,
                    ),
                    itemCount: value.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.sm),
                    itemBuilder: (_, i) => _Result(
                      food: value[i],
                      onTap: () => _pick(value[i]),
                    ),
                  ),
                AsyncError(:final error) => _Failed(error: error),
                _ => const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Hue.goldDim,
                      ),
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  /// Rarity from processing level and nutrient density.
  ///
  /// A first pass — T6 replaces this with the real scoring engine. It is here
  /// now because seeing quality *before* logging is the point of the card.
  Rarity get _rarity {
    final nova = food.novaGroup;
    final dense = food.fibreG >= 5 || food.proteinG >= 15;

    return switch (nova) {
      1 when dense => Rarity.epic,
      1 => Rarity.rare,
      2 => Rarity.rare,
      3 => Rarity.common,
      _ => Rarity.common,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FoodCard(
      name: food.name,
      brand: food.brand,
      rarity: _rarity,
      kcal: food.kcal.round(),
      detail: 'P ${food.proteinG.round()}g · '
          'C ${food.carbsG.round()}g · '
          'F ${food.fatG.round()}g',
      toxicity: (food.novaGroup ?? 1) == 4 ? 55 : 0,
      onTap: onTap,
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

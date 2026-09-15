import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai/openrouter_client.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../domain/parsed_meal.dart';
import '../../domain/portion.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';
import '../ai/ai_providers.dart';

/// Decides how much of a food was eaten, and into which meal.
///
/// Used both for adding a new entry and for correcting an existing one, because
/// the questions are identical and a separate edit screen would drift out of
/// step with this one.
class PortionSheet extends ConsumerStatefulWidget {
  const PortionSheet({
    required this.food,
    required this.day,
    this.existing,
    this.initialSlot,
    this.initialQuantity,
    this.initialUnit,
    super.key,
  });

  final Food food;
  final Day day;

  /// A quantity read off the search box, e.g. the 5 in "5 fried eggs".
  final double? initialQuantity;

  /// The unit that quantity was expressed in, if the query named one.
  final PortionUnit? initialUnit;

  /// The entry being corrected, if this is an edit.
  final Entry? existing;

  final MealSlot? initialSlot;

  /// Opens the sheet. Resolves to true if anything was written.
  static Future<bool> show(
    BuildContext context, {
    required Food food,
    required Day day,
    Entry? existing,
    MealSlot? initialSlot,
    double? initialQuantity,
    PortionUnit? initialUnit,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionSheet(
        food: food,
        day: day,
        existing: existing,
        initialSlot: initialSlot,
        initialQuantity: initialQuantity,
        initialUnit: initialUnit,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<PortionSheet> {
  late final TextEditingController _quantity;
  late PortionUnit _unit;
  late MealSlot _slot;
  bool _saving = false;

  /// True while the model is being asked what a vague portion weighs.
  bool _weighing = false;

  /// What the model said it weighs, and why it thinks so.
  ///
  /// Kept beside the resolved portion rather than replacing it: the number is
  /// an estimate of something nobody weighed, so it is shown with its reason
  /// and taken only if the user accepts it.
  PortionEstimate? _estimate;

  /// Why the last estimate could not be made, if it could not.
  String? _estimateFailure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _unit = existing?.unit ?? widget.initialUnit ?? _defaultUnit;
    _slot = existing?.mealSlot ?? widget.initialSlot ?? _slotForTimeOfDay();
    _quantity = TextEditingController(
      text: _format(existing?.quantity ?? _openingQuantity),
    );
  }

  /// What the amount field starts at for a new entry.
  ///
  /// A bare number in the search box means "5 of them", not "5 grams". So a
  /// parsed quantity is only trusted when the query named a unit, or when the
  /// food is something that comes in pieces. Otherwise "5 fried eggs" against a
  /// food with no piece weight would open at **5 g**, which is worse than the
  /// ordinary 100 it replaces.
  double get _openingQuantity {
    final parsed = widget.initialQuantity;
    if (parsed == null || parsed <= 0) return _defaultQuantity;
    if (widget.initialUnit != null || _unit.usesPieceWeight) return parsed;
    return _defaultQuantity;
  }

  /// A food that knows what one of it weighs is almost always eaten in pieces;
  /// anything else is weighed.
  PortionUnit get _defaultUnit => widget.food.gramsPerPiece != null
      ? PortionUnit.piece
      : PortionUnit.grams;

  double get _defaultQuantity =>
      _defaultUnit == PortionUnit.piece ? 1 : 100;

  /// Guesses the meal from the clock so the common case needs no taps.
  MealSlot _slotForTimeOfDay() {
    final hour = clock.now().hour;
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 15) return MealSlot.lunch;
    if (hour < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  static String _format(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  double get _quantityValue => MeasureField.parse(_quantity.text) ?? 0;

  ResolvedPortion get _resolved => resolvePortion(
        quantity: _quantityValue,
        unit: _unit,
        gramsPerPiece: widget.food.gramsPerPiece,
      );

  /// Asks the model what this portion weighs.
  ///
  /// The second of the four AI purposes in CLAUDE.md §4, and the one that has
  /// had a client, a schema, a decoder, a prompt and tests since T8 with
  /// nothing calling it. Not a fifth purpose: Settings has advertised this
  /// since T8, and the budget maths is unchanged.
  ///
  /// User-initiated, on an entry the app has already marked as a rough
  /// portion, so it costs a call only when someone actually wants one.
  Future<void> _weigh() async {
    setState(() {
      _weighing = true;
      _estimateFailure = null;
    });

    try {
      final estimate = await ref.read(openRouterClientProvider).estimatePortion(
            foodName: widget.food.name,
            quantity: _quantityValue,
            unit: _unit,
            gramsPerPiece: widget.food.gramsPerPiece,
            pieceName: widget.food.pieceName,
          );
      ref.read(aiCallTickProvider.notifier).spent();
      if (mounted) setState(() => _estimate = estimate);
    } on AiFailure catch (failure) {
      if (mounted) {
        setState(() => _estimateFailure = switch (failure) {
              AiNoKey() => 'No key is bound. Weigh it yourself for now.',
              AiBudgetSpent() => 'No readings left today.',
              AiUnreachable() => 'No answer came. Weigh it yourself for now.',
              AiUnreadable() => 'The answer made no sense.',
            });
      }
    } finally {
      if (mounted) setState(() => _weighing = false);
    }
  }

  /// Takes the model's figure, by switching to grams.
  ///
  /// Writing it as grams rather than storing a corrected multiplier is what
  /// makes it honest: the entry then says 45 g, which is what it means, and
  /// `resolvePortion` records the higher confidence that comes with an exact
  /// unit rather than inheriting the handful's.
  void _acceptEstimate() {
    final estimate = _estimate;
    if (estimate == null) return;
    setState(() {
      _unit = PortionUnit.grams;
      _quantity.text = _format(estimate.grams);
      _estimate = null;
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_quantityValue <= 0) return;
    setState(() => _saving = true);

    final dao = ref.read(databaseProvider).journalDao;
    final portion = _resolved;
    final existing = widget.existing;

    if (existing == null) {
      await dao.add(
        EntriesCompanion.insert(
          foodId: widget.food.id,
          day: widget.day,
          mealSlot: _slot,
          quantity: _quantityValue,
          unit: _unit,
          grams: portion.grams,
          confidence: Value(portion.confidence),
          createdAt: clock.now().toIso8601String(),
        ),
      );
    } else {
      await dao.updateEntry(
        existing.copyWith(
          mealSlot: _slot,
          quantity: _quantityValue,
          unit: _unit,
          grams: portion.grams,
          confidence: portion.confidence,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    setState(() => _saving = true);
    await ref.read(databaseProvider).journalDao.remove(existing.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final portion = _resolved;
    final scale = portion.grams / 100;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: OrnatePanel(
            accent: Hue.gold,
            background: Hue.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  food.name,
                  style: Type.heading(size: 19),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (food.brand != null)
                  Text(food.brand!, style: Type.lore(size: 12)),
                const RunicDivider(color: Hue.goldDim),

                // --- how much ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: MeasureField(
                        label: 'How much',
                        unit: '',
                        decimal: true,
                        controller: _quantity,
                        min: 0.1,
                        max: 10000,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(child: _UnitPicker(
                      selected: _unit,
                      onSelected: (u) => setState(() => _unit = u),
                    )),
                  ],
                ),
                const SizedBox(height: Space.lg),

                _PortionReadout(portion: portion, unit: _unit),
                // Offered only where it can help: a portion the app has
                // already admitted is a guess, and a key that exists.
                if (portion.worthRefining &&
                    _quantityValue > 0 &&
                    (ref.watch(aiAvailableProvider).valueOrNull ?? false)) ...[
                  const SizedBox(height: Space.sm),
                  _WeighByEye(
                    weighing: _weighing,
                    estimate: _estimate,
                    failure: _estimateFailure,
                    onAsk: _weighing ? null : _weigh,
                    onAccept: _acceptEstimate,
                  ),
                ],
                const SizedBox(height: Space.lg),

                // --- which meal ---
                Text('MEAL', style: Type.label()),
                const SizedBox(height: Space.sm),
                _SlotPicker(
                  selected: _slot,
                  onSelected: (s) => setState(() => _slot = s),
                ),
                const RunicDivider(),

                // --- what it comes to ---
                _Macros(food: food, scale: scale),
                const SizedBox(height: Space.lg),

                Row(
                  children: [
                    if (widget.existing != null) ...[
                      WitcherButton(
                        label: 'Remove',
                        tone: ButtonTone.danger,
                        onPressed: _saving ? null : _delete,
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                    Expanded(
                      child: WitcherButton(
                        label: widget.existing == null ? 'Log it' : 'Save',
                        tone: ButtonTone.primary,
                        expand: true,
                        onPressed:
                            _saving || _quantityValue <= 0 ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offers the model's reading of a vague portion, and shows its reasoning.
///
/// The note is not decoration. The figure is an estimate of something nobody
/// weighed, so it is shown with what it assumed — "a cupped handful, about
/// 30 g" — which is what lets it be disbelieved rather than merely accepted.
class _WeighByEye extends StatelessWidget {
  const _WeighByEye({
    required this.weighing,
    required this.estimate,
    required this.failure,
    required this.onAsk,
    required this.onAccept,
  });

  final bool weighing;
  final PortionEstimate? estimate;
  final String? failure;
  final VoidCallback? onAsk;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final reading = estimate;

    if (reading != null) {
      return OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${reading.grams.round()} g',
              style: Type.numeral(size: 22, color: Hue.gold),
            ),
            if (reading.note case final note?) ...[
              const SizedBox(height: Space.xxs),
              Text(note, style: Type.lore(size: 11)),
            ],
            const SizedBox(height: Space.sm),
            WitcherButton(label: 'Take it', onPressed: onAccept),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WitcherButton(
          label: weighing ? 'Weighing…' : 'Weigh it by eye',
          icon: Icons.auto_awesome,
          onPressed: onAsk,
        ),
        if (failure case final message?) ...[
          const SizedBox(height: Space.xs),
          Text(
            message,
            style: Type.lore(size: 11, color: Hue.adrenaline),
          ),
        ],
      ],
    );
  }
}

/// Shows the grams a vague portion resolved to, and admits when it is a guess.
class _PortionReadout extends StatelessWidget {
  const _PortionReadout({required this.portion, required this.unit});

  final ResolvedPortion portion;
  final PortionUnit unit;

  @override
  Widget build(BuildContext context) {
    if (unit.isExact) return const SizedBox.shrink();

    final vague = portion.worthRefining;
    return Row(
      children: [
        Icon(
          vague ? Icons.help_outline : Icons.straighten,
          size: 14,
          color: vague ? Hue.adrenaline : Hue.parchmentDim,
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            portion.usedPieceWeight
                ? 'About ${portion.grams.round()} g, from this food’s own '
                    'piece weight.'
                : 'About ${portion.grams.round()} g. A rough figure — correct '
                    'it in grams if it matters.',
            style: Type.lore(
              size: 11,
              color: vague ? Hue.adrenaline : Hue.parchmentDim,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitPicker extends StatelessWidget {
  const _UnitPicker({required this.selected, required this.onSelected});

  final PortionUnit selected;
  final ValueChanged<PortionUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('UNIT', style: Type.label()),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final unit in PortionUnit.values)
              _Chip(
                label: unit.short,
                isSelected: unit == selected,
                onTap: () => onSelected(unit),
              ),
          ],
        ),
      ],
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({required this.selected, required this.onSelected});

  final MealSlot selected;
  final ValueChanged<MealSlot> onSelected;

  static const _names = {
    MealSlot.breakfast: 'Breakfast',
    MealSlot.lunch: 'Lunch',
    MealSlot.dinner: 'Dinner',
    MealSlot.snack: 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final slot in MealSlot.values)
          _Chip(
            label: _names[slot]!,
            isSelected: slot == selected,
            onTap: () => onSelected(slot),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Hue.gold : Hue.surfaceRaised,
          border: Border.all(
            color: isSelected ? Hue.gold : Hue.steel,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: Type.label(
            size: 10.5,
            color: isSelected ? Hue.voidBlack : Hue.parchmentDim,
          ),
        ),
      ),
    );
  }
}

/// What this portion comes to. Absolute figures, never against a target — see
/// CLAUDE.md §1.
class _Macros extends StatelessWidget {
  const _Macros({required this.food, required this.scale});

  final Food food;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Stat(label: 'kcal', value: (food.kcal * scale).round().toString()),
        _Stat(label: 'protein', value: '${(food.proteinG * scale).round()}g'),
        _Stat(label: 'carbs', value: '${(food.carbsG * scale).round()}g'),
        _Stat(label: 'fat', value: '${(food.fatG * scale).round()}g'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Type.prose(size: 16, weight: 600)),
        const SizedBox(height: Space.xxs),
        Text(label.toUpperCase(), style: Type.label(size: 9)),
      ],
    );
  }
}

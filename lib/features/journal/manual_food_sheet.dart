import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';
import 'journal_providers.dart';

/// Writes a food into the library by hand.
///
/// The last step of the resolution order, and until now the missing one:
/// [FoodSource.manual] is the strongest source in `FoodsDao.upsert`'s
/// precedence ladder and nothing in the app could write it. So a food Open
/// Food Facts had never heard of — or held in a form the app cannot use — was
/// a dead end, however well the earlier steps worked.
///
/// A row written here is permanently authoritative: `upsert` refuses to let a
/// weaker source overwrite it, so a later barcode scan of the same product
/// enriches nothing and replaces nothing.
class ManualFoodSheet extends ConsumerStatefulWidget {
  const ManualFoodSheet({this.initialName, this.barcode, super.key});

  /// What upstream did give, when it gave something. Better than a blank field.
  final String? initialName;

  /// Carried through so the row still answers to the scan that failed.
  final String? barcode;

  /// Opens the sheet. Resolves to the stored food, or null if nothing was
  /// written.
  static Future<Food?> show(
    BuildContext context, {
    String? initialName,
    String? barcode,
  }) {
    return showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualFoodSheet(
        initialName: initialName,
        barcode: barcode,
      ),
    );
  }

  @override
  ConsumerState<ManualFoodSheet> createState() => _ManualFoodSheetState();
}

class _ManualFoodSheetState extends ConsumerState<ManualFoodSheet> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  final _brand = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _fibre = TextEditingController(text: '0');

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _protein, _carbs, _fat, _fibre]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) return;

    setState(() => _saving = true);

    final now = clock.now().toIso8601String();
    final db = ref.read(databaseProvider);
    final brand = _brand.text.trim();

    final id = await db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: _name.text.trim(),
        brand: Value(brand.isEmpty ? null : brand),
        barcode: Value(widget.barcode),
        // Recomputed by upsert, which is the only place that rule lives.
        searchKey: '',
        kcal: MeasureField.parse(_kcal.text) ?? 0,
        proteinG: Value(MeasureField.parse(_protein.text) ?? 0),
        carbsG: Value(MeasureField.parse(_carbs.text) ?? 0),
        fatG: Value(MeasureField.parse(_fat.text) ?? 0),
        fibreG: Value(MeasureField.parse(_fibre.text) ?? 0),
        source: FoodSource.manual,
        // The user is the authority on what they wrote down. Nothing upstream
        // is allowed to overwrite it later.
        confidence: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final stored = await db.foodsDao.findById(id);
    ref.read(foodLibraryTickProvider.notifier).changed();

    if (mounted) Navigator.of(context).pop(stored);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Space.huge,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        color: Hue.voidBlack,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              Text(
                'WRITE IT DOWN YOURSELF',
                style: Type.heading(size: 15, letterSpacing: 2),
              ),
              const SizedBox(height: Space.xs),
              Text(
                widget.barcode == null
                    ? 'Nothing in any ledger answers to it. Record what the '
                        'packet says, and it is yours from now on.'
                    : 'The ledger could not be used. Record what the packet '
                        'says, and this sigil will answer to it from now on.',
                style: Type.lore(size: 12),
              ),
              const RunicDivider(height: 20),
              _Text(controller: _name, label: 'Name', autofocus: true),
              const SizedBox(height: Space.md),
              _Text(controller: _brand, label: 'Brand (optional)'),
              const SizedBox(height: Space.lg),
              Text('PER 100 G OR 100 ML', style: Type.label(color: Hue.gold)),
              const SizedBox(height: Space.sm),
              Text(
                'What the packet states. Everything in the app is kept this '
                'way, and a portion is worked out from it.',
                style: Type.lore(size: 11, color: Hue.parchmentFaint),
              ),
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Energy',
                unit: 'kcal',
                controller: _kcal,
                min: 0,
                max: 900,
                decimal: true,
              ),
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Protein',
                unit: 'g',
                controller: _protein,
                min: 0,
                max: 100,
                decimal: true,
              ),
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Carbohydrate',
                unit: 'g',
                controller: _carbs,
                min: 0,
                max: 100,
                decimal: true,
              ),
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Fat',
                unit: 'g',
                controller: _fat,
                min: 0,
                max: 100,
                decimal: true,
              ),
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Fibre',
                unit: 'g',
                controller: _fibre,
                min: 0,
                max: 100,
                decimal: true,
              ),
              const SizedBox(height: Space.lg),
              OrnatePanel(
                child: Text(
                  'Written by hand, this outranks anything the wider world '
                  'says later. Nothing will overwrite it.',
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
              ),
              const SizedBox(height: Space.lg),
              WitcherButton(
                label: _saving ? 'INSCRIBING…' : 'INSCRIBE',
                tone: ButtonTone.primary,
                expand: true,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: Space.md),
              WitcherButton(
                label: 'Never mind',
                expand: true,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain text field in the app's skin.
class _Text extends StatelessWidget {
  const _Text({
    required this.controller,
    required this.label,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final optional = label.contains('optional');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: Type.label()),
        const SizedBox(height: Space.xs),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          style: Type.prose(size: 15),
          cursorColor: Hue.gold,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (optional) return null;
            return (value ?? '').trim().isEmpty ? 'Required' : null;
          },
        ),
      ],
    );
  }
}

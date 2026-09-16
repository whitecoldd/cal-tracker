import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/ai/image_prep.dart';
import '../../data/ai/openrouter_client.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../../domain/parsed_meal.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/measure_field.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';
import '../ai/ai_providers.dart';
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
  // Sugars, saturates and salt sit on every EU nutrition table beside the four
  // above, and all three feed Toxicity and Vitality. Without them a food
  // written by hand scored as though it contained none of any of them, which
  // is not a missing figure but a wrong one.
  final _sugar = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _satFat = TextEditingController(text: '0');
  final _sodium = TextEditingController(text: '0');
  final _fibre = TextEditingController(text: '0');

  bool _saving = false;

  /// Running while a photographed label is being read.
  bool _reading = false;

  /// What went wrong with the last reading, if anything.
  String? _readFailure;

  /// Set once a reading has filled the form.
  ///
  /// The figures came off small print in a photograph, so the sheet says where
  /// they came from and asks to have them checked. A form that silently filled
  /// itself would be indistinguishable from one the user had typed.
  bool _filledFromLabel = false;

  /// NOVA group and glycemic index as read off the label.
  ///
  /// Held in state rather than shown: neither has a field, both drive scoring,
  /// and adding two more inputs to a hand-entry form to carry a model's guess
  /// would be the wrong trade. They are saved only when a reading produced
  /// them, so a food typed by hand still says nothing it was not told.
  int? _novaGroup;
  int? _glycemicIndex;

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _kcal,
      _protein,
      _carbs,
      _sugar,
      _fat,
      _satFat,
      _sodium,
      _fibre,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Photographs the packet and fills the form from its nutrition table.
  ///
  /// The fifth AI use in CLAUDE.md §4. It exists because the alternative for a
  /// product no ledger carries is typing eight figures off small print, and
  /// the write-back rule makes the cost one call for that product forever.
  ///
  /// Nothing is saved here. The reading fills the fields and the user presses
  /// INSCRIBE, so a misread panel is caught by the person holding the packet
  /// rather than by the library six weeks later.
  Future<void> _readLabel(ImageSource source) async {
    // Higher quality than a meal photograph asks for: see [photoPickerProvider].
    final bytes = await ref.read(photoPickerProvider)(source, quality: 92);
    if (bytes == null || !mounted) return;

    setState(() {
      _reading = true;
      _readFailure = null;
    });

    var spent = false;
    try {
      final prepared = await ref.read(imagePrepProvider).prepare(bytes);

      spent = true;
      final reading = await ref.read(openRouterClientProvider).readLabel(
            imageDataUri: prepared.dataUri,
            barcode: widget.barcode,
          );

      if (!mounted) return;
      if (reading == null) {
        setState(
          () => _readFailure = 'No table could be read from that picture. '
              'Photograph the panel itself, square on and in good light.',
        );
        return;
      }
      _fill(reading);
    } on ImageTooLarge catch (e) {
      // Thrown before the request, so nothing was spent.
      if (mounted) {
        setState(() => _readFailure = 'That picture could not be prepared '
            '($e). Try taking it again.');
      }
    } on AiFailure catch (e) {
      if (mounted) setState(() => _readFailure = e.message);
    } finally {
      if (spent) ref.read(aiCallTickProvider.notifier).spent();
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Writes a reading into the fields.
  ///
  /// The name is only taken when the field is empty. A name carried in from a
  /// failed scan came from Open Food Facts, which held the product even if it
  /// could not price it, and that beats a model reading a curved packet.
  void _fill(LabelReading reading) {
    final food = reading.food;
    final panel = food.panel;

    setState(() {
      if (_name.text.trim().isEmpty) _name.text = food.name;
      final brand = food.brand;
      if (_brand.text.trim().isEmpty && brand != null) _brand.text = brand;

      _kcal.text = _figure(panel.kcal);
      _protein.text = _figure(panel.proteinG);
      _carbs.text = _figure(panel.carbsG);
      _sugar.text = _figure(panel.sugarG);
      _fat.text = _figure(panel.fatG);
      _satFat.text = _figure(panel.satFatG);
      _sodium.text = _figure(panel.sodiumMg);
      _fibre.text = _figure(panel.fibreG);

      _novaGroup = panel.novaGroup;
      _glycemicIndex = panel.glycemicIndex;
      _filledFromLabel = true;
      _readFailure = null;
    });
  }

  /// A figure as it should appear in a field the user is about to check.
  ///
  /// One decimal at most, and none on a whole number: a label states 21 g of
  /// protein, not 21.0, and a form that disagrees with the packet in front of
  /// the user invites them to distrust the parts that are right.
  static String _figure(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

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
        sugarG: Value(MeasureField.parse(_sugar.text) ?? 0),
        fatG: Value(MeasureField.parse(_fat.text) ?? 0),
        satFatG: Value(MeasureField.parse(_satFat.text) ?? 0),
        sodiumMg: Value(MeasureField.parse(_sodium.text) ?? 0),
        fibreG: Value(MeasureField.parse(_fibre.text) ?? 0),
        // Only ever set by a label reading — there is no field for either, so
        // on a hand-typed food these stay null rather than claiming a 1.
        novaGroup: Value(_novaGroup),
        glycemicIndex: Value(_glycemicIndex),
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
              _LabelReader(
                reading: _reading,
                failure: _readFailure,
                filled: _filledFromLabel,
                onSource: _reading ? null : _readLabel,
              ),
              const SizedBox(height: Space.md),
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
                label: 'of which sugars',
                unit: 'g',
                controller: _sugar,
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
                label: 'of which saturates',
                unit: 'g',
                controller: _satFat,
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
              const SizedBox(height: Space.md),
              MeasureField(
                label: 'Sodium',
                unit: 'mg',
                controller: _sodium,
                min: 0,
                max: 40000,
                decimal: true,
              ),
              const SizedBox(height: Space.xs),
              Text(
                'A pack that states salt rather than sodium: multiply the '
                'grams of salt by 400.',
                style: Type.lore(size: 11, color: Hue.parchmentFaint),
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

/// Offers to read the nutrition table off a photograph of the packet.
///
/// Sits above the fields rather than beside the save button because it is the
/// alternative to filling them in, not a step after doing so.
class _LabelReader extends ConsumerWidget {
  const _LabelReader({
    required this.reading,
    required this.filled,
    required this.onSource,
    this.failure,
  });

  final bool reading;
  final bool filled;
  final String? failure;

  /// Null while a reading is in flight.
  final void Function(ImageSource)? onSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offered only with a key bound. Unlike the search sheet's model buttons,
    // which explain themselves because they are that sheet's best capability,
    // this one has a complete alternative sitting directly underneath it: the
    // fields. A button that fails where the form already works would be noise.
    final available = ref.watch(aiAvailableProvider).valueOrNull ?? false;
    if (!available) return const SizedBox.shrink();

    return OrnatePanel(
      title: 'Read the packet',
      accent: filled ? Hue.gold : Hue.steel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            filled
                ? 'Taken from the panel you photographed. Check it against '
                    'the packet before inscribing — it was read off small '
                    'print, and what you save here outranks everything.'
                : 'Photograph the nutrition table and the figures below are '
                    'filled in for you. One reading for this food, ever.',
            style: Type.lore(size: 12),
          ),
          if (failure case final message?) ...[
            const SizedBox(height: Space.sm),
            Text(
              message,
              style: Type.lore(size: 12, color: Hue.adrenaline),
            ),
          ],
          const SizedBox(height: Space.sm),
          if (reading)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Hue.gold,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text('Reading the panel…', style: Type.lore(size: 12)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: WitcherButton(
                    label: filled ? 'AGAIN' : 'PHOTOGRAPH',
                    icon: Icons.photo_camera_outlined,
                    onPressed: onSource == null
                        ? null
                        : () => onSource!(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: WitcherButton(
                    label: 'FROM GALLERY',
                    icon: Icons.photo_library_outlined,
                    onPressed: onSource == null
                        ? null
                        : () => onSource!(ImageSource.gallery),
                  ),
                ),
              ],
            ),
        ],
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

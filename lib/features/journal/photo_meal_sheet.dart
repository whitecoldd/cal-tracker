import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/ai/image_prep.dart';
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
import 'journal_providers.dart';
import 'meal_confirm.dart';

/// Log a meal by photographing it.
///
/// One request per photograph, however many foods are on the plate. The
/// picture is shrunk and stripped of its metadata before it leaves the device
/// — see [ImagePolicy] and `ImageCompressor` for why both matter.
class PhotoMealSheet extends ConsumerStatefulWidget {
  const PhotoMealSheet({required this.day, this.slot, super.key});

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
      builder: (_) => PhotoMealSheet(day: day, slot: slot),
    );
    return logged ?? false;
  }

  @override
  ConsumerState<PhotoMealSheet> createState() => _PhotoMealSheetState();
}

class _PhotoMealSheetState extends ConsumerState<PhotoMealSheet> {
  final _note = TextEditingController();

  Uint8List? _preview;
  bool _thinking = false;
  String? _failure;
  List<ResolvedItem>? _resolved;
  List<String> _unrecognised = const [];
  late MealSlot _slot;

  @override
  void initState() {
    super.initState();
    _slot = widget.slot ?? _slotForHour(clock.now().hour);
  }

  static MealSlot _slotForHour(int hour) => switch (hour) {
        < 11 => MealSlot.breakfast,
        < 16 => MealSlot.lunch,
        < 22 => MealSlot.dinner,
        _ => MealSlot.snack,
      };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// What was sent to the model, held so it can be written down on logging.
  PreparedPhoto? _prepared;

  Future<void> _pick(ImageSource source) async {
    final bytes = await ref.read(photoPickerProvider)(source);
    if (bytes == null || !mounted) return;

    setState(() {
      _preview = bytes;
      _failure = null;
      _resolved = null;
      _prepared = null;
    });
  }

  Future<void> _read() async {
    final bytes = _preview;
    if (bytes == null) return;

    setState(() {
      _thinking = true;
      _failure = null;
    });

    var spent = false;
    try {
      final prepared = await ref.read(imagePrepProvider).prepare(bytes);

      spent = true;
      final meal = await ref.read(openRouterClientProvider).parsePhoto(
            imageDataUri: prepared.dataUri,
            note: _note.text,
          );
      final resolved = await ref.read(mealResolverProvider).resolve(meal);
      // The resolver writes anything new into the library, so an open search
      // sheet must not keep serving a list assembled before that.
      ref.read(foodLibraryTickProvider.notifier).changed();

      if (!mounted) return;
      setState(() {
        _resolved = resolved;
        _unrecognised = meal.unrecognised;
        // Kept only now, once the picture has actually produced something.
        // Writing a file for a photograph the user then discards would leave
        // a souvenir of a meal that was never logged.
        _prepared = prepared;
      });
    } on ImageTooLarge catch (e) {
      // Caught before the request, so nothing was spent.
      if (mounted) {
        setState(() => _failure = 'That picture could not be prepared ($e). '
            'Try taking it again.');
      }
    } on AiFailure catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (spent) ref.read(aiCallTickProvider.notifier).spent();
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _log() async {
    final items = _resolved;
    if (items == null || items.isEmpty) return;

    final db = ref.read(databaseProvider);
    final stamp = clock.now().toIso8601String();
    final note = _note.text.trim();

    // One photograph, one file, and every entry it produced points at it. That
    // is what the column allows and it is honest: each of these rows did come
    // out of this picture. `rawText` one line down already works exactly this
    // way with the note.
    final photo = await ref.read(mealPhotoStoreProvider).save(
          _prepared?.jpeg ?? Uint8List(0),
          stamp: stamp,
        );

    for (final item in items) {
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: item.food.id,
          day: widget.day,
          mealSlot: _slot,
          quantity: item.quantity,
          unit: item.unit,
          grams: item.grams,
          rawText: Value(note.isEmpty ? null : note),
          photoPath: Value(photo),
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
        top: Space.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ColoredBox(
        color: Hue.voidBlack,
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          shrinkWrap: true,
          children: [
            Text('PAINT THE PLATE', style: Type.heading(size: 16)),
            const SizedBox(height: Space.sm),
            Text(
              'One reading covers the whole plate. The picture is shrunk and '
              'its location data removed before it is sent.',
              style: Type.lore(size: 12),
            ),
            const SizedBox(height: Space.md),
            if (_preview == null)
              _Sources(onPick: _pick)
            else ...[
              _Preview(bytes: _preview!),
              const SizedBox(height: Space.md),
              TextField(
                controller: _note,
                style: Type.prose(size: 14),
                cursorColor: Hue.gold,
                decoration: const InputDecoration(
                  hintText: 'Anything the picture does not show (optional)',
                ),
              ),
              const SizedBox(height: Space.md),
              if (_resolved == null)
                WitcherButton(
                  label: _thinking ? 'Reading…' : 'Read the plate',
                  icon: Icons.auto_awesome,
                  tone: ButtonTone.primary,
                  onPressed: _thinking ? null : _read,
                ),
              const SizedBox(height: Space.sm),
              if (_resolved == null)
                WitcherButton(
                  label: 'Take another',
                  onPressed: _thinking ? null : () => _pick(ImageSource.camera),
                ),
            ],
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
                emptyMessage: 'No food was recognised in that picture. '
                    'Try a straighter angle, or name the foods instead.',
              ),
            ],
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WitcherButton(
          label: 'Take a photograph',
          icon: Icons.photo_camera_outlined,
          tone: ButtonTone.primary,
          onPressed: () => onPick(ImageSource.camera),
        ),
        const SizedBox(height: Space.sm),
        WitcherButton(
          label: 'Choose one',
          icon: Icons.photo_library_outlined,
          onPressed: () => onPick(ImageSource.gallery),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Hue.steel, width: Geometry.frameStroke),
          ),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

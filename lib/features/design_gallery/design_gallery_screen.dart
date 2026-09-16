import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';

import '../../domain/harm.dart';
import '../../domain/rarity.dart';
import '../../domain/sealed_value.dart';
import '../../domain/signs.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/alchemy_vial.dart';
import '../../widgets/creature_plate.dart';
import '../../widgets/curse_line.dart';
import '../../widgets/food_card.dart';
import '../../widgets/meal_thumb.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/runic_tabs.dart';
import '../../widgets/sealed_node.dart';
import '../../widgets/sign_glyph.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/witcher_button.dart';

/// Every primitive in the design system on one scrollable page.
///
/// This is a development surface, not a product screen. It exists so the look
/// can be judged on a real device before any feature depends on it, and so a
/// change to a token is immediately visible everywhere it lands.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  bool _revealed = false;

  /// Which segment the mode-switch sample is showing.
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _section('Typography'),
          OrnatePanel(
            title: 'The Wolf School',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Week the Seventh', style: Type.heading(size: 24)),
                const SizedBox(height: Space.sm),
                Text(
                  'Running text sits in EB Garamond. It should read comfortably '
                  'at length, because the weekly account is meant to be read, '
                  'not skimmed.',
                  style: Type.prose(),
                ),
                const RunicDivider(),
                Text(
                  'Lore italics carry the flavour — bestiary entries, the '
                  'taunt on a sealed panel, the narrator at the week end.',
                  style: Type.lore(),
                ),
                const SizedBox(height: Space.md),
                Text('ENGRAVED LABEL', style: Type.label()),
                const SizedBox(height: Space.xs),
                Text('2,140', style: Type.numeral()),
              ],
            ),
          ),

          _section('Sealed values'),
          Text(
            'The signature interaction: a value that exists, is recorded, and '
            'refuses to be read until the week closes.',
            style: Type.lore(),
          ),
          const SizedBox(height: Space.md),
          OrnatePanel(
            title: 'The Reckoning',
            accent: _revealed ? Hue.gold : Hue.steel,
            trailing: GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Text(
                _revealed ? 'RE-SEAL' : 'UNSEAL',
                style: Type.label(color: Hue.gold),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SealedNode(
                    label: 'Energy balance',
                    value: _revealed
                        ? const Revealed(-2340)
                        : const Sealed<num>(),
                    format: (n) => '${n > 0 ? '+' : ''}${n.round()}',
                  ),
                ),
                Container(width: 1, height: 64, color: Hue.steelDim),
                Expanded(
                  child: SealedNode(
                    label: 'Weight change',
                    value: _revealed
                        ? const Revealed(-0.4)
                        : const Sealed<num>(),
                    format: (n) => '${n.toStringAsFixed(1)} kg',
                    lore: 'Ask again when the week is done.',
                  ),
                ),
              ],
            ),
          ),

          _section('Stat bars'),
          const OrnatePanel(
            child: Column(
              children: [
                StatBar(
                  label: 'Vitality',
                  value: 78,
                  color: Hue.vitality,
                ),
                SizedBox(height: Space.md),
                StatBar(
                  label: 'Toxicity',
                  value: 41,
                  color: Hue.toxicity,
                ),
                SizedBox(height: Space.md),
                StatBar(
                  label: 'Stamina',
                  value: 8412,
                  max: 10000,
                  color: Hue.stamina,
                  valueLabel: '8,412 steps',
                ),
                SizedBox(height: Space.md),
                StatBar(
                  label: 'Adrenaline',
                  value: 4,
                  max: 7,
                  color: Hue.adrenaline,
                  segments: 7,
                  valueLabel: '4 day streak',
                ),
              ],
            ),
          ),

          _section('Alchemy'),
          const OrnatePanel(
            title: 'Macros',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AlchemyVial(
                  label: 'Protein',
                  value: 118,
                  target: 150,
                  color: Hue.vitality,
                ),
                AlchemyVial(
                  label: 'Carbs',
                  value: 210,
                  target: 220,
                  color: Hue.stamina,
                ),
                AlchemyVial(
                  label: 'Fat',
                  value: 79,
                  target: 65,
                  color: Hue.adrenaline,
                ),
                AlchemyVial(
                  label: 'Fibre',
                  value: 12,
                  target: 30,
                  color: Hue.toxicity,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          // The same primitive measuring composition rather than a quantity
          // against a goal. This is the mode the Alchemy screen uses, because
          // a macro target derived from expenditure could be subtracted back
          // into a deficit. See CLAUDE.md §1.
          const OrnatePanel(
            title: 'Composition',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AlchemyVial(
                  label: 'Protein',
                  value: 0.26,
                  target: 0.35,
                  color: Hue.vitality,
                  valueLabel: '26%',
                  captionLabel: '10-35%',
                ),
                AlchemyVial(
                  label: 'Carbs',
                  value: 0.51,
                  target: 0.65,
                  color: Hue.stamina,
                  valueLabel: '51%',
                  captionLabel: '45-65%',
                ),
                AlchemyVial(
                  label: 'Fat',
                  value: 0.42,
                  target: 0.35,
                  color: Hue.adrenaline,
                  valueLabel: '42%',
                  captionLabel: '20-35%',
                ),
              ],
            ),
          ),

          _section('Signs'),
          OrnatePanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (sign, charge) in const [
                  (Sign.igni, 0.79),
                  (Sign.quen, 0.40),
                  (Sign.aard, 0.84),
                  (Sign.axii, 1.0),
                  (Sign.yrden, 0.15),
                ])
                  SignGlyph(sign: sign, charge: charge, showLabel: true),
              ],
            ),
          ),

          _section('Food cards'),
          const FoodCard(
            name: 'Red lentils, dry',
            rarity: FoodRarity.epic,
            kcal: 352,
            detail: 'P 24g - C 60g - F 1g - Fibre 11g',
          ),
          const SizedBox(height: Space.sm),
          const FoodCard(
            name: 'Chicken breast, raw',
            rarity: FoodRarity.rare,
            kcal: 120,
            detail: 'P 23g - C 0g - F 3g',
          ),
          const SizedBox(height: Space.sm),
          const FoodCard(
            name: 'Energy drink, 500ml',
            brand: 'Some Brand',
            rarity: FoodRarity.common,
            kcal: 45,
            detail: 'Sugar 11g - Caffeine 160mg - NOVA 4',
            toxicity: 72,
          ),

          _section('Buttons'),
          OrnatePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WitcherButton(
                  label: 'Log the meal',
                  icon: Icons.add,
                  tone: ButtonTone.primary,
                  expand: true,
                  onPressed: () {},
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: WitcherButton(
                        label: 'Scan',
                        icon: Icons.qr_code_scanner,
                        expand: true,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: WitcherButton(
                        label: 'Discard',
                        tone: ButtonTone.danger,
                        expand: true,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                const WitcherButton(
                  label: 'Sealed until Sunday',
                  expand: true,
                  onPressed: null,
                ),
              ],
            ),
          ),

          _section('Mode switch'),
          RunicTabs<int>(
            tabs: const [
              RunicTab(
                value: 0,
                label: 'The Tally',
                lore: 'The week in figures.',
              ),
              RunicTab(
                value: 1,
                label: 'The Tale',
                lore: 'The week in words.',
              ),
            ],
            selected: _mode,
            onSelected: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: Space.lg),
          // Three segments, to show the strip does not assume two.
          RunicTabs<int>(
            tabs: const [
              RunicTab(value: 0, label: 'Week'),
              RunicTab(value: 1, label: 'Month'),
              RunicTab(value: 2, label: 'All'),
            ],
            selected: 1,
            onSelected: (_) {},
            accent: Hue.steelLight,
          ),

          _section('Curse lines'),
          OrnatePanel(
            title: 'Curses',
            accent: Hue.bloodRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CurseLine(
                  title: 'Salt burn',
                  detail: '4,100 mg — 205% of the guideline',
                  basis: 'Sodium against the WHO guideline of 2,000 mg a day.',
                  isPastGuideline: true,
                ),
                const CurseLine(
                  title: 'Sweet rot',
                  detail: '38 g — 7% of energy',
                  basis: 'Free sugars against the WHO guideline of under 10% '
                      'of energy.',
                  isPastGuideline: false,
                ),
                const RunicDivider(),
                Text(
                  harmDisclaimer,
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
              ],
            ),
          ),

          _section('Panel accents'),
          OrnatePanel(
            title: 'Harm',
            accent: Hue.bloodRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Four additives, two of them NOVA 4 markers. Sodium at 168% '
                  'of the daily reference.',
                  style: Type.prose(size: 14),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Lore, not a physician — not medical advice.',
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
              ],
            ),
          ),
          _section('Creature plate'),
          OrnatePanel(
            title: 'Epic',
            accent: FoodRarity.epic.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreaturePlate(
                  image: _PaintedSample(),
                  accent: FoodRarity.epic.color,
                ),
                const SizedBox(height: Space.md),
                Text('Salted almonds', style: Type.heading(size: 20)),
                Text('Alesto', style: Type.lore(size: 12)),
                const RunicDivider(),
                // The same photograph at journal size, weathered by the same
                // filter, so the two surfaces that show pictures can be
                // compared side by side rather than a screen apart.
                Row(
                  children: [
                    MealThumb(image: _PaintedSample()),
                    Expanded(
                      child: Text(
                        'Logged from a photograph',
                        style: Type.prose(size: 14),
                      ),
                    ),
                    Text('184', style: Type.prose(size: 15, weight: 600)),
                    const SizedBox(width: Space.xs),
                    Text('kcal', style: Type.label(size: 8)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.huge),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: Type.label(color: Hue.gold)),
          const SizedBox(width: Space.md),
          const Expanded(child: RunicDivider(color: Hue.goldDim, height: 10)),
        ],
      ),
    );
  }
}

/// A stand-in photograph, painted rather than loaded.
///
/// The gallery must render with no network and no files, and a golden must be
/// able to draw it without a real event loop — `MemoryImage` and `FileImage`
/// both decode asynchronously, which fake async never completes. A picture
/// recorded and rasterised with `toImageSync` is available on the first frame.
///
/// It is a rough food-coloured wash on purpose. What is being reviewed here is
/// the *treatment* — the frame, the scrim, how much colour survives — and a
/// recognisable photograph would draw the eye away from exactly that.
class _PaintedSample extends ImageProvider<_PaintedSample> {
  static const int _size = 64;

  @override
  Future<_PaintedSample> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PaintedSample>(this);

  @override
  ImageStreamCompleter loadImage(_PaintedSample key, ImageDecoderCallback _) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: _paint())),
    );
  }

  ui.Image _paint() {
    final recorder = ui.PictureRecorder();
    const rect = Rect.fromLTWH(0, 0, _size * 1.0, _size * 1.0);

    Canvas(recorder, rect)
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB07A3C), Color(0xFF6B4A22)],
          ).createShader(rect),
      )
      ..drawCircle(
        const Offset(_size * 0.62, _size * 0.4),
        _size * 0.22,
        Paint()..color = const Color(0xFFD8A657),
      );

    return recorder.endRecording().toImageSync(_size, _size);
  }

  @override
  bool operator ==(Object other) => other is _PaintedSample;

  @override
  int get hashCode => (_PaintedSample).hashCode;
}

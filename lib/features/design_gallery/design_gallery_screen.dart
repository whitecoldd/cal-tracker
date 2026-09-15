import 'package:flutter/material.dart';

import '../../domain/rarity.dart';
import '../../domain/sealed_value.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/alchemy_vial.dart';
import '../../widgets/food_card.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
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

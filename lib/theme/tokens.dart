// Deliberately `animation` rather than `material`: this file is the bottom of
// the theme layer and nothing here should be able to reach a widget. It
// re-exports the `dart:ui` types the colour tokens need, plus the curve
// [Motion] is defined in terms of.
import 'package:flutter/animation.dart';

/// Colour, spacing and geometry tokens for the Witcher 3 skin.
///
/// Never use a raw colour literal in a widget — pull it from here so the whole
/// app can be re-tinted from one place.
abstract final class Hue {
  // --- ground ---
  /// Page background. Near-black, warm rather than blue.
  static const Color voidBlack = Color(0xFF0D0B0A);

  /// Panel fill, one step lifted off the void.
  static const Color surface = Color(0xFF17130F);

  /// Raised surface: cards on panels, selected rows.
  static const Color surfaceRaised = Color(0xFF221C16);

  // --- text ---
  /// Primary text. Aged parchment.
  static const Color parchment = Color(0xFFE8D9B0);

  /// Secondary text and lore italics.
  static const Color parchmentDim = Color(0xFFA89878);

  /// Disabled / placeholder.
  static const Color parchmentFaint = Color(0xFF6B6254);

  // --- chrome ---
  /// Accent, XP, ornament. Old gold.
  static const Color gold = Color(0xFFC9A227);

  /// Gold at rest — borders that should not shout.
  static const Color goldDim = Color(0xFF7A6318);

  /// Borders, dividers, disabled ornament.
  static const Color steel = Color(0xFF4A4540);

  /// Lit steel — chain links, anything that should catch the light.
  static const Color steelLight = Color(0xFF6A6358);

  /// Hairline separators inside panels.
  static const Color steelDim = Color(0xFF2E2A26);

  // --- stat colours, mapped to the game's own HUD ---
  /// Vitality. Geralt's health bar is red.
  static const Color vitality = Color(0xFFB4232D);

  /// Danger, harm flags, damage. Darker than vitality so the two never blur.
  static const Color bloodRed = Color(0xFF8B1A1A);

  /// Toxicity. The sickly green of one decoction too many.
  static const Color toxicity = Color(0xFF7A9A3C);

  /// Stamina.
  static const Color stamina = Color(0xFFC9A227);

  /// Adrenaline / streak heat.
  static const Color adrenaline = Color(0xFFD06A1E);

  // --- rarity ---
  static const Color rarityCommon = Color(0xFF9A9086);
  static const Color rarityRare = Color(0xFF4E7FB0);

  /// The waterskin and the Yrden glyph. The same steel-blue as [rarityRare],
  /// named separately because it is used for a different reason — a token that
  /// means "rare" should not be what a water bar reaches for.
  static const Color water = Color(0xFF4E7FB0);
  static const Color rarityEpic = Color(0xFF9B59B6);
  static const Color rarityRelic = Color(0xFFC9A227);
}

/// Spacing scale. Multiples of 4.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Geometry shared by the ornate primitives.
abstract final class Geometry {
  /// Length of a panel's corner bracket arm.
  static const double bracketArm = 14;

  /// Border width for ornate frames.
  static const double frameStroke = 1.2;

  /// Radius used sparingly — this world has very few rounded corners.
  static const double radius = 2;
}

/// How the app moves.
///
/// Centralised for the same reason colour is: a duration picked per widget
/// drifts, and the difference between a page being turned and a Material route
/// sliding in is entirely in these numbers. Short, and barely any travel —
/// CLAUDE.md §5 is engraved and weathered, not animated.
abstract final class Motion {
  /// A day giving way to another day.
  static const Duration page = Duration(milliseconds: 220);

  /// A scrim, a readout resizing — anything the eye should not have to wait on.
  static const Duration quick = Duration(milliseconds: 140);

  static const Curve easeOut = Curves.easeOutCubic;

  /// How far a page slides, as a fraction of its width. Deliberately small.
  static const double slide = 0.06;
}

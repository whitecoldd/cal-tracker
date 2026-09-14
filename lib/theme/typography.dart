import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography for the Witcher skin.
///
/// Both families are bundled **variable** fonts, so weight must be applied with
/// [FontVariation] on the `wght` axis. Setting only [TextStyle.fontWeight]
/// makes Flutter synthesise a fake bold instead of using the real axis.
abstract final class Type {
  static const String display = 'Cinzel';
  static const String body = 'EBGaramond';

  static List<FontVariation> _w(double weight) => [FontVariation('wght', weight)];

  /// Engraved capitals. Screen titles, section headers, numbers that matter.
  static TextStyle heading({
    double size = 20,
    double weight = 600,
    Color color = Hue.parchment,
    double letterSpacing = 1.6,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: 1.2,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: _w(weight),
    );
  }

  /// Running text.
  static TextStyle prose({
    double size = 15,
    double weight = 400,
    Color color = Hue.parchment,
    double height = 1.45,
  }) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      height: height,
      color: color,
      fontVariations: _w(weight),
    );
  }

  /// Flavour text — bestiary entries, the weekly narrative, sealed taunts.
  static TextStyle lore({double size = 14, Color color = Hue.parchmentDim}) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      height: 1.5,
      color: color,
      fontStyle: FontStyle.italic,
      fontVariations: _w(400),
    );
  }

  /// Small engraved label above a value. Always upper-cased by the widget.
  static TextStyle label({
    double size = 10.5,
    Color color = Hue.parchmentDim,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: 1.1,
      color: color,
      letterSpacing: 2.2,
      fontVariations: _w(600),
    );
  }

  /// A number the eye should land on.
  static TextStyle numeral({double size = 28, Color color = Hue.parchment}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: 1.0,
      color: color,
      letterSpacing: 0.5,
      fontVariations: _w(700),
    );
  }
}

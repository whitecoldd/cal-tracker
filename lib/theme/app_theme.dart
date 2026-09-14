import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Assembles the [ThemeData] for the Witcher skin.
///
/// Material defaults are deliberately overridden almost everywhere: this world
/// has no rounded cards, no elevation shadows and no purple ripples.
abstract final class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: Hue.gold,
      onPrimary: Hue.voidBlack,
      secondary: Hue.bloodRed,
      onSecondary: Hue.parchment,
      surface: Hue.surface,
      onSurface: Hue.parchment,
      error: Hue.bloodRed,
      onError: Hue.parchment,
      outline: Hue.steel,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Hue.voidBlack,
      canvasColor: Hue.voidBlack,
      splashColor: Hue.gold.withValues(alpha: 0.08),
      highlightColor: Hue.gold.withValues(alpha: 0.05),
      dividerTheme: const DividerThemeData(
        color: Hue.steelDim,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: Type.heading(size: 34, weight: 700),
        headlineMedium: Type.heading(size: 24),
        titleLarge: Type.heading(size: 18),
        titleMedium: Type.heading(size: 15, weight: 500, letterSpacing: 1.2),
        bodyLarge: Type.prose(size: 16),
        bodyMedium: Type.prose(),
        bodySmall: Type.prose(size: 13, color: Hue.parchmentDim),
        labelLarge: Type.label(size: 12),
        labelSmall: Type.label(),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Hue.voidBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: Type.heading(size: 17, letterSpacing: 3),
        iconTheme: const IconThemeData(color: Hue.parchmentDim, size: 20),
      ),
      iconTheme: const IconThemeData(color: Hue.parchmentDim),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Hue.surfaceRaised,
        hintStyle: Type.prose(color: Hue.parchmentFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md,
        ),
        border: _inputBorder(Hue.steel),
        enabledBorder: _inputBorder(Hue.steel),
        focusedBorder: _inputBorder(Hue.gold),
        errorBorder: _inputBorder(Hue.bloodRed),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: Hue.surfaceRaised,
          border: Border.fromBorderSide(BorderSide(color: Hue.goldDim)),
        ),
        textStyle: Type.prose(size: 13),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Geometry.radius),
      borderSide: BorderSide(color: color, width: Geometry.frameStroke),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A creature's picture, treated to sit inside the Bestiary.
///
/// Takes an [ImageProvider] rather than a URL or a path, which is the seam
/// everything else depends on: the design gallery hands it a painted
/// placeholder and a golden hands it a synchronous one, so neither needs a
/// network, a file, or the asynchronous decode that makes images so awkward in
/// a widget test.
///
/// **The treatment is the point.** A supermarket photograph dropped on void
/// black fights every other surface in the app. Desaturated towards the
/// palette, dimmed, and sunk behind a scrim that fades into the panel beneath
/// it, it reads as a plate in a bestiary rather than a shop listing. See
/// CLAUDE.md §5.
class CreaturePlate extends StatelessWidget {
  const CreaturePlate({
    required this.image,
    this.accent = Hue.steel,
    this.height = 132,
    super.key,
  });

  /// Null renders nothing at all — most foods have no picture, and an empty
  /// frame saying so would be worse than the space it occupies.
  final ImageProvider? image;

  /// Borrowed from the creature's rarity, so the frame agrees with the panel
  /// it sits in.
  final Color accent;

  final double height;

  /// How much colour survives. Not zero: a fully grey plate loses the one
  /// thing a photograph is for, which is recognising the food at a glance.
  static const double _saturation = 0.45;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: accent),
          color: Hue.voidBlack,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(_desaturate),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                // A picture that will not decode is the same as no picture.
                // It cannot be a broken-image icon: this is a food sheet, and
                // the failure is never the user's to act on.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                // No fade-in. The plate is either there on the first frame or
                // it is filled in when the file arrives, and an opacity
                // animation on every rebuild reads as flicker.
                gaplessPlayback: true,
              ),
            ),
            // Sinks the photograph into the panel rather than letting it end
            // on a hard edge.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC0D0B0A)],
                  stops: [0.35, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A saturation matrix at [_saturation], with the whole thing dimmed.
  ///
  /// Written out rather than composed at runtime because a `ColorFilter.matrix`
  /// wants a const list and the numbers are stable — they are the standard
  /// luminance weights, blended towards identity.
  static const List<double> _desaturate = <double>[
    0.2126 + 0.7874 * _saturation, 0.7152 - 0.7152 * _saturation, 0.0722 - 0.0722 * _saturation, 0, 0, //
    0.2126 - 0.2126 * _saturation, 0.7152 + 0.2848 * _saturation, 0.0722 - 0.0722 * _saturation, 0, 0, //
    0.2126 - 0.2126 * _saturation, 0.7152 - 0.7152 * _saturation, 0.0722 + 0.9278 * _saturation, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

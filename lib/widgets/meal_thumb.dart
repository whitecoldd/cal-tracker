import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The small square that marks an entry as one the camera produced.
///
/// Takes an [ImageProvider] for the same reason `CreaturePlate` does: a real
/// file decodes asynchronously, and a widget test's fake async never turns the
/// event loop that would finish it.
///
/// Weathered with the same filter as the Bestiary plate, from [Filters], so the
/// two surfaces that show photographs treat them identically. A journal row is
/// mostly type at eleven and fourteen points; a full-saturation thumbnail
/// beside it would be the loudest thing on the Journal.
class MealThumb extends StatelessWidget {
  const MealThumb({required this.image, this.size = 30, super.key});

  /// Null renders nothing — and nothing is the right answer far more often
  /// than not. Most entries were typed, and after a restore *every* entry's
  /// photograph is gone while the entry itself is intact.
  final ImageProvider? image;

  final double size;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Hue.steel),
            color: Hue.voidBlack,
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(Filters.weathered),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

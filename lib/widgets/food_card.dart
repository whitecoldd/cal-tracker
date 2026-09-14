import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// How good a food is, as a collectable-card rarity.
///
/// Derived from NOVA group and nutrient density, so lentils outrank an energy
/// drink without the app having to lecture anyone.
enum Rarity {
  common('Common', Hue.rarityCommon),
  rare('Rare', Hue.rarityRare),
  epic('Epic', Hue.rarityEpic),
  relic('Relic', Hue.rarityRelic);

  const Rarity(this.title, this.color);

  final String title;
  final Color color;
}

/// A Gwent-style card for one food.
///
/// Used in the Bestiary and in search results, so the quality of a choice is
/// legible before it is logged.
class FoodCard extends StatelessWidget {
  const FoodCard({
    required this.name,
    required this.rarity,
    required this.kcal,
    this.brand,
    this.detail,
    this.toxicity = 0,
    this.onTap,
    super.key,
  });

  final String name;
  final String? brand;
  final Rarity rarity;

  /// Energy per 100g.
  final int kcal;

  /// Short stat line, e.g. P 24g - C 2g - F 11g.
  final String? detail;

  /// 0..100. Drives the bar along the bottom edge.
  final double toxicity;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: _CardPainter(rarity.color, toxicity / 100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.md,
            Space.md,
            Space.md + 3,
          ),
          child: Row(
            children: [
              // Energy sits in its own gem at the left, like a card cost.
              _CostGem(kcal: kcal, color: rarity.color),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.prose(size: 15, weight: 600),
                    ),
                    if (brand != null)
                      Text(
                        brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.lore(size: 12),
                      ),
                    if (detail != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        detail!,
                        style: Type.prose(size: 12, color: Hue.parchmentDim),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                rarity.title.toUpperCase(),
                style: Type.label(size: 9, color: rarity.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostGem extends StatelessWidget {
  const _CostGem({required this.kcal, required this.color});

  final int kcal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _GemPainter(color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$kcal', style: Type.numeral(size: 15)),
              Text('KCAL', style: Type.label(size: 6.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GemPainter extends CustomPainter {
  const _GemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Flat-topped hexagon.
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (i * 60 - 30) * math.pi / 180;
      final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();

    canvas
      ..drawPath(path, Paint()..color = Hue.voidBlack)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.8),
      );
  }

  @override
  bool shouldRepaint(_GemPainter old) => old.color != color;
}

class _CardPainter extends CustomPainter {
  const _CardPainter(this.accent, this.toxicity);

  final Color accent;
  final double toxicity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRect(rect, Paint()..color = Hue.surface)
      // Rarity strip down the left edge.
      ..drawRect(Rect.fromLTWH(0, 0, 3, size.height), Paint()..color = accent)
      ..drawRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Hue.steelDim,
      );

    // Toxicity creeping along the bottom edge. The colour shifts from the
    // sickly green of the HUD meter towards blood red as it climbs, so a
    // mostly-full strip can never be mistaken for a filled progress bar.
    if (toxicity > 0) {
      final t = toxicity.clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 3, size.width * t, 3),
        Paint()..color = Color.lerp(Hue.toxicity, Hue.bloodRed, t)!,
      );
    }
  }

  @override
  bool shouldRepaint(_CardPainter old) =>
      old.accent != accent || old.toxicity != toxicity;
}

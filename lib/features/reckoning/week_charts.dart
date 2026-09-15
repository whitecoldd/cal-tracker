import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The week's daily energy balance, as bars above and below the line.
///
/// Only ever built from a revealed week. Drawing the verdict as a picture is
/// no better than printing it, so the caller unwraps a `SealedValue` before
/// this widget exists at all. See CLAUDE.md §1.
class BalanceChart extends StatelessWidget {
  const BalanceChart({required this.balances, super.key});

  /// One entry per logged day, oldest first. Negative is a deficit.
  final List<double> balances;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Text('No days to plot.', style: Type.lore(size: 12));
    }

    final extent = balances
        .map((b) => b.abs())
        .fold<double>(500, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          // Symmetric about zero, so a deficit day and a surplus day of the
          // same size look the same size.
          maxY: extent,
          minY: -extent,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: extent,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Hue.steelDim,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: const BarTouchData(enabled: false),
          barGroups: [
            for (var i = 0; i < balances.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    fromY: 0,
                    toY: balances[i],
                    width: 14,
                    borderRadius: BorderRadius.zero,
                    // A deficit is not "good" and a surplus is not "bad" — the
                    // colours separate direction, they do not grade it.
                    color: balances[i] < 0 ? Hue.toxicity : Hue.adrenaline,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The week's weigh-ins.
class WeightChart extends StatelessWidget {
  const WeightChart({required this.weights, super.key});

  /// Oldest first. Gaps are simply absent rather than interpolated.
  final List<double> weights;

  @override
  Widget build(BuildContext context) {
    if (weights.length < 2) {
      return Text(
        'Not enough weigh-ins this week to draw a line.',
        style: Type.lore(size: 12),
      );
    }

    final low = weights.reduce((a, b) => a < b ? a : b);
    final high = weights.reduce((a, b) => a > b ? a : b);
    // A flat week would otherwise draw as a wild zigzag on a zero-height axis.
    final pad = ((high - low) * 0.5).clamp(0.3, 5.0);

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minY: low - pad,
          maxY: high + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < weights.length; i++)
                  FlSpot(i.toDouble(), weights[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              color: Hue.gold,
              barWidth: 2,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: Hue.gold,
                  strokeWidth: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

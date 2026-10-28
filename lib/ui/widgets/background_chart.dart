import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../bloc/history.dart';

/// Bare line chart of [history] (no axes, grid or interaction) for use as a
/// faint background behind the readings.
class BackgroundChart extends StatelessWidget {
  const BackgroundChart({super.key, required this.history, this.opacity = 0.5});

  final SampleHistory history;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final points = history.points;
    final values = [for (final p in points) ?p.value];
    if (values.length < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final pad = (maxY - minY) * 0.15;
    if (pad == 0) {
      final delta = maxY.abs() * 0.1 + 1e-9;
      minY -= delta;
      maxY += delta;
    } else {
      minY -= pad;
      maxY += pad;
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: points.first.t,
            maxX: math.max(points.last.t, points.first.t + 1),
            minY: minY,
            maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final p in points)
                    p.value == null ? FlSpot.nullSpot : FlSpot(p.t, p.value!),
                ],
                color: scheme.primary,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

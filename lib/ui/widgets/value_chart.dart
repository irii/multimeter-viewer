import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../bloc/history.dart';
import '../../fluke/units.dart';
import '../../l10n/l10n.dart';

/// Charts narrower than this show the values inside the plot instead of on
/// an axis next to it, leaving the whole width to the curve (phones).
const double _insideLabelsBelowWidth = 480;

/// Width of the value axis left of the plot.
double _leftAxisWidth(double chartWidth) =>
    chartWidth < _insideLabelsBelowWidth ? 0 : 48;

/// Height of the time axis below the plot (labels, plus its name on wide
/// charts).
double _bottomAxisHeight(double chartWidth) =>
    chartWidth < _insideLabelsBelowWidth ? 22 : 22 + 16;

/// Line chart of [points] (values in base units of [unit]). The axis uses an
/// SI prefix chosen from the largest value; `null` values become gaps.
///
/// With [startTime] the time axis shows the clock time (`HH:mm:ss`) of each
/// point instead of seconds. With [controller] the chart can be zoomed and
/// panned horizontally (mouse wheel / pinch, drag).
class ValueLineChart extends StatelessWidget {
  const ValueLineChart({
    super.key,
    required this.points,
    required this.unit,
    this.minPoints,
    this.maxPoints,
    this.startTime,
    this.controller,
  });

  /// Must contain at least one non-null value.
  final List<SamplePoint> points;

  /// Optional band (e.g. interval minimum/maximum) drawn behind [points].
  final List<SamplePoint>? minPoints;
  final List<SamplePoint>? maxPoints;
  final String unit;

  /// Wall-clock time of `t == 0`.
  final DateTime? startTime;

  /// Enables zoom/pan and lets the caller drive it (see [ChartZoom]).
  final TransformationController? controller;

  static const double maxZoom = 200;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (controller == null) return _buildChart(context, size, 1);
        // Rebuild on zoom so the time labels adapt to the visible range.
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) =>
              _buildChart(context, size, controller.value.getMaxScaleOnAxis()),
        );
      },
    );
  }

  Widget _buildChart(BuildContext context, Size size, double zoom) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = size.width;
    final inside = width < _insideLabelsBelowWidth;

    final values = [
      for (final p in [...points, ...?minPoints, ...?maxPoints]) ?p.value,
    ];
    final maxAbs = values.map((v) => v.abs()).fold(0.0, math.max);
    final multiplier = isUnscaledUnit(unit)
        ? 0
        : multiplierForMagnitude(maxAbs);
    final scale = math.pow(10, multiplier).toDouble();
    final axisUnit = '${prefixForMultiplier(multiplier)}${unitSymbol(unit)}';

    List<FlSpot> spotsOf(List<SamplePoint> series) => [
      for (final p in series)
        p.value == null ? FlSpot.nullSpot : FlSpot(p.t, p.value! / scale),
    ];
    final spots = spotsOf(points);
    final band = minPoints != null && maxPoints != null;
    LineChartBarData bandLine(List<SamplePoint> series) => LineChartBarData(
      spots: spotsOf(series),
      color: scheme.primary.withValues(alpha: 0.35),
      barWidth: 1,
      dotData: const FlDotData(show: false),
    );

    var minY = values.reduce(math.min) / scale;
    var maxY = values.reduce(math.max) / scale;
    final pad = (maxY - minY).abs() * 0.1;
    if (pad == 0) {
      final delta = maxY.abs() * 0.1 + 0.001;
      minY -= delta;
      maxY += delta;
    } else {
      minY -= pad;
      maxY += pad;
    }

    final minX = points.first.t;
    final maxX = math.max(points.last.t, minX + 1);

    // Value steps that match the grid, roughly one per 50 px.
    final plotHeight = math.max(size.height - _bottomAxisHeight(width), 40.0);
    final valueInterval = niceValueInterval((maxY - minY) / (plotHeight / 50));
    final decimals = math.max(
      0,
      -(math.log(valueInterval) / math.ln10).floor(),
    );

    // Roughly one time label per 90 px of the visible range.
    final plotWidth = math.max(width - _leftAxisWidth(width), 100.0);
    final visibleRange = (maxX - minX) / zoom;
    final timeInterval = niceTimeInterval(visibleRange / (plotWidth / 90));

    String timeLabel(double t) => startTime == null
        ? formatAxisTime(t, visibleRange)
        : formatClock(_clockAt(t), withFraction: timeInterval < 1);

    final chart = LineChart(
      duration: Duration.zero,
      transformationConfig: controller == null
          ? const FlTransformationConfig()
          : FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              maxScale: maxZoom,
              transformationController: controller,
            ),
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          horizontalInterval: valueInterval,
          verticalInterval: timeInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          getDrawingVerticalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(
          border: Border.all(color: scheme.outlineVariant),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          // The unit is shown above the axis (wide) or with each value
          // inside the plot (narrow), not as a rotated axis name.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !inside,
              reservedSize: _leftAxisWidth(width),
              interval: valueInterval,
              // Only the grid values, not the padded chart edges.
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(decimals),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            // The time base is named by the toggle above the chart; phones
            // keep the height for the curve.
            axisNameWidget: inside
                ? null
                : Text(
                    startTime != null
                        ? l10n.axisClock
                        : visibleRange > 120
                        ? l10n.axisTime
                        : l10n.axisTimeSeconds,
                  ),
            axisNameSize: inside ? 0 : 16,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: timeInterval,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  timeLabel(value),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  // With a band, bars 0/1 are the interval minimum/maximum.
                  band && s.barIndex < 2
                      ? '${s.barIndex == 0 ? '↓' : '↑'} '
                            '${s.y.toStringAsPrecision(5)} $axisUnit'
                      : '${s.y.toStringAsPrecision(5)} $axisUnit\n'
                            '${startTime == null ? '' : '${formatClock(_clockAt(s.x), withFraction: true)} · '}'
                            '+${s.x.toStringAsFixed(1)} s',
                  TextStyle(color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
        // Band first, so the main line is drawn on top.
        betweenBarsData: [
          if (band)
            BetweenBarsData(
              fromIndex: 0,
              toIndex: 1,
              color: scheme.primary.withValues(alpha: 0.18),
            ),
        ],
        lineBarsData: [
          if (band) ...[bandLine(minPoints!), bandLine(maxPoints!)],
          LineChartBarData(
            spots: spots,
            color: scheme.primary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: !band,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (!inside) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(axisUnit, style: labelStyle),
          const SizedBox(height: 2),
          Expanded(child: chart),
        ],
      );
    }

    // Values with unit on the grid lines, inside the plot.
    double yOf(double v) => plotHeight * (maxY - v) / (maxY - minY);
    final first = (minY / valueInterval).ceil();
    final last = (maxY / valueInterval).floor();
    return Stack(
      children: [
        Positioned.fill(child: chart),
        for (var k = first; k <= last; k++)
          if (yOf(k * valueInterval) case final y when y > 14 && y < plotHeight)
            Positioned(
              left: 4,
              top: y - 15,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '${(k * valueInterval).toStringAsFixed(decimals)} $axisUnit',
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  DateTime _clockAt(double t) =>
      startTime!.add(Duration(milliseconds: (t * 1000).round()));
}

/// Zoom buttons for a [ValueLineChart] driven by [controller].
class ChartZoom {
  ChartZoom(this.controller);

  final TransformationController controller;

  double get scale => controller.value.getMaxScaleOnAxis();

  /// Zooms by [factor] around the horizontal center of a plot that is
  /// [chartWidth] wide (including the value axis).
  void zoomBy(double factor, double chartWidth) {
    final width = math.max(chartWidth - _leftAxisWidth(chartWidth), 1.0);
    final m = controller.value;
    final s = m.getMaxScaleOnAxis();
    final tx = m.storage[12];
    final newScale = (s * factor).clamp(1.0, ValueLineChart.maxZoom);
    // Keep the content at the viewport center in place.
    final center = width / 2;
    final contentX = (center - tx) / s;
    final newTx = (center - contentX * newScale).clamp(
      width - width * newScale,
      0.0,
    );
    controller.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, newTx);
  }

  void reset() => controller.value = Matrix4.identity();
}

/// A "nice" value step (1, 2 or 5 times a power of ten) of at least [raw].
double niceValueInterval(double raw) {
  if (raw <= 0 || !raw.isFinite) return 1;
  final power = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final step in const [1, 2, 5, 10]) {
    if (step * power >= raw) return step * power;
  }
  return 10 * power;
}

/// A "nice" axis step (1, 2, 5, 10, 15, 30 s, 1, 2, 5, 10, 15, 30 min, ...)
/// of at least [raw] seconds.
double niceTimeInterval(double raw) {
  const steps = [
    0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, //
    60, 120, 300, 600, 900, 1800,
    3600, 7200, 10800, 21600, 43200, 86400,
  ];
  for (final step in steps) {
    if (step >= raw) return step.toDouble();
  }
  return (raw / 86400).ceil() * 86400.0;
}

/// Axis label for [seconds]: plain seconds for short ranges, `m:ss` or
/// `h:mm:ss` for long ones.
String formatAxisTime(double seconds, double range) {
  if (range <= 120) return seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1);
  final total = seconds.round();
  String two(int v) => v.toString().padLeft(2, '0');
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// `HH:mm:ss`, or `HH:mm:ss.s` with [withFraction].
String formatClock(DateTime t, {bool withFraction = false}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final base = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  return withFraction ? '$base.${t.millisecond ~/ 100}' : base;
}

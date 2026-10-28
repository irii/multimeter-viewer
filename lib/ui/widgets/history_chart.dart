import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/history.dart';
import '../../bloc/time_base_cubit.dart';
import '../../fluke/units.dart';
import '../../l10n/l10n.dart';
import 'value_chart.dart';

/// Line chart of the PRIMARY reading. Starts over when the unit changes
/// (handled by [SampleHistory]).
///
/// With [expand] the chart fills the height its parent gives it (use inside
/// an `Expanded`); otherwise it is [height] pixels tall.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.history,
    this.expand = false,
    this.height = 300,
  });

  final SampleHistory history;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unit = history.unit;
    final timeBase = context.watch<TimeBaseCubit>().state;
    final systemStart = history.systemStart;
    final useSystem = timeBase == TimeBase.system && systemStart != null;
    final chart = history.hasValues
        ? ValueLineChart(
            points: useSystem
                ? [
                    for (final p in history.points)
                      if (p.systemT case final t?) SamplePoint(t, p.value),
                  ]
                : history.points,
            unit: unit ?? 'NONE',
            startTime: useSystem ? systemStart : history.meterStart,
          )
        : Center(
            child: Text(
              l10n.waitingForReadings,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  unit == null
                      ? l10n.history
                      : l10n.historyWithUnit(unitLabel(unit)),
                  style: theme.textTheme.titleMedium,
                ),
                SegmentedButton<TimeBase>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: TimeBase.meter,
                      icon: const Icon(Icons.speed, size: 18),
                      label: Text(l10n.timeBaseMeter),
                      tooltip: l10n.timeBaseMeterTooltip,
                    ),
                    ButtonSegment(
                      value: TimeBase.system,
                      icon: const Icon(Icons.computer, size: 18),
                      label: Text(l10n.timeBaseSystem),
                      tooltip: l10n.timeBaseSystemTooltip,
                    ),
                  ],
                  selected: {timeBase},
                  onSelectionChanged: (s) =>
                      context.read<TimeBaseCubit>().select(s.single),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expand)
              Expanded(child: chart)
            else
              SizedBox(height: height, child: chart),
          ],
        ),
      ),
    );
  }
}

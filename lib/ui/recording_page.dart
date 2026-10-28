import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/history.dart';
import '../fluke/units.dart';
import '../l10n/l10n.dart';
import '../recording/recording.dart';
import '../recording/recording_csv.dart';
import '../recording/recording_files.dart';
import '../recording/viewer_bloc.dart';
import '../router.dart';
import 'widgets/recording_banner.dart' show formatDuration;
import 'widgets/value_chart.dart';
import 'widgets/window_app_bar.dart';
import 'widgets/bar_actions.dart';

/// Asks for a recording file and shows it on the recording page. Works with
/// or without a meter connection.
void openRecordingFile(BuildContext context) {
  context.read<RecordingViewerBloc>().add(const RecordingViewerFileRequested());
  context.push(Routes.recording);
}

class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordingViewerBloc, RecordingViewerState>(
      listenWhen: (previous, current) =>
          current.error != null &&
          current.error != previous.error &&
          current.recording != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(viewerErrorText(context, state)))),
      builder: (context, state) {
        final recording = state.recording;
        return Scaffold(
          appBar: WindowAppBar(
            appBar: AppBar(
              title: Text(
                recording == null || recording.info.name.isEmpty
                    ? context.l10n.recording
                    : recording.info.name,
              ),
              actions: [
                BarActions(
                  actions: [
                    BarAction(
                      icon: Icons.save_alt,
                      label: context.l10n.actionExportCsv,
                      pinned: true,
                      onPressed: recording == null
                          ? null
                          : () => _export(context, recording),
                    ),
                    BarAction(
                      icon: Icons.folder_open,
                      label: context.l10n.actionOpenRecording,
                      onPressed: () => context.read<RecordingViewerBloc>().add(
                        const RecordingViewerFileRequested(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: switch (state.status) {
            RecordingViewerStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            RecordingViewerStatus.loaded => _RecordingView(state: state),
            RecordingViewerStatus.empty ||
            RecordingViewerStatus.failure => _Empty(
              error: state.error == null
                  ? null
                  : viewerErrorText(context, state),
            ),
          },
        );
      },
    );
  }
}

/// Saves [recording] as CSV, whatever its origin.
Future<void> _export(BuildContext context, Recording recording) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final fileName = suggestedFileName(recording.info, recording.startedAt);
  try {
    if (!await saveCsvFile(fileName, recordingToCsv(recording))) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recordingExported(fileName))),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed('$e'))));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null ? Icons.insert_chart_outlined : Icons.error_outline,
              size: 64,
              color: error == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error == null
                  ? context.l10n.noRecordingLoaded
                  : context.l10n.loadingFailed,
              style: theme.textTheme.titleLarge,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              SelectableText(error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<RecordingViewerBloc>().add(
                const RecordingViewerFileRequested(),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(context.l10n.actionOpenRecording),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({required this.state});

  final RecordingViewerState state;

  @override
  Widget build(BuildContext context) {
    final recording = state.recording!;
    final groups = recording.samplesByUnit;
    final unit = state.selectedUnit;
    final samples = state.selectedSamples;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MetadataCard(recording: recording, fileName: state.fileName),
            const SizedBox(height: 12),
            if (groups.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in groups.entries)
                    ChoiceChip(
                      label: Text(
                        '${unitLabel(entry.key)} (${entry.value.length})',
                      ),
                      selected: entry.key == unit,
                      onSelected: (_) => context
                          .read<RecordingViewerBloc>()
                          .add(RecordingViewerUnitSelected(entry.key)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (unit != null) ...[
              _StatsRow(samples: samples, unit: unit),
              const SizedBox(height: 12),
              _RecordingChart(
                samples: samples,
                unit: unit,
                startedAt: recording.startedAt,
              ),
            ] else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.l10n.recordingHasNoSamples),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.recording, this.fileName});

  final Recording recording;

  /// File the recording was loaded from, `null` if not saved.
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = recording.info;
    final identity = recording.identity;
    final range = recording.range;
    final entries = <(String, String)>[
      (
        l10n.originLabel,
        switch (recording.origin) {
          RecordingOrigin.app => l10n.originApp,
          RecordingOrigin.meter => l10n.originMeter,
        },
      ),
      (l10n.fileLabel, fileName ?? l10n.notSaved),
      if (info.identifier.isNotEmpty) (l10n.identifierLabel, info.identifier),
      (l10n.startMeter, l10n.dateTime(recording.startedAt)),
      (l10n.endMeter, l10n.dateTime(recording.endedAt)),
      if (recording.systemStartedAt != null)
        (l10n.startSystem, l10n.dateTime(recording.systemStartedAt!)),
      if (clockOffset(l10n, recording) case final offset?)
        (l10n.meterClockOffset, offset),
      (
        l10n.duration,
        info.duration > Duration.zero
            ? l10n.durationOf(
                formatDuration(recording.duration),
                formatDuration(info.duration),
              )
            : formatDuration(recording.duration),
      ),
      (l10n.readings, '${recording.samples.length}'),
      if (recording.sampleInterval case final interval?)
        (l10n.sampleIntervalLabel, _interval(l10n, interval)),
      if (recording.eventThreshold case final threshold?)
        (l10n.eventThresholdLabel, '${l10n.decimal(threshold * 100, 1)} %'),
      if (range != null)
        (
          l10n.rangeLabel,
          '${range.label} · ${range.autoRange ? l10n.rangeAuto : l10n.rangeManual}',
        ),
      if (identity != null) ...[
        (l10n.model, identity.model),
        (l10n.serialNumber, identity.serial),
        (l10n.firmware, identity.firmware),
      ],
      if (recording.stopReason != null)
        (l10n.endedLabel, l10n.stopReason(recording.stopReason!)),
    ];

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                for (final (label, value) in entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SelectableText(value, style: theme.textTheme.bodyLarge),
                    ],
                  ),
              ],
            ),
            if (info.comment.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                l10n.commentLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SelectableText(info.comment, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.samples, required this.unit});

  final List<RecordingSample> samples;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = [
      for (final s in samples)
        if (s.trend.hasValue) s,
    ];
    final overloads = samples.length - valid.length;
    // Interval recordings: extremes from the interval min/max, average
    // weighted by interval length.
    double low(RecordingSample s) =>
        s.minimum?.hasValue ?? false ? s.minimum!.value : s.trend.value;
    double high(RecordingSample s) =>
        s.maximum?.hasValue ?? false ? s.maximum!.value : s.trend.value;
    double weight(RecordingSample s) => (s.interval?.inMilliseconds ?? 0) > 0
        ? s.interval!.inMilliseconds / 1000
        : 1;
    final totalWeight = valid.fold(0.0, (sum, s) => sum + weight(s));
    final stats = <(String, String)>[
      if (valid.isNotEmpty) ...[
        (
          l10n.statMinimum,
          formatQuantity(valid.map(low).reduce(math.min), unit),
        ),
        (
          l10n.statMaximum,
          formatQuantity(valid.map(high).reduce(math.max), unit),
        ),
        (
          l10n.statAverage,
          formatQuantity(
            valid.fold(0.0, (sum, s) => sum + s.trend.value * weight(s)) /
                totalWeight,
            unit,
          ),
        ),
      ],
      (l10n.readings, '${samples.length}'),
      if (overloads > 0) (l10n.overloadInvalid, '$overloads'),
    ];

    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in stats)
          SizedBox(
            width: 200,
            child: Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingChart extends StatefulWidget {
  const _RecordingChart({
    required this.samples,
    required this.unit,
    required this.startedAt,
  });

  final List<RecordingSample> samples;
  final String unit;
  final DateTime startedAt;

  @override
  State<_RecordingChart> createState() => _RecordingChartState();
}

class _RecordingChartState extends State<_RecordingChart> {
  final _controller = TransformationController();
  late final _zoom = ChartZoom(_controller);

  @override
  void didUpdateWidget(_RecordingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New unit or recording: show everything again.
    if (oldWidget.unit != widget.unit ||
        oldWidget.startedAt != widget.startedAt) {
      _zoom.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final points = <SamplePoint>[];
    final minPoints = <SamplePoint>[];
    final maxPoints = <SamplePoint>[];
    for (final s in widget.samples) {
      final value = s.trend.hasValue ? s.trend.value : null;
      // Collapse runs of invalid readings into one gap.
      if (value == null && points.isNotEmpty && points.last.value == null) {
        continue;
      }
      final t = s.elapsed.inMilliseconds / 1000;
      points.add(SamplePoint(t, value));
      if (s.minimum != null || s.maximum != null) {
        minPoints.add(
          SamplePoint(
            t,
            s.minimum?.hasValue ?? false ? s.minimum!.value : value,
          ),
        );
        maxPoints.add(
          SamplePoint(
            t,
            s.maximum?.hasValue ?? false ? s.maximum!.value : value,
          ),
        );
      }
    }
    final hasValues = points.any((p) => p.value != null);
    final hasBand = minPoints.length == points.length && minPoints.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.recordingWithUnit(unitLabel(widget.unit)),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => Text(
                      '${_zoom.scale.toStringAsFixed(1)}×',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.zoomOut,
                    icon: const Icon(Icons.zoom_out),
                    onPressed: () => _zoom.zoomBy(1 / 2, constraints.maxWidth),
                  ),
                  IconButton(
                    tooltip: l10n.zoomIn,
                    icon: const Icon(Icons.zoom_in),
                    onPressed: () => _zoom.zoomBy(2, constraints.maxWidth),
                  ),
                  IconButton(
                    tooltip: l10n.zoomReset,
                    icon: const Icon(Icons.fit_screen),
                    onPressed: _zoom.reset,
                  ),
                ],
              ),
              Text(
                l10n.zoomHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: hasValues
                    ? ValueLineChart(
                        points: points,
                        minPoints: hasBand ? minPoints : null,
                        maxPoints: hasBand ? maxPoints : null,
                        unit: widget.unit,
                        startTime: widget.startedAt,
                        controller: _controller,
                      )
                    : Center(child: Text(l10n.noValidReadings)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sample interval, e.g. `0,3 s` or `1:00`.
String _interval(AppLocalizations l10n, Duration interval) {
  final seconds = interval.inMicroseconds / 1e6;
  return seconds < 60
      ? '${l10n.decimal(seconds, seconds % 1 == 0 ? 0 : 1)} s'
      : formatDuration(interval);
}

/// Error of the viewer as text, naming the file when known.
String viewerErrorText(BuildContext context, RecordingViewerState state) {
  final l10n = context.l10n;
  final reason = l10n.error(state.error!);
  final file = state.errorFile;
  return file == null
      ? l10n.errorOpenFile(reason)
      : l10n.errorFileWithReason(file, reason);
}

/// How far the meter clock is ahead (+) or behind (−) the system clock,
/// from the first sample, e.g. `+2,4 s`; `null` without system times.
String? clockOffset(AppLocalizations l10n, Recording recording) {
  final first = recording.samples
      .where((s) => s.systemTime != null)
      .firstOrNull;
  if (first == null) return null;
  final seconds =
      first.meterTime.difference(first.systemTime!).inMilliseconds / 1000;
  final abs = seconds.abs();
  final sign = seconds < 0 ? '−' : '+';
  final text = abs >= 120
      ? formatDuration(Duration(seconds: abs.round()))
      : '${l10n.decimal(abs, 1)} s';
  return '$sign$text';
}

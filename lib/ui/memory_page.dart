import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/memory_bloc.dart';
import '../fluke/fluke_memory_reader.dart';
import '../fluke/qdda.dart';
import '../l10n/l10n.dart';
import '../recording/viewer_bloc.dart';
import '../router.dart';
import 'mono_font.dart';
import 'widgets/recording_banner.dart' show formatDuration;
import 'widgets/window_app_bar.dart';
import 'widgets/bar_actions.dart';

/// Lists recordings, min/max and peak sessions and saved measurements stored
/// in the connected meter; recordings can be downloaded and charted.
class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<MemoryBloc, MemoryState>(
      listenWhen: (previous, current) =>
          current.downloadCount != previous.downloadCount ||
          (current.downloadError != null &&
              current.downloadError != previous.downloadError) ||
          (current.downloadCancelled && !previous.downloadCancelled),
      listener: (context, state) {
        if (state.downloadError != null) {
          _snack(
            context,
            l10n.downloadFailed(l10n.error(state.downloadError!)),
          );
        } else if (state.downloadCancelled) {
          _snack(context, l10n.downloadCancelled);
        } else if (state.downloaded != null) {
          context.read<RecordingViewerBloc>().add(
            RecordingViewerShown(state.downloaded!),
          );
          context.push(Routes.recording);
        }
      },
      child: BlocBuilder<MemoryBloc, MemoryState>(
        builder: (context, state) => Scaffold(
          appBar: WindowAppBar(
            appBar: AppBar(
              title: Text(l10n.meterMemory),
              actions: [
                BarActions(
                  actions: [
                    BarAction(
                      icon: Icons.refresh,
                      label: l10n.actionRescan,
                      pinned: true,
                      onPressed:
                          state.status == MemoryStatus.loading ||
                              state.downloading != null
                          ? null
                          : () => context.read<MemoryBloc>().add(
                              const MemoryLoadRequested(),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: switch (state.status) {
            MemoryStatus.loading => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.memoryReading),
                ],
              ),
            ),
            MemoryStatus.failure => _Failure(error: state.error),
            MemoryStatus.loaded => _Contents(state: state),
          },
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _Failure extends StatelessWidget {
  const _Failure({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.memoryReadFailed, style: theme.textTheme.titleLarge),
            if (error != null) ...[
              const SizedBox(height: 8),
              SelectableText(l10n.error(error!), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.read<MemoryBloc>().add(const MemoryLoadRequested()),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contents extends StatelessWidget {
  const _Contents({required this.state});

  final MemoryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final contents = state.contents;
    if (contents.isEmpty) {
      return Center(child: Text(l10n.memoryEmpty));
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: l10n.memoryRecordings,
              icon: Icons.timeline,
              hint: l10n.memoryDownloadHint,
              children: [
                for (final r in contents.recordings)
                  _RecordingTile(recording: r, state: state),
              ],
            ),
            _Section(
              title: l10n.memoryMinMax,
              icon: Icons.unfold_more,
              children: [
                for (final s in contents.minMaxSessions)
                  _SessionTile(session: s),
              ],
            ),
            _Section(
              title: l10n.memoryPeak,
              icon: Icons.show_chart,
              children: [
                for (final s in contents.peakSessions) _SessionTile(session: s),
              ],
            ),
            _Section(
              title: l10n.memoryMeasurements,
              icon: Icons.bookmark_border,
              children: [
                for (final m in contents.measurements)
                  _MeasurementTile(measurement: m),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.hint,
  });

  final String title;
  final IconData icon;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(
                '$title (${children.length})',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: hint == null || children.isEmpty ? null : Text(hint!),
            ),
            if (children.isEmpty)
              ListTile(
                dense: true,
                title: Text(
                  context.l10n.memoryNoEntries,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording, required this.state});

  final MemoryRecording recording;
  final MemoryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = state.downloading?.index == recording.index;
    final busy = state.downloading != null;
    final interval = recording.sampleInterval < 60
        ? '${l10n.decimal(recording.sampleInterval, recording.sampleInterval % 1 == 0 ? 0 : 1)} s'
        : formatDuration(
            Duration(milliseconds: (recording.sampleInterval * 1000).round()),
          );

    return ListTile(
      title: Text(recording.name.isEmpty ? l10n.unnamed : recording.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.primaryFunction(recording.primaryFunction)} · '
            '${l10n.dateTime(recording.startTime)} – '
            '${l10n.timeOfDay(recording.endTime)} '
            '(${formatDuration(recording.duration)})\n'
            '${l10n.sampleCount(recording.sampleCount)} · '
            '${l10n.memoryInterval(interval)}',
          ),
          if (active) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 2),
            Text(
              l10n.downloadProgress(state.downloadDone, state.downloadTotal),
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: active
          ? IconButton(
              tooltip: l10n.actionCancelDownload,
              icon: const Icon(Icons.close),
              onPressed: () => context.read<MemoryBloc>().add(
                const MemoryDownloadCancelRequested(),
              ),
            )
          : FilledButton.tonalIcon(
              onPressed: busy
                  ? null
                  : () => context.read<MemoryBloc>().add(
                      MemoryDownloadRequested(recording),
                    ),
              icon: const Icon(Icons.download),
              label: Text(l10n.actionDownload),
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final MemorySession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      title: Text(session.name.isEmpty ? l10n.unnamed : session.name),
      subtitle: Text(
        '${l10n.primaryFunction(session.primaryFunction)} · '
        '${l10n.dateTime(session.startTime)} – '
        '${l10n.timeOfDay(session.endTime)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [_ReadingTable(readings: session.readings)],
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.measurement});

  final MemoryMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = measurement.time;
    return ExpansionTile(
      title: Text(measurement.name.isEmpty ? l10n.unnamed : measurement.name),
      subtitle: Text(
        '${l10n.primaryFunction(measurement.primaryFunction)}'
        '${time == null ? '' : ' · ${l10n.dateTime(time)}'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [_ReadingTable(readings: measurement.readings)],
    );
  }
}

class _ReadingTable extends StatelessWidget {
  const _ReadingTable({required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final r in readings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.readingId(r.id),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${r.signedDisplayText} ${r.unitText}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: monoFontFamily,
                    fontFamilyFallback: monoFontFamilyFallback,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(
                    l10n.timeOfDay(r.time),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

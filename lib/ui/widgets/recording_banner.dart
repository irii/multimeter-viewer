import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../recording/recording_bloc.dart';
import '../../recording/recording_csv.dart';
import '../../recording/recording_files.dart';
import '../../recording/viewer_bloc.dart';
import '../../router.dart';

/// Progress of a running recording, or save/discard actions once finished.
class RecordingBanner extends StatelessWidget {
  const RecordingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, state) => switch (state.status) {
        RecordingStatus.idle => const SizedBox.shrink(),
        RecordingStatus.recording => _Recording(state: state),
        RecordingStatus.finished => _Finished(state: state),
      },
    );
  }
}

String formatDuration(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class _Recording extends StatelessWidget {
  const _Recording({required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = state.info!;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.recordingActive(
                      info.identifier.isEmpty
                          ? info.name
                          : '${info.name} (${info.identifier})',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.read<RecordingBloc>().add(
                    const RecordingStopRequested(),
                  ),
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.actionStop),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 6),
            Text(
              '${formatDuration(state.elapsed)} / '
              '${formatDuration(info.duration)} · '
              '${l10n.sampleCount(state.samples.length)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});

  final RecordingState state;

  Future<void> _save(BuildContext context) async {
    final bloc = context.read<RecordingBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final info = state.info!;
    try {
      final saved = await saveCsvFile(
        suggestedFileName(info, state.startedAt!),
        recordingToCsv(state.toRecording()),
      );
      if (!saved) return;
      bloc.add(const RecordingDiscarded());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordingSaved(info.name))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed('$e'))));
    }
  }

  void _show(BuildContext context) {
    context.read<RecordingViewerBloc>().add(
      RecordingViewerShown(state.toRecording()),
    );
    context.push(Routes.recording);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = state.info!;
    final hasSamples = state.samples.isNotEmpty;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.recordingFinished(info.name),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${l10n.sampleCount(state.samples.length)} · '
                        '${formatDuration(state.elapsed)}'
                        '${state.stopReason == null ? '' : ' · ${l10n.stopReason(state.stopReason!)}'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => context.read<RecordingBloc>().add(
                    const RecordingDiscarded(),
                  ),
                  child: Text(l10n.actionDiscard),
                ),
                OutlinedButton.icon(
                  onPressed: hasSamples ? () => _show(context) : null,
                  icon: const Icon(Icons.show_chart),
                  label: Text(l10n.actionShow),
                ),
                FilledButton.icon(
                  onPressed: hasSamples ? () => _save(context) : null,
                  icon: const Icon(Icons.save_alt),
                  label: Text(l10n.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

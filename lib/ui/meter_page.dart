import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/meter_bloc.dart';
import '../compact/compact_mode_cubit.dart';
import '../fluke/qdda.dart';
import '../l10n/l10n.dart';
import '../recording/recording_bloc.dart';
import '../router.dart';
import 'meter_properties_dialog.dart';
import 'recording_dialog.dart';
import 'recording_page.dart';
import 'widgets/history_chart.dart';
import 'widgets/meter_properties_card.dart';
import 'widgets/primary_display.dart';
import 'widgets/reading_card.dart';
import 'widgets/recording_banner.dart';
import 'widgets/status_chips.dart';
import 'widgets/window_app_bar.dart';
import 'widgets/bar_actions.dart';

class MeterPage extends StatelessWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeterBloc, MeterState>(
      builder: (context, state) {
        final identity = state.identity;
        return Scaffold(
          appBar: WindowAppBar(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(identity?.model ?? MeterModel.supportedLabel),
                  if (identity != null)
                    // Builder: the bar's text color, not the page's.
                    Builder(
                      builder: (context) => Text(
                        'FW ${identity.firmware} · SN ${identity.serial}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DefaultTextStyle.of(context).style.color,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                BarActions(
                  leading: [
                    if (state.warning != null)
                      Tooltip(
                        message: context.l10n.error(state.warning!),
                        child: Icon(
                          Icons.warning_amber,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const _RecordButton(),
                  ],
                  actions: [
                    if (context.read<CompactModeCubit>().available)
                      BarAction(
                        icon: Icons.picture_in_picture_alt,
                        label: context.l10n.compactViewTooltip,
                        pinned: true,
                        onPressed: () => _enterCompact(context),
                      ),
                    BarAction(
                      icon: Icons.sd_storage_outlined,
                      label: context.l10n.meterMemory,
                      onPressed: () => context.push(Routes.memory),
                    ),
                    BarAction(
                      icon: Icons.folder_open,
                      label: context.l10n.actionOpenRecording,
                      onPressed: () => openRecordingFile(context),
                    ),
                    BarAction(
                      icon: Icons.link_off,
                      label: context.l10n.actionDisconnect,
                      onPressed: () => context.read<MeterBloc>().add(
                        const MeterDisconnectRequested(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: !state.isConnected
              // Only reachable when the connection dropped while another
              // page (e.g. a recording) was pushed on top of this one.
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_off, size: 48),
                      const SizedBox(height: 12),
                      Text(context.l10n.notConnected),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(Routes.connect),
                        child: Text(context.l10n.backToDeviceSelection),
                      ),
                    ],
                  ),
                )
              : state.display == null
              ? const Center(child: CircularProgressIndicator())
              : _MeterBody(state: state),
        );
      },
    );
  }
}

Future<void> _enterCompact(BuildContext context) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await context.read<CompactModeCubit>().enter();
    router.go(Routes.compact);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.compactViewUnavailable('$e'))),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton();

  Future<void> _start(BuildContext context) async {
    final bloc = context.read<RecordingBloc>();
    final info = await showRecordingDialog(context);
    if (info != null) bloc.add(RecordingStartRequested(info));
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select((RecordingBloc b) => b.state.status);
    return switch (status) {
      RecordingStatus.recording => IconButton(
        tooltip: context.l10n.recordingStopTooltip,
        icon: const Icon(Icons.stop_circle, color: Colors.red),
        onPressed: () =>
            context.read<RecordingBloc>().add(const RecordingStopRequested()),
      ),
      RecordingStatus.idle => IconButton(
        tooltip: context.l10n.recordingStartTooltip,
        icon: const Icon(Icons.fiber_manual_record),
        onPressed: () => _start(context),
      ),
      // A finished recording must be saved or discarded first.
      RecordingStatus.finished => IconButton(
        tooltip: context.l10n.recordingSaveOrDiscardFirst,
        icon: const Icon(Icons.fiber_manual_record),
        onPressed: null,
      ),
    };
  }
}

class _MeterBody extends StatelessWidget {
  const _MeterBody({required this.state});

  final MeterState state;

  @override
  Widget build(BuildContext context) {
    final display = state.display!;
    final extras = [for (final id in extraReadingIds) ?display.reading(id)];

    final properties = state.properties;
    final propertiesCard = properties == null
        ? null
        : MeterPropertiesCard(
            properties: properties,
            onEdit: () => showMeterPropertiesDialog(
              context,
              context.read<MeterBloc>(),
              properties,
            ),
          );

    final extrasWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final r in extras) ReadingCard(reading: r)],
    );

    final statusAndExtras = [
      if (StatusChips.hasChips(display)) StatusChips(display: display),
      if (extras.isNotEmpty) extrasWrap,
    ].separatedBy(const SizedBox(height: 12));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: readings in one row, the chart below fills the rest.
        if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 640) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RecordingBanner(),
                // Live display and meter info side by side, equally tall;
                // modes and extra readings below them.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: PrimaryDisplay(display: display),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child:
                            propertiesCard ??
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: statusAndExtras,
                            ),
                      ),
                    ],
                  ),
                ),
                if (propertiesCard != null && statusAndExtras.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...statusAndExtras,
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: HistoryChart(history: state.history, expand: true),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const RecordingBanner(),
            PrimaryDisplay(display: display),
            if (StatusChips.hasChips(display)) ...[
              const SizedBox(height: 12),
              StatusChips(display: display),
            ],
            if (extras.isNotEmpty) ...[const SizedBox(height: 12), extrasWrap],
            const SizedBox(height: 12),
            HistoryChart(history: state.history, height: 360),
            if (propertiesCard != null) ...[
              const SizedBox(height: 12),
              propertiesCard,
            ],
          ],
        );
      },
    );
  }
}

extension on List<Widget> {
  /// The widgets with [separator] between each two.
  List<Widget> separatedBy(Widget separator) => [
    for (final (i, widget) in indexed) ...[if (i > 0) separator, widget],
  ];
}

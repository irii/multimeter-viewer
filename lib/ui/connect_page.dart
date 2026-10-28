import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../about/app_info.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/meter_bloc.dart';
import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/qdda.dart';
import '../l10n/l10n.dart';
import 'recording_page.dart';
import 'widgets/recording_banner.dart';
import 'widgets/window_app_bar.dart';
import 'widgets/bar_actions.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scanning = context.select((DiscoveryBloc b) => b.state.scanning);
    return BlocListener<DiscoveryBloc, DiscoveryState>(
      // Each completed scan that changes the meters, and the first one.
      listenWhen: (previous, current) =>
          previous.scanned != current.scanned ||
          !_sameIds(previous.meters, current.meters),
      listener: _autoSelect,
      child: Scaffold(
        appBar: WindowAppBar(
          appBar: AppBar(
            title: const Text(AppInfo.name),
            actions: [
              BarActions(
                actions: [
                  BarAction(
                    icon: Icons.folder_open,
                    label: l10n.actionOpenRecording,
                    onPressed: () => openRecordingFile(context),
                  ),
                  BarAction(
                    icon: Icons.refresh,
                    label: l10n.actionRescan,
                    pinned: true,
                    onPressed: scanning
                        ? null
                        : () => context.read<DiscoveryBloc>().add(
                            const DiscoveryScanRequested(),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                RecordingBanner(),
                _MeterList(),
                _ConnectError(),
                SizedBox(height: 24),
                _OpenRecordingCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Android: connects right away when exactly one meter is available.
  /// The first scan of the page only does so if the user did not just
  /// disconnect; later, a newly appearing meter (e.g. a re-plugged cable)
  /// always counts as a request to connect.
  static void _autoSelect(BuildContext context, DiscoveryState state) {
    final discovery = context.read<DiscoveryBloc>();
    final meter = context.read<MeterBloc>();
    if (!state.scanned) return;
    final firstScan = discovery.takeFirstMeterScan();
    if (!discovery.autoSelectSingle || state.meters.length != 1) return;
    final meterState = meter.state;
    if (meterState.status == MeterStatus.connecting || meterState.isConnected) {
      return;
    }
    if (firstScan &&
        (meterState.disconnectedByUser ||
            meterState.status == MeterStatus.failure)) {
      return;
    }
    meter.add(MeterConnectRequested(state.meters.single));
  }

  static bool _sameIds(List<MeterCandidate> a, List<MeterCandidate> b) =>
      a.length == b.length &&
      a.map((c) => c.id).toSet().containsAll(b.map((c) => c.id));
}

class _MeterList extends StatelessWidget {
  const _MeterList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discovery = context.watch<DiscoveryBloc>();
    final state = discovery.state;
    final meterState = context.watch<MeterBloc>().state;
    final connecting = meterState.status == MeterStatus.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.availableMeters,
          subtitle: l10n.connectInstructions,
          busy: state.scanning,
        ),
        if (state.error != null)
          _StatusMessage(
            icon: Icons.error_outline,
            error: true,
            title: l10n.scanFailed,
            message:
                '${l10n.error(state.error!)}\n'
                        '${l10n.connectionHint(state.error) ?? ''}'
                    .trim(),
          )
        else if (state.scanned && state.meters.isEmpty)
          _StatusMessage(
            icon: Icons.search_off,
            title: l10n.noMeterFound(MeterModel.supportedLabel),
            message: l10n.noMeterFoundHint,
          )
        else if (!state.scanned)
          _StatusMessage(icon: Icons.search, title: l10n.searchingMeters),
        for (final meter in state.meters)
          _MeterTile(
            candidate: meter,
            connecting: connecting,
            // Scans and connects are serialized by the discovery.
            enabled: !connecting,
          ),
        if (state.cablesWithoutMeter.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.cablesWithoutMeter, small: true),
          Card.outlined(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final cable in state.cablesWithoutMeter)
                  ListTile(
                    leading: const Icon(Icons.cable),
                    title: Text(cable.cableName),
                    subtitle: Text(_cableProblem(l10n, cable.error)),
                  ),
              ],
            ),
          ),
        ],
        if (discovery.canRequestDevice) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: state.scanning
                  ? null
                  : () => context.read<DiscoveryBloc>().add(
                      const DiscoveryDeviceRequested(),
                    ),
              icon: const Icon(Icons.add_link),
              label: Text(l10n.grantUsbCable),
            ),
          ),
        ],
      ],
    );
  }
}

/// Title above a group of items, with an optional explanation and a small
/// progress indicator while that group is being refreshed.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.busy = false,
    this.small = false,
  });

  final String title;
  final String? subtitle;
  final bool busy;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, small ? 0 : 8, 4, small ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: small
                      ? theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.titleLarge,
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder shown instead of the meters: searching, nothing found or a
/// failed scan.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    this.message,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = this.message;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: error
                ? scheme.errorContainer
                : scheme.surfaceContainerHighest,
            foregroundColor: error
                ? scheme.onErrorContainer
                : scheme.onSurfaceVariant,
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  const _MeterTile({
    required this.candidate,
    required this.connecting,
    required this.enabled,
  });

  final MeterCandidate candidate;
  final bool connecting;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final identity = candidate.identity!;
    final supported = identity.meterModel.isSupported;
    final scheme = Theme.of(context).colorScheme;
    void connect() =>
        context.read<MeterBloc>().add(MeterConnectRequested(candidate));

    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        onTap: enabled ? connect : null,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: supported
                ? scheme.primaryContainer
                : scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            supported ? Icons.speed : Icons.help_outline,
            color: supported
                ? scheme.onPrimaryContainer
                : scheme.onTertiaryContainer,
          ),
        ),
        title: Text(identity.model),
        subtitle: Text(
          'SN ${identity.serial} · FW ${identity.firmware}\n'
          '${l10n.cableName(candidate.cableName)}'
          '${supported ? '' : '\n${l10n.modelUntested}'}',
        ),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: enabled ? connect : null,
          child: connecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionConnect),
        ),
      ),
    );
  }
}

class _OpenRecordingCard extends StatelessWidget {
  const _OpenRecordingCard();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.insert_chart_outlined),
        title: Text(context.l10n.openSavedRecording),
        subtitle: Text(context.l10n.openSavedRecordingSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openRecordingFile(context),
      ),
    );
  }
}

class _ConnectError extends StatelessWidget {
  const _ConnectError();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeterBloc>().state;
    final failure = state.failure;
    if (state.status != MeterStatus.failure || failure == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final message = l10n.meterFailure(failure);
    final hint = l10n.connectionHint(failure.cause);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Text(
                l10n.connectionFailed,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: TextStyle(color: scheme.onErrorContainer)),
          ],
        ],
      ),
    );
  }
}

/// Why a cable has no usable meter, with advice where there is some.
String _cableProblem(AppLocalizations l10n, Object? error) {
  if (error == null || error is FlukeTimeoutException) {
    return l10n.noMeterResponds;
  }
  final hint = l10n.connectionHint(error);
  return hint == null ? l10n.error(error) : '${l10n.error(error)}\n$hint';
}

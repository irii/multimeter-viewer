import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../fluke/fluke_client.dart';
import '../l10n/l10n.dart';
import '../router.dart';
import '../usb/usb_meter_discovery.dart';
import 'mono_font.dart';
import 'widgets/window_app_bar.dart';

/// Raw view of what a cable or adapter sends and receives, for debugging
/// the IR adapter. Meter discovery is paused while this page is shown: it
/// only runs on the connect page, which this page replaces.
class SerialMonitorPage extends StatefulWidget {
  const SerialMonitorPage({super.key});

  @override
  State<SerialMonitorPage> createState() => _SerialMonitorPageState();
}

class _SerialMonitorPageState extends State<SerialMonitorPage> {
  static const _quickCommands = ['ID', 'QDDA', 'qmpq operator'];

  final _command = TextEditingController(text: 'ID');
  final _clock = Stopwatch()..start();
  final List<_LogEntry> _log = [];

  List<SerialPortInfo>? _ports;
  String? _portId;
  SerialChannel? _channel;
  bool _busy = false;
  Object? _error;

  UsbMeterDiscovery get _usb => context.read<UsbMeterDiscovery?>()!;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
  }

  @override
  void dispose() {
    _channel?.close();
    _channel = null;
    _command.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPorts() => _run(() async {
    final ports = await _usb.listSerialPorts();
    if (!mounted) return;
    setState(() {
      _ports = ports;
      if (!ports.any((p) => p.id == _portId)) {
        _portId = ports.isEmpty ? null : ports.first.id;
      }
    });
  });

  Future<void> _open() => _run(() async {
    final id = _portId;
    if (id == null) return;
    final channel = await _usb.openSerialPort(id);
    if (!mounted) {
      await channel.close();
      return;
    }
    setState(() => _channel = channel);
    unawaited(_readLoop(channel));
  });

  Future<void> _close() async {
    final channel = _channel;
    setState(() => _channel = null);
    await channel?.close();
  }

  /// Reads until the channel is closed or replaced.
  Future<void> _readLoop(SerialChannel channel) async {
    while (identical(_channel, channel)) {
      final List<int> data;
      try {
        data = await channel.read();
      } catch (e) {
        if (identical(_channel, channel) && mounted) {
          setState(() => _error = e);
          await _close();
        }
        return;
      }
      if (!identical(_channel, channel) || !mounted) return;
      if (data.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      } else {
        setState(() => _log.add(_LogEntry(_clock.elapsed, false, data)));
      }
    }
  }

  Future<void> _send(String command) async {
    final channel = _channel;
    if (channel == null || command.isEmpty) return;
    final List<int> bytes;
    try {
      bytes = latin1.encode('$command\r');
    } on ArgumentError catch (e) {
      setState(() => _error = e);
      return;
    }
    final sentAt = _clock.elapsed;
    setState(() => _log.add(_LogEntry(sentAt, true, bytes)));
    try {
      await channel.write(bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _logText() => _log.map((e) => e.format(_sentBefore(e))).join('\n');

  /// When the last command before [entry] was sent.
  Duration? _sentBefore(_LogEntry entry) {
    for (final e in _log.reversed) {
      if (e.sent && e.time <= entry.time && !identical(e, entry)) {
        return e.time;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = _channel != null;
    final ports = _ports ?? const [];

    return Scaffold(
      appBar: WindowAppBar(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go(Routes.connect)),
          title: Text(l10n.serialMonitor),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: l10n.serialMonitorCopy,
              onPressed: _log.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _logText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.serialMonitorCopied)),
                      );
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.serialMonitorClear,
              onPressed: _log.isEmpty ? null : () => setState(_log.clear),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.serialMonitorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _portId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.serialMonitorPort,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: Text(l10n.serialMonitorNoPorts),
                    items: [
                      for (final p in ports)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: open || _busy
                        ? null
                        : (id) => setState(() => _portId = id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: open || _busy ? null : _refreshPorts,
                ),
                const SizedBox(width: 4),
                open
                    ? OutlinedButton(
                        onPressed: _close,
                        child: Text(l10n.serialMonitorClose),
                      )
                    : FilledButton(
                        onPressed: _busy || _portId == null ? null : _open,
                        child: Text(l10n.serialMonitorOpen),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _command,
                    enabled: open,
                    decoration: InputDecoration(
                      labelText: l10n.serialMonitorCommand,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: open ? () => _send(_command.text) : null,
                  child: Text(l10n.serialMonitorSend),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _quickCommands)
                  ActionChip(
                    label: Text(c),
                    onPressed: open
                        ? () {
                            _command.text = c;
                            _send(c);
                          }
                        : null,
                  ),
              ],
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                l10n.error(error),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Card.outlined(
                margin: EdgeInsets.zero,
                child: _log.isEmpty
                    ? Center(child: Text(l10n.serialMonitorEmpty))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: _log.length,
                        itemBuilder: (context, i) {
                          final entry = _log[_log.length - 1 - i];
                          return SelectableText(
                            entry.format(_sentBefore(entry)),
                            style: TextStyle(
                              fontFamily: monoFontFamily,
                              fontFamilyFallback: monoFontFamilyFallback,
                              fontSize: 12,
                              color: entry.sent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One write, or one chunk as it arrived from the cable or adapter.
class _LogEntry {
  _LogEntry(this.time, this.sent, List<int> bytes)
    : bytes = List.unmodifiable(bytes);

  /// Since the page was opened.
  final Duration time;
  final bool sent;
  final List<int> bytes;

  /// `12.345 s  +3.1 ms  RX  30 0d 46  |0.F|`; the delay is counted from
  /// [sentAt], the last command before this chunk.
  String format(Duration? sentAt) {
    final seconds = (time.inMicroseconds / 1e6).toStringAsFixed(3);
    final delay = !sent && sentAt != null
        ? '+${((time - sentAt).inMicroseconds / 1000).toStringAsFixed(1)} ms'
        : '';
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final text = String.fromCharCodes(
      bytes.map((b) => b >= 0x20 && b < 0x7f ? b : 0x2e),
    );
    return '${seconds.padLeft(8)} s  ${delay.padLeft(10)}  '
        '${sent ? 'TX' : 'RX'}  $hex  |$text|';
  }
}

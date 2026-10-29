import 'dart:async';
import 'dart:convert';

import 'package:multimeter_viewer/compact/compact_window.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/fluke/fluke_memory_reader.dart';
import 'package:multimeter_viewer/recording/recording.dart';
import 'package:multimeter_viewer/fluke/meter_discovery.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:multimeter_viewer/settings/settings_cubit.dart';

export 'package:multimeter_viewer/settings/settings_store.dart'
    show MemorySettingsStore;

/// Made-up readings in the QDDA response format.
const sampleQdda =
    'MV_AC,NONE,AUTO,VAC,50,-3,OFF,0.000,0,2,'
    'LIVE,0.007312,VAC,-3,3,5,NORMAL,NONE,1793196900.250,'
    'PRIMARY,0.007312,VAC,-3,3,5,NORMAL,NONE,1793196900.250';

/// Made-up readings with MIN MAX active.
const sampleQddaMinMax =
    'MV_AC,PEAK_MIN_MAX,AUTO,VAC,50,-3,OFF,1793197020.400,1,MIN_MAX_AVG,5,'
    'LIVE,0.00648,VAC,-3,2,5,NORMAL,NONE,1793197029.600,'
    'PRIMARY,0.00648,VAC,-3,2,5,NORMAL,NONE,1793197029.600,'
    'MINIMUM,-0.0187,V,-3,2,5,NORMAL,NONE,1793197021.200,'
    'MAXIMUM,0.02764,V,-3,2,5,NORMAL,NONE,1793197020.900,'
    'AVERAGE,0.00612,VAC,-3,2,5,NORMAL,NONE,1793197029.600';

/// Serial channel returning pre-scripted chunks.
class FakeChannel implements SerialChannel {
  final List<List<int>> chunks = [];
  final List<String> written = [];
  final removed = StreamController<void>.broadcast();
  bool closed = false;

  void respond(String text) => chunks.add(ascii.encode(text));

  @override
  Future<void> write(List<int> data) async => written.add(ascii.decode(data));

  @override
  Future<List<int>> read() async =>
      chunks.isEmpty ? const [] : chunks.removeAt(0);

  @override
  Stream<void> get onRemoved => removed.stream;

  @override
  Future<void> close() async => closed = true;
}

/// Meter link whose QDDA answers come from [responses] (Object = error).
class FakeLink implements MeterLink {
  FakeLink({
    this.responses = const [],
    this.meterIdentity = identity,
    this.properties = const MeterProperties(),
  });

  final List<Object> responses;

  /// Identity this fake answers `ID` with.
  final MeterIdentity meterIdentity;

  /// Owner texts this fake has stored.
  MeterProperties properties;

  @override
  Future<MeterProperties> readProperties() async => properties;

  /// `mpq` commands this fake received, as `name=value`.
  final written = <String>[];

  @override
  Future<void> writeProperty(String name, String value) async {
    written.add('$name=$value');
    properties = MeterProperties.fromMap({
      for (final n in MeterProperties.names)
        n: n == name ? value : properties[n],
    });
  }

  final removed = StreamController<void>.broadcast();
  int _index = 0;
  int _polls = 0;

  static String _liveExample(int poll) {
    final t = (1793196900.250 + poll * 0.2).toStringAsFixed(3);
    return 'MV_AC,NONE,AUTO,VAC,50,-3,OFF,0.000,0,2,'
        'LIVE,0.007312,VAC,-3,3,5,NORMAL,NONE,$t,'
        'PRIMARY,0.007312,VAC,-3,3,5,NORMAL,NONE,$t';
  }

  bool closed = false;

  static const identity = MeterIdentity(
    model: 'FLUKE 289',
    firmware: 'V1.00',
    serial: '40211337',
  );

  /// Memory of this fake meter.
  @override
  FakeMemory memory = FakeMemory();

  @override
  Future<MeterIdentity> identify() async => meterIdentity;

  @override
  Future<QddaResponse> queryDisplay() async {
    final r = responses.isEmpty
        ? _liveExample(_polls++)
        : responses[_index < responses.length
              ? _index++
              : responses.length - 1];
    if (r is String) return QddaResponse.parse(r);
    throw r;
  }

  @override
  Stream<void> get onRemoved => removed.stream;

  @override
  Future<void> close() async => closed = true;
}

const fluke287Identity = MeterIdentity(
  model: 'FLUKE 287',
  firmware: 'V2.02',
  serial: '12345678',
);

const fake287Candidate = MeterCandidate(
  id: '403:6001:B7',
  cableName: 'FT232R USB UART (B7)',
  identity: fluke287Identity,
);

const fakeCandidate = MeterCandidate(
  id: '403:6001:A1',
  cableName: 'FT232R USB UART (A1)',
  identity: FakeLink.identity,
);

/// Discovery returning [candidates]; [connect] hands out [link].
class FakeDiscovery implements MeterDiscovery {
  FakeDiscovery({this.candidates = const [fakeCandidate], FakeLink? link})
    : link = link ?? FakeLink();

  List<MeterCandidate> candidates;
  final FakeLink link;
  final changes = StreamController<void>.broadcast();
  int scans = 0;
  Object? scanError;

  @override
  bool get canRequestDevice => false;

  /// Like Android when `true`.
  @override
  bool autoSelectSingle = false;

  @override
  Future<List<MeterCandidate>> scan() async {
    scans++;
    if (scanError != null) throw scanError!;
    return candidates;
  }

  @override
  Future<void> requestDevice() async {}

  @override
  Future<MeterLink> connect(MeterCandidate candidate) async => link;

  @override
  Stream<void> get onDevicesChanged => changes.stream;
}

/// Records the window operations of the compact view.
class FakeCompactWindow implements CompactWindow {
  FakeCompactWindow({this.hasControls = true});

  final List<String> calls = [];

  /// `false` behaves like Android's picture-in-picture window.
  @override
  final bool hasControls;

  /// Add to it to simulate the system ending the compact view.
  final closedBySystem = StreamController<void>.broadcast();

  @override
  Stream<void> get onClosedBySystem => closedBySystem.stream;

  @override
  Future<void> enterCompact() async => calls.add('enter');

  @override
  Future<void> exitCompact() async => calls.add('exit');

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async =>
      calls.add('onTop:$alwaysOnTop');
}

/// The existing widget tests check German texts.
const germanSettings = AppSettings(language: AppLanguage.de);

/// Meter memory with fixed [contents]; recordings download as [recording]
/// (sample by sample, so progress and cancelling can be tested).
class FakeMemory implements MeterMemory {
  FakeMemory({this.contents = const MemoryContents(), this.recording});

  MemoryContents contents;
  Recording? recording;
  Object? readError;

  /// Delay per downloaded sample.
  Duration sampleDelay = Duration.zero;

  @override
  Future<MemoryContents> readContents() async {
    if (readError != null) throw readError!;
    return contents;
  }

  @override
  Future<Recording> downloadRecording(
    MemoryRecording recording, {
    MeterIdentity? identity,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final result = this.recording!;
    final total = result.samples.length;
    onProgress?.call(0, total);
    for (var i = 0; i < total; i++) {
      if (isCancelled?.call() ?? false) throw const MemoryDownloadCancelled();
      await Future<void>.delayed(sampleDelay);
      onProgress?.call(i + 1, total);
    }
    return result;
  }
}

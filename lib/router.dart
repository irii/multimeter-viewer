import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'bloc/discovery_bloc.dart';
import 'bloc/memory_bloc.dart';
import 'bloc/meter_bloc.dart';
import 'fluke/meter_discovery.dart';
import 'ui/about_page.dart';
import 'ui/compact_page.dart';
import 'ui/licenses_page.dart';
import 'ui/connect_page.dart';
import 'ui/memory_page.dart';
import 'ui/meter_page.dart';
import 'ui/recording_page.dart';

abstract final class Routes {
  static const connect = '/';
  static const meter = '/meter';

  /// Recorded data; reachable with or without a meter connection.
  static const recording = '/recording';

  /// Minimal always-on-top value panel (desktop, Android PiP).
  static const compact = '/compact';

  /// Recordings and measurements stored in the meter.
  static const memory = '/memory';

  static const about = '/about';
  static const licenses = '/licenses';
}

GoRouter createRouter(MeterBloc bloc) => GoRouter(
  initialLocation: Routes.connect,
  refreshListenable: _StreamListenable(
    bloc.stream.map((s) => s.isConnected).distinct(),
  ),
  redirect: (context, state) {
    final connected = bloc.state.isConnected;
    final location = state.matchedLocation;
    if (connected && location == Routes.connect) return Routes.meter;
    if (!connected &&
        (location == Routes.meter ||
            location == Routes.compact ||
            location == Routes.memory)) {
      return Routes.connect;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: Routes.connect,
      // Scoped to the route: discovery only runs (and probes cables) while
      // the connect page is shown.
      builder: (context, state) => BlocProvider(
        create: (context) =>
            DiscoveryBloc(discovery: context.read<MeterDiscovery>())
              ..add(const DiscoveryScanRequested()),
        child: const ConnectPage(),
      ),
    ),
    GoRoute(path: Routes.meter, builder: (context, state) => const MeterPage()),
    GoRoute(
      path: Routes.memory,
      // Scoped to the route; reads the memory of the open connection.
      builder: (context, state) => BlocProvider(
        create: (context) {
          final meter = context.read<MeterBloc>();
          return MemoryBloc(
            memory: meter.link!.memory,
            identity: meter.state.identity,
          )..add(const MemoryLoadRequested());
        },
        child: const MemoryPage(),
      ),
    ),
    GoRoute(path: Routes.about, builder: (context, state) => const AboutPage()),
    GoRoute(
      path: Routes.licenses,
      builder: (context, state) => const LicensesPage(),
    ),
    GoRoute(
      path: Routes.compact,
      builder: (context, state) => const CompactPage(),
    ),
    GoRoute(
      path: Routes.recording,
      builder: (context, state) => const RecordingPage(),
    ),
  ],
);

/// Re-runs the router's redirect whenever [stream] emits.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

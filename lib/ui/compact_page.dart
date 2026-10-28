import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../bloc/meter_bloc.dart';
import '../compact/compact_mode_cubit.dart';
import '../fluke/qdda.dart';
import '../l10n/l10n.dart';
import '../recording/recording_bloc.dart';
import '../router.dart';
import 'mono_font.dart';
import 'widgets/reading_card.dart' show extraReadingIds;
import 'widgets/background_chart.dart';

/// Minimal always-on-top panel with just the readings: a small desktop
/// window or Android's picture-in-picture window.
class CompactPage extends StatelessWidget {
  const CompactPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget content = const _CompactContent();
    // macOS keeps native resize edges with a hidden title bar; Windows and
    // Linux lose the frame, so provide resize edges ourselves.
    if (context.read<CompactModeCubit>().hasControls &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      content = DragToResizeArea(child: content);
    }
    // Back to the normal view however the compact view ended (button,
    // picture-in-picture expanded or closed, meter disconnected).
    return BlocListener<CompactModeCubit, CompactModeState>(
      listenWhen: (previous, current) => previous.active && !current.active,
      listener: (context, state) => context.go(Routes.meter),
      child: Scaffold(body: content),
    );
  }
}

class _CompactContent extends StatefulWidget {
  const _CompactContent();

  @override
  State<_CompactContent> createState() => _CompactContentState();
}

class _CompactContentState extends State<_CompactContent> {
  bool _hover = false;

  Future<void> _restore() => context.read<CompactModeCubit>().exit();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = context.watch<MeterBloc>().state;
    final cubit = context.watch<CompactModeCubit>();
    final compact = cubit.state;
    final recording =
        context.select((RecordingBloc b) => b.state.status) ==
        RecordingStatus.recording;
    final display = state.display;
    final primary = display?.primary;
    final secondary = display?.reading('SECONDARY');
    // Min/max/avg, references ... and the live value where it differs from
    // the main one (REL, HOLD); otherwise it would just repeat it.
    final extras = [
      for (final id in const ['LIVE', 'REL_LIVE', ...extraReadingIds])
        if (display?.reading(id) case final r?)
          if (!id.endsWith('LIVE') ||
              r.displayText != primary?.displayText ||
              r.unitText != primary?.unitText)
            r,
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackgroundChart(history: state.history),
          // Only the readings move the window: the drag area also handles
          // double clicks, which would delay taps on the buttons.
          _movable(
            cubit.hasControls,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: _ScaleBelowHeight(
                height: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (recording) ...[
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            display == null
                                ? (state.identity?.model ?? '')
                                : [
                                    l10n.primaryFunction(
                                      display.primaryFunction,
                                    ),
                                    ...display.modes.map(l10n.mode),
                                  ].join(' · '),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (display?.lightningBolt ?? false)
                          Icon(
                            Icons.bolt,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                      ],
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              primary?.fixedWidthDisplayText ??
                                  withSignColumn('----'),
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontFamily: monoFontFamily,
                                fontFamilyFallback: monoFontFamilyFallback,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              primary?.unitText ?? '',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (secondary != null)
                      Text(
                        '${secondary.signedDisplayText} ${secondary.unitText}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: monoFontFamily,
                          fontFamilyFallback: monoFontFamilyFallback,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (extras.isNotEmpty) _ExtraReadings(readings: extras),
                    if (state.warning != null)
                      Text(
                        l10n.error(state.warning!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (cubit.hasControls)
            Positioned(
              top: 2,
              right: 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hover ? 1 : 0.35,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: compact.alwaysOnTop
                          ? l10n.alwaysOnTopOff
                          : l10n.alwaysOnTopOn,
                      isSelected: compact.alwaysOnTop,
                      icon: const Icon(Icons.push_pin_outlined),
                      selectedIcon: const Icon(Icons.push_pin),
                      onPressed: () =>
                          context.read<CompactModeCubit>().toggleAlwaysOnTop(),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: l10n.normalView,
                      icon: const Icon(Icons.open_in_full),
                      onPressed: _restore,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lays out [child] at least [height] high and scales it down to fit a
/// smaller panel (e.g. Android's picture-in-picture window), so small panels
/// show the same lines as large ones instead of dropping some.
class _ScaleBelowHeight extends StatelessWidget {
  const _ScaleBelowHeight({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight >= height) return child;
      final scale = constraints.maxHeight / height;
      return FittedBox(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: constraints.maxWidth / scale,
          height: height,
          child: child,
        ),
      );
    },
  );
}

/// Lets the panel be dragged around where the window can be moved.
Widget _movable(bool movable, Widget child) =>
    movable ? DragToMoveArea(child: child) : child;

/// One line of small readings below the main value, e.g.
/// `Min 4.998 V  Max 5.031 V  Ø 5.012 V`. Shrinks to fit instead of
/// wrapping, so the panel layout stays the same.
class _ExtraReadings extends StatelessWidget {
  const _ExtraReadings({required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelMedium?.copyWith(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFamilyFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final (i, r) in readings.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Text(l10n.readingIdShort(r.id), style: labelStyle),
              const SizedBox(width: 4),
              Text('${r.signedDisplayText} ${r.unitText}', style: valueStyle),
            ],
          ],
        ),
      ),
    );
  }
}

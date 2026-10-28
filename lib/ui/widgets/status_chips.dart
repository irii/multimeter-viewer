import 'package:flutter/material.dart';

import '../../fluke/qdda.dart';
import '../../l10n/l10n.dart';

/// Range, active modes and MIN MAX start time as chips.
class StatusChips extends StatelessWidget {
  const StatusChips({super.key, required this.display});

  final QddaResponse display;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final minMaxStart = display.minMaxStart;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(
            display.range.autoRange ? Icons.auto_mode : Icons.tune,
            size: 18,
          ),
          label: Text(
            '${display.range.autoRange ? l10n.rangeAuto : l10n.rangeManual} · '
            '${display.range.label}',
          ),
        ),
        for (final mode in display.modes)
          Chip(
            backgroundColor: scheme.secondaryContainer,
            label: Text(
              l10n.mode(mode),
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        if (minMaxStart != null)
          Chip(
            avatar: const Icon(Icons.schedule, size: 18),
            label: Text(l10n.minMaxSince(l10n.timeOfDay(minMaxStart))),
          ),
      ],
    );
  }
}

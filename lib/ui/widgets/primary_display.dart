import 'package:flutter/material.dart';

import '../../fluke/qdda.dart';
import '../../l10n/l10n.dart';
import '../mono_font.dart';

/// Large main reading plus the small secondary/live readings, like the
/// meter's LCD.
class PrimaryDisplay extends StatelessWidget {
  const PrimaryDisplay({super.key, required this.display});

  final QddaResponse display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = display.primary;
    final l10n = context.l10n;
    final secondaryFunction = l10n.secondaryFunction(display.secondaryFunction);
    final attribute = primary == null
        ? null
        : l10n.attribute(primary.attribute);
    final smallReadings = [
      for (final id in const ['SECONDARY', 'LIVE', 'REL_LIVE'])
        ?display.reading(id),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Shrinks first on narrow screens; the range stays readable.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: l10n.primaryFunction(display.primaryFunction),
                      children: [
                        if (secondaryFunction != null)
                          TextSpan(
                            text: '  · $secondaryFunction',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _RangeLabel(range: display.range),
                if (display.lightningBolt)
                  Tooltip(
                    message: l10n.dangerousVoltage,
                    child: Icon(Icons.bolt, color: theme.colorScheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    primary?.signedDisplayText ?? withSignColumn('----'),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontFamily: monoFontFamily,
                      fontFamilyFallback: monoFontFamilyFallback,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    primary?.unitText ?? '',
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            if (attribute != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  attribute,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (smallReadings.isNotEmpty) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final r in smallReadings) _SmallReading(reading: r),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Range like on the meter's display, e.g. "Auto · 5 V".
class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.range});

  final RangeData range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: l10n.rangeLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              range.autoRange ? Icons.auto_mode : Icons.tune,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '${range.autoRange ? l10n.rangeAuto : l10n.rangeManual} · '
              '${range.label}',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallReading extends StatelessWidget {
  const _SmallReading({required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.readingId(reading.id),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${reading.signedDisplayText} ${reading.unitText}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: monoFontFamily,
            fontFamilyFallback: monoFontFamilyFallback,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

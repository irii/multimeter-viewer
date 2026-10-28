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
                Text(
                  l10n.primaryFunction(display.primaryFunction),
                  style: theme.textTheme.titleMedium,
                ),
                if (secondaryFunction != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· $secondaryFunction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
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

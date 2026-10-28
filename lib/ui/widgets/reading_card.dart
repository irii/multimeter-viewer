import 'package:flutter/material.dart';

import '../../fluke/qdda.dart';
import '../../l10n/l10n.dart';
import '../mono_font.dart';

/// Reading IDs shown as separate cards below the main display.
const extraReadingIds = [
  'MINIMUM',
  'MAXIMUM',
  'AVERAGE',
  'REL_REFERENCE',
  'DB_REF',
  'TEMP_OFFSET',
];

class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key, required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.readingId(reading.id),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${reading.signedDisplayText} ${reading.unitText}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: monoFontFamily,
                    fontFamilyFallback: monoFontFamilyFallback,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../fluke/meter_properties.dart';
import '../../l10n/l10n.dart';

/// Company, operator, site and contact stored in the meter; only the
/// properties that are set. The pencil calls [onEdit].
class MeterPropertiesCard extends StatelessWidget {
  const MeterPropertiesCard({super.key, required this.properties, this.onEdit});

  final MeterProperties properties;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rows = [
      (Icons.business_outlined, l10n.propertyCompany, properties.company),
      (Icons.person_outline, l10n.propertyOperator, properties.operator),
      (Icons.place_outlined, l10n.propertySite, properties.site),
      (Icons.contact_mail_outlined, l10n.propertyContact, properties.contact),
    ];
    // Same card and title style as the primary display and the chart.
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.meterProperties,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: l10n.meterPropertiesEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
              ],
            ),
            if (properties.isEmpty)
              Text(
                l10n.meterPropertiesEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final (icon, label, value) in rows)
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: label,
                        child: Icon(
                          icon,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          value,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

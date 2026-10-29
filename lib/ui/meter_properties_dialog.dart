import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bloc/meter_bloc.dart';
import '../fluke/meter_properties.dart';
import '../l10n/l10n.dart';

/// Edits company, operator, site and contact and saves them in the meter.
Future<void> showMeterPropertiesDialog(
  BuildContext context,
  MeterBloc bloc,
  MeterProperties current,
) => showDialog<void>(
  context: context,
  builder: (context) => _MeterPropertiesDialog(bloc: bloc, current: current),
);

class _MeterPropertiesDialog extends StatefulWidget {
  const _MeterPropertiesDialog({required this.bloc, required this.current});

  final MeterBloc bloc;
  final MeterProperties current;

  @override
  State<_MeterPropertiesDialog> createState() => _MeterPropertiesDialogState();
}

class _MeterPropertiesDialogState extends State<_MeterPropertiesDialog> {
  late final _controllers = {
    for (final name in MeterProperties.names)
      name: TextEditingController(text: widget.current[name] ?? ''),
  };
  var _saving = false;
  Object? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.bloc.saveProperties(
        MeterProperties.fromMap({
          for (final MapEntry(key: name, value: controller)
              in _controllers.entries)
            name: controller.text,
        }),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      'company': (Icons.business_outlined, l10n.propertyCompany),
      'operator': (Icons.person_outline, l10n.propertyOperator),
      'site': (Icons.place_outlined, l10n.propertySite),
      'contact': (Icons.contact_mail_outlined, l10n.propertyContact),
    };
    return AlertDialog(
      icon: const Icon(Icons.edit_outlined),
      title: Text(l10n.meterPropertiesEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final name in MeterProperties.names) ...[
                TextField(
                  controller: _controllers[name],
                  enabled: !_saving,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      MeterProperties.allowedCharacters,
                    ),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: Icon(labels[name]!.$1),
                    labelText: labels[name]!.$2,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                l10n.meterPropertiesHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.saveFailed(l10n.error(_error!)),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionSave),
        ),
      ],
    );
  }
}

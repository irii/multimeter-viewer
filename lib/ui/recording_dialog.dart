import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../recording/recording.dart';

enum _DurationUnit {
  seconds(Duration(seconds: 1)),
  minutes(Duration(minutes: 1)),
  hours(Duration(hours: 1));

  const _DurationUnit(this.unit);

  final Duration unit;

  String label(AppLocalizations l10n) => switch (this) {
    seconds => l10n.unitSeconds,
    minutes => l10n.unitMinutes,
    hours => l10n.unitHours,
  };
}

/// Asks for name, identifier, comment and length of a new recording.
/// Returns `null` if cancelled.
Future<RecordingInfo?> showRecordingDialog(BuildContext context) =>
    showDialog<RecordingInfo>(
      context: context,
      builder: (context) => const _RecordingDialog(),
    );

class _RecordingDialog extends StatefulWidget {
  const _RecordingDialog();

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _comment = TextEditingController();
  final _length = TextEditingController(text: '5');
  var _unit = _DurationUnit.minutes;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _comment.dispose();
    _length.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      RecordingInfo(
        name: _name.text.trim(),
        identifier: _identifier.text.trim(),
        comment: _comment.text.trim(),
        duration: _unit.unit * int.parse(_length.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
      title: Text(l10n.newRecording),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.recordingNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.recordingNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _identifier,
                  decoration: InputDecoration(
                    labelText: l10n.identifierLabel,
                    hintText: l10n.identifierHint,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comment,
                  decoration: InputDecoration(
                    labelText: l10n.commentLabel,
                    border: const OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _length,
                        decoration: InputDecoration(
                          labelText: l10n.lengthLabel,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n <= 0
                              ? l10n.lengthInvalid
                              : null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_DurationUnit>(
                        initialValue: _unit,
                        decoration: InputDecoration(
                          labelText: l10n.durationUnitLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final u in _DurationUnit.values)
                            DropdownMenuItem(
                              value: u,
                              child: Text(u.label(l10n)),
                            ),
                        ],
                        onChanged: (u) => setState(() => _unit = u!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.fiber_manual_record),
          label: Text(l10n.recordingStartTooltip),
        ),
      ],
    );
  }
}

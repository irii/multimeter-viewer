import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../meter/model/model.dart';

/// Switches a capability or one of its subfunctions on the meter.
typedef CapabilitySetter = void Function(
  String id, {
  String? subFunction,
  required bool active,
});

/// The active measurement mode with a menu of all modes, its subfunctions as
/// switches, and the MIN MAX start time. What the app cannot set only shows
/// its state.
class CapabilityPanel extends StatelessWidget {
  const CapabilityPanel({
    super.key,
    required this.capabilities,
    required this.display,
    required this.onSet,
  });

  final MeterCapabilities capabilities;
  final MeterDisplay display;
  final CapabilitySetter onSet;

  bool _isActive(MeterSubFunction sub) => switch (sub.kind) {
    MeterSubFunctionKind.secondary => display.secondaryFunction == sub.id,
    MeterSubFunctionKind.mode => display.modes.contains(sub.id),
    MeterSubFunctionKind.action => false,
  };

  /// The subfunctions of the active mode, plus whatever else the meter reports
  /// as active, so nothing it does stays hidden.
  List<MeterSubFunction> _subFunctions(MeterCapability? current) {
    final declared = current?.subFunctions ?? const <MeterSubFunction>[];
    bool isDeclared(String id) => declared.any((sub) => sub.id == id);
    final secondary = display.secondaryFunction;
    return [
      ...declared,
      if (secondary != 'NONE' && !isDeclared(secondary))
        MeterSubFunction(secondary, MeterSubFunctionKind.secondary),
      for (final mode in display.modes)
        if (!isDeclared(mode))
          MeterSubFunction(mode, MeterSubFunctionKind.mode),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = capabilities.measurement(display.primaryFunction);
    final minMaxStart = display.minMaxStart;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MeasurementMenu(
          capabilities: capabilities,
          active: display.primaryFunction,
          onSet: onSet,
        ),
        for (final sub in _subFunctions(current))
          _SubFunctionChip(
            sub: sub,
            active: _isActive(sub),
            onChanged: sub.settable
                ? (active) => onSet(
                    display.primaryFunction,
                    subFunction: sub.id,
                    active: active,
                  )
                : null,
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

class _MeasurementMenu extends StatelessWidget {
  const _MeasurementMenu({
    required this.capabilities,
    required this.active,
    required this.onSet,
  });

  final MeterCapabilities capabilities;
  final String active;
  final CapabilitySetter onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = [
      ...capabilities.measurements,
      if (capabilities.measurement(active) == null) MeterCapability(active),
    ];
    return PopupMenuButton<String>(
      tooltip: l10n.measurementModes,
      onSelected: (id) {
        if (id != active) onSet(id, active: true);
      },
      itemBuilder: (context) => [
        for (final mode in modes)
          CheckedPopupMenuItem(
            value: mode.id,
            checked: mode.id == active,
            enabled: mode.settable,
            child: Text(l10n.primaryFunction(mode.id)),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(l10n.primaryFunction(active)),
      ),
    );
  }
}

class _SubFunctionChip extends StatelessWidget {
  const _SubFunctionChip({
    required this.sub,
    required this.active,
    required this.onChanged,
  });

  final MeterSubFunction sub;
  final bool active;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (sub.kind) {
      MeterSubFunctionKind.secondary =>
        l10n.secondaryFunction(sub.id) ?? sub.id,
      MeterSubFunctionKind.mode => l10n.mode(sub.id),
      MeterSubFunctionKind.action => sub.id,
    };
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: onChanged,
      tooltip: sub.settable ? null : l10n.capabilityNotSettable,
      // A disabled chip would be too faint to read what is active.
      color: active ? WidgetStatePropertyAll(scheme.secondaryContainer) : null,
      checkmarkColor: scheme.onSecondaryContainer,
      labelStyle: active ? TextStyle(color: scheme.onSecondaryContainer) : null,
    );
  }
}

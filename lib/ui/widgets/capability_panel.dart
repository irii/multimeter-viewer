import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../meter/model/model.dart';
import 'bar_actions.dart';

/// Switches a capability, or presses or switches one of its sub-capabilities,
/// on the meter.
typedef CapabilitySetter = void Function(
  String id, {
  String? sub,
  required bool active,
});

/// Icon of a feature's buttons in the app bar.
IconData capabilityIcon(String capability) => switch (capability) {
  'backlight' => Icons.light_mode_outlined,
  _ => Icons.touch_app_outlined,
};

/// The [MeterControl.button]s of the features, as app bar actions.
List<BarAction> capabilityActions(
  BuildContext context,
  MeterCapabilities capabilities, {
  required CapabilitySetter onSet,
}) => [
  for (final feature in capabilities.features)
    for (final sub in feature.subCapabilities)
      if (sub.control == MeterControl.button)
        BarAction(
          icon: capabilityIcon(feature.id),
          label: context.l10n.subCapability(feature.id, sub),
          onPressed: sub.settable
              ? () => onSet(feature.id, sub: sub.id, active: true)
              : null,
        ),
];

/// The active measurement mode with a menu of all modes, the controls of its
/// sub-capabilities and of the features (except buttons, see
/// [capabilityActions]), and the MIN MAX start time. Every control is drawn
/// from its [MeterControl]; what the app cannot set only shows its state.
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

  /// The sub-capabilities of the active mode, plus whatever else the meter
  /// reports as active and neither the mode nor a feature declares, as
  /// labels, so nothing it does stays hidden.
  List<MeterSubCapability> _measurementSubs(MeterCapability? current) {
    final declared = current?.subCapabilities ?? const <MeterSubCapability>[];
    bool isDeclared(String id) => [
      ...declared,
      for (final feature in capabilities.features) ...feature.subCapabilities,
    ].any((sub) => sub.id == id && sub.source != MeterStateSource.none);
    final secondary = display.secondaryFunction;
    return [
      ...declared,
      if (secondary != 'NONE' && !isDeclared(secondary))
        MeterSubCapability(
          secondary,
          MeterControl.label,
          source: MeterStateSource.secondaryFunction,
        ),
      for (final mode in display.modes)
        if (!isDeclared(mode))
          MeterSubCapability(
            mode,
            MeterControl.label,
            source: MeterStateSource.mode,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = display.primaryFunction;
    final minMaxStart = display.minMaxStart;
    final controls = [
      for (final sub in _measurementSubs(capabilities.measurement(active)))
        (active, sub),
      for (final feature in capabilities.features)
        for (final sub in feature.subCapabilities)
          if (sub.control != MeterControl.button) (feature.id, sub),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MeasurementMenu(
          capabilities: capabilities,
          active: active,
          onSet: onSet,
        ),
        for (final (capability, sub) in controls)
          if (sub.control != MeterControl.none &&
              (sub.control != MeterControl.label || sub.isActive(display)))
            _SubCapabilityControl(
              capability: capability,
              sub: sub,
              active: sub.isActive(display),
              onSet: onSet,
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

/// One sub-capability, drawn according to its [MeterControl].
class _SubCapabilityControl extends StatelessWidget {
  const _SubCapabilityControl({
    required this.capability,
    required this.sub,
    required this.active,
    required this.onSet,
  });

  final String capability;
  final MeterSubCapability sub;
  final bool active;
  final CapabilitySetter onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = Text(l10n.subCapability(capability, sub));
    final tooltip = sub.settable ? null : l10n.capabilityNotSettable;
    final activeStyle = TextStyle(color: scheme.onSecondaryContainer);
    return switch (sub.control) {
      MeterControl.toggle => FilterChip(
        label: label,
        selected: active,
        onSelected: sub.settable
            ? (value) => onSet(capability, sub: sub.id, active: value)
            : null,
        tooltip: tooltip,
        // A disabled chip would be too faint to read what is active.
        color: active
            ? WidgetStatePropertyAll(scheme.secondaryContainer)
            : null,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: active ? activeStyle : null,
      ),
      MeterControl.button => ActionChip(
        label: label,
        onPressed: sub.settable
            ? () => onSet(capability, sub: sub.id, active: true)
            : null,
        tooltip: tooltip,
      ),
      MeterControl.label => Chip(
        label: label,
        backgroundColor: scheme.secondaryContainer,
        labelStyle: activeStyle,
      ),
      MeterControl.none => const SizedBox.shrink(),
    };
  }
}

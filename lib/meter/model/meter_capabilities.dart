import 'package:equatable/equatable.dart';

import 'meter_display.dart';

/// How the app shows a [MeterSubCapability].
enum MeterControl {
  /// On or off; can be switched when settable.
  toggle,

  /// An action without a state; can be pressed when settable.
  button,

  /// Shown only while active, never switchable.
  label,

  /// Not shown as a control; used by the app's own pages (memory, meter
  /// properties).
  none,
}

/// Where the on/off state of a [MeterSubCapability] comes from.
enum MeterStateSource {
  /// No state, e.g. a button.
  none,

  /// Active while it is [MeterDisplay.secondaryFunction].
  secondaryFunction,

  /// Active while it is in [MeterDisplay.modes].
  mode,
}

/// A part of a [MeterCapability], e.g. `HERTZ`, `HOLD` or pressing the
/// backlight button.
class MeterSubCapability extends Equatable {
  const MeterSubCapability(
    this.id,
    this.control, {
    this.source = MeterStateSource.none,
    this.settable = false,
  });

  final String id;
  final MeterControl control;
  final MeterStateSource source;

  /// Whether the app can switch or press it on the meter.
  final bool settable;

  bool isActive(MeterDisplay display) => switch (source) {
    MeterStateSource.none => false,
    MeterStateSource.secondaryFunction => display.secondaryFunction == id,
    MeterStateSource.mode => display.modes.contains(id),
  };

  @override
  List<Object?> get props => [id, control, source, settable];
}

/// A measurement mode or a feature of a meter.
class MeterCapability extends Equatable {
  const MeterCapability(
    this.id, {
    this.settable = false,
    this.subCapabilities = const [],
  });

  final String id;

  /// Whether the app can switch it on the meter.
  final bool settable;
  final List<MeterSubCapability> subCapabilities;

  MeterSubCapability? sub(String id) {
    for (final sub in subCapabilities) {
      if (sub.id == id) return sub;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, settable, subCapabilities];
}

/// Features the app has its own pages for.
abstract final class MeterFeatures {
  /// Sub-capability: [read].
  static const memory = 'memory';

  /// Sub-capabilities: [read], [write].
  static const properties = 'properties';

  static const read = 'read';
  static const write = 'write';
}

/// What a meter can do.
class MeterCapabilities extends Equatable {
  const MeterCapabilities({
    this.measurements = const [],
    this.features = const [],
  });

  /// Each ID is a possible [MeterDisplay.primaryFunction].
  final List<MeterCapability> measurements;

  /// Everything besides measuring, e.g. [MeterFeatures] or a backlight.
  final List<MeterCapability> features;

  MeterCapability? measurement(String id) => _find(measurements, id);

  MeterCapability? feature(String id) => _find(features, id);

  /// Whether the meter offers the feature [id] and, if given, its [sub].
  bool hasFeature(String id, {String? sub}) {
    final feature = this.feature(id);
    if (feature == null) return false;
    return sub == null || feature.sub(sub) != null;
  }

  /// Whether the app can switch the capability [id] or its [sub].
  bool isSettable(String id, {String? sub}) {
    final capability = measurement(id) ?? feature(id);
    if (sub == null) return capability?.settable ?? false;
    return capability?.sub(sub)?.settable ?? false;
  }

  static MeterCapability? _find(List<MeterCapability> list, String id) {
    for (final capability in list) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  @override
  List<Object?> get props => [measurements, features];
}

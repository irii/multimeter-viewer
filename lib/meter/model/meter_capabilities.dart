import 'package:equatable/equatable.dart';

/// How a [MeterSubFunction] relates to the meter's display.
enum MeterSubFunctionKind {
  /// Active while it is [MeterDisplay.secondaryFunction].
  secondary,

  /// Active while it is in [MeterDisplay.modes].
  mode,

  /// Something a feature offers, without an on/off state.
  action,
}

/// A function within a [MeterCapability], e.g. `HERTZ` or `HOLD`.
class MeterSubFunction extends Equatable {
  const MeterSubFunction(this.id, this.kind, {this.settable = false});

  final String id;
  final MeterSubFunctionKind kind;

  /// Whether the app can switch it on the meter.
  final bool settable;

  @override
  List<Object?> get props => [id, kind, settable];
}

/// A measurement mode or a feature of a meter.
class MeterCapability extends Equatable {
  const MeterCapability(
    this.id, {
    this.settable = false,
    this.subFunctions = const [],
  });

  final String id;

  /// Whether the app can switch it on the meter.
  final bool settable;
  final List<MeterSubFunction> subFunctions;

  MeterSubFunction? subFunction(String id) {
    for (final sub in subFunctions) {
      if (sub.id == id) return sub;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, settable, subFunctions];
}

/// Features a meter may offer besides measuring.
abstract final class MeterFeatures {
  /// Subfunction: [read].
  static const memory = 'memory';

  /// Subfunctions: [read], [write].
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

  /// IDs from [MeterFeatures].
  final List<MeterCapability> features;

  MeterCapability? measurement(String id) => _find(measurements, id);

  /// Whether the meter offers the feature [id] and, if given, its
  /// [subFunction].
  bool hasFeature(String id, {String? subFunction}) {
    final feature = _find(features, id);
    if (feature == null) return false;
    return subFunction == null || feature.subFunction(subFunction) != null;
  }

  /// Whether the app can switch the capability [id] or its [subFunction].
  bool isSettable(String id, {String? subFunction}) {
    final capability = _find(measurements, id) ?? _find(features, id);
    if (subFunction == null) return capability?.settable ?? false;
    return capability?.subFunction(subFunction)?.settable ?? false;
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

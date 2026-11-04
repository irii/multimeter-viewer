import 'package:equatable/equatable.dart';

enum MeterModel {
  fluke287('Fluke 287'),
  fluke289('Fluke 289'),

  /// Answers like a Fluke but is not a 287/289; may work, untested.
  unknown('Fluke');

  const MeterModel(this.label);

  final String label;

  static const supported = [fluke287, fluke289];

  bool get isSupported => supported.contains(this);
}

class MeterIdentity extends Equatable {
  const MeterIdentity({
    required this.model,
    required this.firmware,
    required this.serial,
  });

  /// Model as reported by the meter, e.g. `FLUKE 287`.
  final String model;
  final String firmware;
  final String serial;

  /// Model family derived from [model]. The 287 and 289 share the protocol;
  /// the 287 just lacks some functions (LoZ, LoΩ).
  MeterModel get meterModel {
    final number = RegExp(r'\b(\d{3})\b').firstMatch(model)?.group(1);
    return switch (number) {
      '287' => MeterModel.fluke287,
      '289' => MeterModel.fluke289,
      _ => MeterModel.unknown,
    };
  }

  @override
  List<Object?> get props => [model, firmware, serial];
}

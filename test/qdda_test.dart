import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('QddaResponse.parse', () {
    test('plain MV_AC display', () {
      final r = QddaResponse.parse(sampleQdda);
      expect(r.primaryFunction, 'MV_AC');
      expect(r.secondaryFunction, 'NONE');
      expect(r.range.autoRange, isTrue);
      expect(r.range.label, '50 mV');
      expect(r.lightningBolt, isFalse);
      expect(r.minMaxStart, isNull);
      expect(r.modes, isEmpty);
      expect(r.readings.map((e) => e.id), ['LIVE', 'PRIMARY']);
      final p = r.primary!;
      expect(p.value, closeTo(0.007312, 1e-12));
      expect(p.displayText, '7.312');
      expect(p.unitText, 'mV AC');
      expect(p.timestamp, 1793196900.250);
    });

    test('MV_AC with PEAK_MIN_MAX and MIN MAX readings', () {
      final r = QddaResponse.parse(sampleQddaMinMax);
      expect(r.secondaryFunction, 'PEAK_MIN_MAX');
      expect(r.modes, ['MIN_MAX_AVG']);
      expect(r.minMaxStartTime, 1793197020.400);
      expect(r.readings, hasLength(5));
      expect(r.reading('MINIMUM')!.displayText, '-18.70');
      expect(r.reading('MINIMUM')!.unitText, 'mV');
      expect(r.reading('MAXIMUM')!.displayText, '27.64');
      expect(r.reading('AVERAGE')!.displayText, '6.12');
    });

    test('overload', () {
      final r = QddaResponse.parse(
        'OHMS,NONE,AUTO,OHM,5,6,OFF,0.000,0,2,'
        'LIVE,9.99999999E+37,OHM,6,2,5,OL,NONE,1793196900.250,'
        'PRIMARY,+9.99999999E+37,OHM,6,2,5,OL,NONE,1793196900.250',
      );
      expect(r.primary!.hasValue, isFalse);
      expect(r.primary!.displayText, 'OL');
      expect(r.primary!.unitText, 'MΩ');
    });

    test('too short response throws', () {
      expect(
        () => QddaResponse.parse('MV_AC,NONE,AUTO'),
        throwsA(isA<FlukeParseException>()),
      );
    });
  });

  group('MeterIdentity.parse', () {
    test('model, firmware and serial', () {
      expect(
        MeterIdentity.parse('FLUKE 289,V1.00,40211337'),
        const MeterIdentity(
          model: 'FLUKE 289',
          firmware: 'V1.00',
          serial: '40211337',
        ),
      );
    });

    test('rejects garbage', () {
      expect(
        () => MeterIdentity.parse('hello'),
        throwsA(isA<FlukeParseException>()),
      );
    });
  });

  group('MeterIdentity.meterModel', () {
    test('recognizes 287 and 289', () {
      expect(
        MeterIdentity.parse('FLUKE 287,V2.02,12345678').meterModel,
        MeterModel.fluke287,
      );
      expect(
        MeterIdentity.parse('FLUKE 289,V1.00,40211337').meterModel,
        MeterModel.fluke289,
      );
      expect(MeterModel.fluke287.isSupported, isTrue);
      expect(MeterModel.supportedLabel, 'Fluke 287/289');
    });

    test('other models are unknown but still parse', () {
      final id = MeterIdentity.parse('FLUKE 189,V2.0,111');
      expect(id.meterModel, MeterModel.unknown);
      expect(id.meterModel.isSupported, isFalse);
    });
  });

  test('parses a Fluke 287 display (no LoZ/LoΩ functions involved)', () {
    final r = QddaResponse.parse(
      'V_DC,NONE,AUTO,VDC,5,0,OFF,0.000,0,2,'
      'LIVE,1.2345,VDC,0,4,5,NORMAL,NONE,1761656700.000,'
      'PRIMARY,1.2345,VDC,0,4,5,NORMAL,NONE,1761656700.000',
    );
    expect(r.primary!.displayText, '1.2345');
  });

  group('signedDisplayText', () {
    Reading reading(double value, {String state = 'NORMAL'}) => Reading(
      id: 'PRIMARY',
      value: value,
      baseUnit: 'VDC',
      multiplier: 0,
      decimalPlaces: 3,
      displayDigits: 5,
      state: state,
      attribute: 'NONE',
      timestamp: 0,
    );

    test('reserves the sign column so the width stays constant', () {
      final positive = reading(1.234).signedDisplayText;
      final negative = reading(-1.234).signedDisplayText;
      expect(positive, ' 1.234');
      expect(negative, '-1.234');
      expect(positive.length, negative.length);
    });

    test('fixed width keeps the length within a range', () {
      // 5 display digits, 3 decimals -> "dd.ddd" plus sign column.
      final texts = [
        reading(7.312).fixedWidthDisplayText,
        reading(-17.312).fixedWidthDisplayText,
        reading(0, state: 'OL').fixedWidthDisplayText,
      ];
      expect(texts, ['  7.312', '-17.312', '     OL']);
      expect(texts.map((t) => t.length).toSet(), {7});
    });

    test('zero and overload', () {
      expect(reading(0).signedDisplayText, ' 0.000');
      expect(reading(9.9e37, state: 'OL').signedDisplayText, ' OL');
      expect(reading(-9.9e37, state: 'OL_MINUS').signedDisplayText, '-OL');
    });
  });
}

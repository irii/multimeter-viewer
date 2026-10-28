import 'package:multimeter_viewer/bloc/history.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:flutter_test/flutter_test.dart';

Reading reading({
  double value = 1,
  String unit = 'VDC',
  int multiplier = 0,
  String state = 'NORMAL',
  required double t,
}) => Reading(
  id: 'PRIMARY',
  value: value,
  baseUnit: unit,
  multiplier: multiplier,
  decimalPlaces: 3,
  displayDigits: 5,
  state: state,
  attribute: 'NONE',
  timestamp: t,
);

void main() {
  test('appends points relative to the first sample', () {
    final h = const SampleHistory()
        .append(reading(value: 1, t: 100))
        .append(reading(value: 2, t: 100.5));
    expect(h.unit, 'VDC');
    expect(h.points, const [SamplePoint(0, 1), SamplePoint(0.5, 2)]);
  });

  test('unit change restarts the series', () {
    final h = const SampleHistory()
        .append(reading(t: 100))
        .append(reading(t: 101))
        .append(reading(value: 5, unit: 'VAC', t: 102));
    expect(h.unit, 'VAC');
    expect(h.start, 102);
    expect(h.points, const [SamplePoint(0, 5)]);
  });

  test('multiplier change (autorange) keeps the series', () {
    final h = const SampleHistory()
        .append(reading(value: 0.5, multiplier: -3, t: 100))
        .append(reading(value: 5, multiplier: 0, t: 101));
    expect(h.points, hasLength(2));
  });

  test('overload becomes a single gap', () {
    final h = const SampleHistory()
        .append(reading(t: 100))
        .append(reading(state: 'OL', t: 101))
        .append(reading(state: 'OL', t: 102))
        .append(reading(t: 103));
    expect(h.points.map((p) => p.value), [1, null, 1]);
  });

  test('frozen timestamp (HOLD) adds nothing', () {
    final h = const SampleHistory()
        .append(reading(t: 100))
        .append(reading(t: 101))
        .append(reading(t: 101));
    expect(h.points, hasLength(2));
  });

  test('buffer is bounded', () {
    var h = const SampleHistory();
    for (var i = 0; i < SampleHistory.maxPoints + 50; i++) {
      h = h.append(reading(value: i.toDouble(), t: 100.0 + i));
    }
    expect(h.points, hasLength(SampleHistory.maxPoints));
    expect(h.points.last.value, SampleHistory.maxPoints + 49);
  });

  test('keeps the system receive time next to the meter time', () {
    final t0 = DateTime(2026, 10, 28, 14, 5);
    final h = const SampleHistory()
        .append(reading(t: 100), receivedAt: t0)
        .append(
          reading(t: 100.2),
          receivedAt: t0.add(const Duration(milliseconds: 350)),
        );
    expect(h.systemStart, t0);
    expect(h.meterStart, meterTimeToDateTime(100));
    expect(h.points.last.t, closeTo(0.2, 1e-9));
    expect(h.points.last.systemT, 0.35);
  });
}

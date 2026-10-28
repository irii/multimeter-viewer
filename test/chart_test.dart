import 'package:multimeter_viewer/ui/widgets/value_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('niceTimeInterval picks readable steps', () {
    expect(niceTimeInterval(0.07), 0.1);
    expect(niceTimeInterval(3), 5);
    expect(niceTimeInterval(11), 15);
    expect(niceTimeInterval(45), 60);
    expect(niceTimeInterval(200), 300);
    expect(niceTimeInterval(4000), 7200);
  });

  test('formatClock', () {
    final t = DateTime(2026, 10, 28, 9, 5, 7, 340);
    expect(formatClock(t), '09:05:07');
    expect(formatClock(t, withFraction: true), '09:05:07.3');
  });

  test('ChartZoom zooms around the center and clamps', () {
    final controller = TransformationController();
    final zoom = ChartZoom(controller);
    const chartWidth = 548.0; // 500 px plot + value axis

    zoom.zoomBy(2, chartWidth);
    expect(zoom.scale, 2);
    // Center (250) stays in place: tx = 250 - 250 * 2.
    expect(controller.value.storage[12], -250);

    zoom.zoomBy(1000, chartWidth);
    expect(zoom.scale, ValueLineChart.maxZoom);

    zoom.zoomBy(0.0001, chartWidth);
    expect(zoom.scale, 1);
    expect(controller.value.storage[12], 0);

    zoom.zoomBy(4, chartWidth);
    zoom.reset();
    expect(zoom.scale, 1);
  });

  test('ChartZoom: narrow charts have no value axis', () {
    final controller = TransformationController();
    ChartZoom(controller).zoomBy(2, 300);
    // The whole width is plot: center 150 stays in place.
    expect(controller.value.storage[12], -150);
  });

  test('niceValueInterval picks 1, 2 or 5 times a power of ten', () {
    expect(niceValueInterval(0.13), closeTo(0.2, 1e-12));
    expect(niceValueInterval(3), 5);
    expect(niceValueInterval(7), 10);
    expect(niceValueInterval(40), 50);
  });
}

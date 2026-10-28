import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/platform/window_chrome.dart';
import 'package:multimeter_viewer/ui/widgets/window_app_bar.dart';

/// Title bar drawn by the app, like on macOS.
class FakeWindowChrome extends WindowChrome {
  final calls = <String>[];

  @override
  bool get drawsTitleBar => true;

  @override
  double get titleBarHeight => 52;

  @override
  EdgeInsets get titleBarPadding => const EdgeInsets.only(left: 72);

  @override
  Future<void> startDragging() async => calls.add('drag');

  @override
  Future<void> titleBarDoubleClicked() async => calls.add('doubleClick');

  @override
  Future<void> hideTitleBar() async => calls.add('hide');

  @override
  Future<void> restoreTitleBar() async => calls.add('restore');
}

void main() {
  late FakeWindowChrome chrome;
  var taps = 0;

  Future<void> pumpBar(WidgetTester tester) async {
    chrome = FakeWindowChrome();
    WindowChrome.instance = chrome;
    addTearDown(() => WindowChrome.instance = const SystemWindowChrome());
    taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(appBarTheme: const AppBarTheme(toolbarHeight: 52)),
        home: Scaffold(
          appBar: WindowAppBar(
            appBar: AppBar(
              title: const Text('Title'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> doubleClick(WidgetTester tester, Offset position) async {
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(
        position,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('app bar acts as the title bar', (tester) async {
    await pumpBar(tester);
    expect(tester.getSize(find.byType(AppBar)).height, 52);
    // Clear of the window buttons.
    expect(tester.getTopLeft(find.text('Title')).dx, greaterThanOrEqualTo(72));

    // Double click on the free bar area, not on the button.
    await doubleClick(tester, const Offset(400, 26));
    expect(chrome.calls, ['doubleClick']);
    await doubleClick(tester, tester.getCenter(find.byIcon(Icons.refresh)));
    expect(chrome.calls, ['doubleClick']);
    expect(taps, 2); // no delay or swallowed taps

    await tester.drag(find.text('Title'), const Offset(50, 20));
    expect(chrome.calls, ['doubleClick', 'drag']);
  });

  testWidgets('plain app bar where the system draws the title bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: WindowAppBar(appBar: AppBar(title: const Text('Title'))),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    expect(tester.getTopLeft(find.text('Title')).dx, lessThan(72));
  });
}

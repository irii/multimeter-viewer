import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../platform/window_chrome.dart';

/// [AppBar] that doubles as the window's title bar where the app draws it
/// ([WindowChrome.drawsTitleBar]): as tall as the title bar, clear of the
/// window buttons, in the app's color to set it apart from the content, and
/// it moves the window when dragged. Elsewhere it is just [appBar].
class WindowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WindowAppBar({super.key, required this.appBar});

  final AppBar appBar;

  @override
  Size get preferredSize {
    final chrome = WindowChrome.instance;
    return chrome.drawsTitleBar
        ? Size.fromHeight(chrome.titleBarHeight)
        : appBar.preferredSize;
  }

  @override
  Widget build(BuildContext context) {
    final chrome = WindowChrome.instance;
    if (!chrome.drawsTitleBar) return appBar;
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = scheme.brightness == Brightness.light
        ? (scheme.primary, scheme.onPrimary)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);
    // The app bar keeps its content inside the padding (SafeArea).
    return ValueListenableBuilder(
      valueListenable: chrome.fullScreen,
      builder: (context, fullScreen, child) => MediaQuery(
        data: media.copyWith(
          padding: fullScreen
              ? media.padding
              : media.padding + chrome.titleBarPadding,
        ),
        child: child!,
      ),
      child: Theme(
        data: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            backgroundColor: background,
            foregroundColor: foreground,
            // Keeps the color when content scrolls under the bar.
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: _TitleBarGestures(chrome: chrome, child: appBar),
      ),
    );
  }
}

/// Dragging moves the window, a double click zooms or minimizes it like a
/// native title bar. Buttons in the bar keep working without delay: no
/// double-tap recognizer competes with their taps.
class _TitleBarGestures extends StatefulWidget {
  const _TitleBarGestures({required this.chrome, required this.child});

  final WindowChrome chrome;
  final Widget child;

  @override
  State<_TitleBarGestures> createState() => _TitleBarGesturesState();
}

class _TitleBarGesturesState extends State<_TitleBarGestures> {
  Duration? _lastDown;

  /// Whether the window follows the current drag. Set on the first move,
  /// not on pan start: a click without movement also starts a pan when no
  /// button competes for it.
  bool _dragging = false;
  Offset? _lastPosition;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final last = _lastDown;
    final isDouble =
        last != null &&
        event.timeStamp - last <= kDoubleTapTimeout &&
        (event.position - _lastPosition!).distance <= kDoubleTapSlop;
    _lastDown = isDouble ? null : event.timeStamp;
    _lastPosition = event.position;
    if (isDouble && !_isOverControl(event)) {
      widget.chrome.titleBarDoubleClicked();
    }
  }

  /// Whether the pointer is over a button or another control in the bar:
  /// besides the drag detector below this widget, something else handles
  /// pointer events there (e.g. the ink well of a button).
  bool _isOverControl(PointerEvent event) {
    final own = context.findRenderObject();
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    final targets = [for (final entry in result.path) entry.target];
    final ownIndex = targets.indexOf(own!);
    if (ownIndex < 0) return false;
    return targets.take(ownIndex).whereType<RenderPointerListener>().length > 1;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (_) {
        if (_dragging) return;
        _dragging = true;
        widget.chrome.startDragging();
      },
      onPanEnd: (_) => _dragging = false,
      onPanCancel: () => _dragging = false,
      child: widget.child,
    ),
  );
}

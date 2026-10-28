import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'compact_window.dart';

final class CompactModeState extends Equatable {
  const CompactModeState({this.active = false, this.alwaysOnTop = false});

  /// Whether the window currently shows the compact value panel.
  final bool active;
  final bool alwaysOnTop;

  @override
  List<Object?> get props => [active, alwaysOnTop];
}

/// Switches the window between the normal app and a small always-on-top
/// panel that only shows the readings (desktop panel or Android
/// picture-in-picture).
class CompactModeCubit extends Cubit<CompactModeState> {
  CompactModeCubit(this._window) : super(const CompactModeState()) {
    _closedSub = _window?.onClosedBySystem.listen((_) {
      if (state.active) emit(const CompactModeState());
    });
  }

  /// `null` where window control is not available (web, iOS).
  final CompactWindow? _window;
  StreamSubscription<void>? _closedSub;

  bool get available => _window != null;

  /// Whether the panel has its own buttons (see [CompactWindow.hasControls]).
  bool get hasControls => _window?.hasControls ?? false;

  Future<void> enter() async {
    final window = _window;
    if (window == null || state.active) return;
    await window.enterCompact();
    emit(const CompactModeState(active: true, alwaysOnTop: true));
  }

  Future<void> exit() async {
    final window = _window;
    if (window == null || !state.active) return;
    await window.exitCompact();
    emit(const CompactModeState());
  }

  Future<void> toggleAlwaysOnTop() async {
    final window = _window;
    if (window == null || !state.active) return;
    final next = !state.alwaysOnTop;
    await window.setAlwaysOnTop(next);
    emit(CompactModeState(active: true, alwaysOnTop: next));
  }

  @override
  Future<void> close() {
    _closedSub?.cancel();
    return super.close();
  }
}

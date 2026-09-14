import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../domain/models/preferences.dart';
import 'gesture_controller.dart';

enum _Interaction { none, hold, scrub }

/// Tap and long press compete with the descendant PageView in the same arena.
/// A recognized hold owns the pointer until release, including horizontal scrub.
class PlayerGestureSurface extends StatefulWidget {
  const PlayerGestureSurface({
    super.key,
    required this.controller,
    required this.child,
    required this.enabled,
    required this.locked,
    required this.landscape,
    required this.sensitivity,
  });

  final PlayerGestureController controller;
  final Widget child;
  final bool enabled;
  final bool locked;
  final bool landscape;
  final GestureSensitivity sensitivity;

  @override
  State<PlayerGestureSurface> createState() => _PlayerGestureSurfaceState();
}

class _PlayerGestureSurfaceState extends State<PlayerGestureSurface> {
  final _pointers = <int>{};
  bool _blocked = false;
  int _sequence = 0;
  Size _size = Size.zero;
  _Interaction _interaction = _Interaction.none;

  bool get _allowed => widget.enabled && !widget.locked && !_blocked;

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      ++_sequence;
      _cancel();
      _blocked =
          event.localPosition.dx < PlayerGestureController.safeEdge ||
          event.localPosition.dx >
              _size.width - PlayerGestureController.safeEdge;
    }
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _blocked = true;
      _cancel();
    }
  }

  void _cancel() {
    _interaction = _Interaction.none;
    widget.controller.cancel();
  }

  void _finish(_Interaction interaction, {bool cancelled = false}) {
    if (_interaction != interaction) return;
    _interaction = _Interaction.none;
    if (cancelled || !_allowed) {
      widget.controller.cancel();
    } else {
      widget.controller.end();
    }
  }

  @override
  void didUpdateWidget(PlayerGestureSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.locked ||
        widget.landscape != oldWidget.landscape ||
        widget.controller != oldWidget.controller) {
      _blocked = true;
      _interaction = _Interaction.none;
      final sequence = ++_sequence;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && sequence == _sequence) oldWidget.controller.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final settings = DeviceGestureSettings(
        touchSlop: switch (widget.sensitivity) {
          GestureSensitivity.low => 22,
          GestureSensitivity.medium => 16,
          GestureSensitivity.high => 10,
        },
      );
      return Listener(
        onPointerDown: _down,
        onPointerUp: (event) => _pointers.remove(event.pointer),
        onPointerCancel: (event) {
          _pointers.remove(event.pointer);
          _blocked = true;
          _cancel();
        },
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          gestures: {
            if (widget.enabled && !widget.locked) ...{
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    () => TapGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer
                      ..gestureSettings = settings
                      ..onTap = () {
                        if (_allowed) widget.controller.tap();
                      },
                  ),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      debugOwner: this,
                      duration: PlayerGestureController.holdDelay,
                      postAcceptSlopTolerance: double.infinity,
                    ),
                    (recognizer) => recognizer
                      ..gestureSettings = settings
                      ..onLongPressStart = (details) {
                        if (!_allowed) return;
                        _interaction = _Interaction.hold;
                        widget.controller.startHold(
                          details.localPosition,
                          _size,
                          landscape: widget.landscape,
                        );
                      }
                      ..onLongPressMoveUpdate = (details) {
                        if (_allowed && _interaction == _Interaction.hold) {
                          widget.controller.update(details.localPosition);
                        }
                      }
                      ..onLongPressEnd = (_) {
                        _finish(_Interaction.hold);
                      }
                      ..onLongPressCancel = () {
                        _finish(_Interaction.hold, cancelled: true);
                      },
                  ),
              if (widget.landscape)
                HorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      HorizontalDragGestureRecognizer
                    >(
                      () => HorizontalDragGestureRecognizer(debugOwner: this),
                      (recognizer) => recognizer
                        ..gestureSettings = settings
                        ..onlyAcceptDragOnThreshold = true
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = (details) {
                          if (!_allowed) return;
                          _interaction = _Interaction.scrub;
                          widget.controller.startScrub(
                            details.localPosition,
                            _size,
                          );
                        }
                        ..onUpdate = (details) {
                          if (_allowed && _interaction == _Interaction.scrub) {
                            widget.controller.update(details.localPosition);
                          }
                        }
                        ..onEnd = (_) {
                          _finish(_Interaction.scrub);
                        }
                        ..onCancel = () {
                          _finish(_Interaction.scrub, cancelled: true);
                        },
                    ),
            },
          },
          child: widget.child,
        ),
      );
    },
  );
}

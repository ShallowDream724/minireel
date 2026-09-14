import 'dart:math';
import 'dart:ui';

enum GestureHudKind { boost, seek }

final class GestureHud {
  const GestureHud(
    this.kind, {
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.delta = Duration.zero,
  });
  final GestureHudKind kind;
  final Duration position;
  final Duration duration;
  final Duration delta;
}

/// Applies playback actions only after Flutter has recognized the gesture.
final class PlayerGestureController {
  PlayerGestureController({
    required this.onTap,
    required this.onMenu,
    required this.onBoost,
    required this.onSeek,
    required this.onScrubState,
    required this.onHud,
    required this.onHaptic,
    required this.readPosition,
    required this.readDuration,
  });

  final void Function() onTap;
  final void Function() onMenu;
  final void Function(bool) onBoost;
  final void Function(Duration) onSeek;
  final void Function(bool) onScrubState;
  final void Function(GestureHud?) onHud;
  final void Function() onHaptic;
  final Duration Function() readPosition;
  final Duration Function() readDuration;

  static const safeEdge = 22.0;
  static const holdDelay = Duration(milliseconds: 380);
  Offset _origin = Offset.zero;
  Size _size = Size.zero;
  Duration _seekOrigin = Duration.zero;
  Duration? _target;
  bool _boosted = false;
  bool _scrubbing = false;

  void tap() => onTap();

  void startHold(Offset point, Size size, {required bool landscape}) {
    cancel();
    onHaptic();
    if (!landscape && point.dy < size.height * .5) {
      onMenu();
      return;
    }
    _origin = point;
    _size = size;
    _seekOrigin = readPosition();
    _boosted = true;
    onBoost(true);
    onHud(const GestureHud(GestureHudKind.boost));
  }

  void startScrub(Offset point, Size size) {
    cancel();
    _origin = point;
    _size = size;
    _seekOrigin = readPosition();
    _scrubbing = true;
    onScrubState(true);
  }

  void update(Offset point) {
    if (!_boosted && !_scrubbing) return;
    final dx = point.dx - _origin.dx;
    if (dx.abs() <= 8 && !_scrubbing) return;
    final duration = readDuration();
    if (duration <= Duration.zero) return;
    if (!_scrubbing) {
      _scrubbing = true;
      onScrubState(true);
    }
    final offsetMs = dx / max(_size.width * .42, 1) * 45000;
    _target = Duration(
      milliseconds: (_seekOrigin.inMilliseconds + offsetMs).round().clamp(
        0,
        duration.inMilliseconds,
      ),
    );
    onHud(
      GestureHud(
        GestureHudKind.seek,
        position: _target!,
        duration: duration,
        delta: _target! - _seekOrigin,
      ),
    );
  }

  void end() => _finish(commit: true);

  /// Cancellation restores speed without committing a seek or synthesizing a tap.
  void cancel() => _finish(commit: false);

  void _finish({required bool commit}) {
    if (!_boosted && !_scrubbing) return;
    final boosted = _boosted;
    final scrubbing = _scrubbing;
    final target = commit ? _target : null;
    _boosted = false;
    _scrubbing = false;
    _target = null;
    if (boosted) onBoost(false);
    if (target != null) onSeek(target);
    if (scrubbing) onScrubState(false);
    onHud(null);
  }

  void dispose() => cancel();
}

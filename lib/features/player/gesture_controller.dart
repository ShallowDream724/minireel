import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../../domain/models/preferences.dart';

enum GestureHudKind { brightness, volume, boost, seek, episode }

final class GestureHud {
  const GestureHud(
    this.kind, {
    this.level = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.delta = Duration.zero,
    this.next = true,
  });
  final GestureHudKind kind;
  final double level;
  final Duration position;
  final Duration duration;
  final Duration delta;
  final bool next;
}

enum _Mode {
  pending,
  ignored,
  brightness,
  volume,
  episode,
  boosted,
  scrub,
  menu,
}

/// One pointer, one gesture. Direction is locked after the movement threshold.
/// The 22 dp safe edges are left to Android's system back gesture.
final class PlayerGestureController {
  PlayerGestureController({
    required this.onTap,
    required this.onLockedTap,
    required this.onMenu,
    required this.onBoost,
    required this.onSeek,
    required this.onScrubState,
    required this.onBrightness,
    required this.onVolume,
    required this.onEpisode,
    required this.onHud,
    required this.onHaptic,
    required this.readPosition,
    required this.readDuration,
  });

  final void Function() onTap;
  final void Function() onLockedTap;
  final void Function() onMenu;
  final void Function(bool) onBoost;
  final void Function(Duration) onSeek;
  final void Function(bool) onScrubState;
  final void Function(double) onBrightness;
  final void Function(double) onVolume;
  final void Function(bool next) onEpisode;
  final void Function(GestureHud?) onHud;
  final void Function() onHaptic;
  final Duration Function() readPosition;
  final Duration Function() readDuration;

  static const safeEdge = 22.0;
  static const holdDelay = Duration(milliseconds: 380);
  Timer? _timer;
  int? _pointer;
  Offset _origin = Offset.zero;
  Size _size = Size.zero;
  _Mode _mode = _Mode.pending;
  bool _top = true;
  bool _locked = false;
  bool _landscape = false;
  bool _moved = false;
  bool _switched = false;
  double _initialBrightness = .8;
  double _initialVolume = .5;
  Duration _seekOrigin = Duration.zero;
  Duration? _target;
  GestureSensitivity _sensitivity = GestureSensitivity.medium;

  double get _startThreshold => switch (_sensitivity) {
    GestureSensitivity.low => 22,
    GestureSensitivity.medium => 16,
    GestureSensitivity.high => 10,
  };
  double get _episodeThreshold => switch (_sensitivity) {
    GestureSensitivity.low => 120,
    GestureSensitivity.medium => 88,
    GestureSensitivity.high => 64,
  };

  void down({
    required int pointer,
    required Offset point,
    required Size size,
    required bool locked,
    required double brightness,
    required double volume,
    required GestureSensitivity sensitivity,
    bool landscape = false,
  }) {
    if (_pointer != null) {
      cancel();
      return;
    }
    _pointer = pointer;
    _origin = point;
    _size = size;
    _top = point.dy < size.height * .5;
    _locked = locked;
    _landscape = landscape;
    _moved = false;
    _switched = false;
    _target = null;
    _initialBrightness = brightness;
    _initialVolume = volume;
    _sensitivity = sensitivity;
    if (point.dx < safeEdge || point.dx > size.width - safeEdge) {
      _mode = _Mode.ignored;
      return;
    }
    _mode = _Mode.pending;
    if (locked) return;
    _timer = Timer(holdDelay, () {
      if (_pointer == null || _moved || _locked) return;
      onHaptic();
      if (_top && !_landscape) {
        _mode = _Mode.menu;
        onMenu();
      } else {
        _mode = _Mode.boosted;
        _seekOrigin = readPosition();
        onBoost(true);
        onHud(const GestureHud(GestureHudKind.boost));
      }
    });
  }

  void move(int pointer, Offset point) {
    if (pointer != _pointer || _mode == _Mode.ignored || _mode == _Mode.menu) {
      return;
    }
    final dx = point.dx - _origin.dx;
    final dy = point.dy - _origin.dy;
    if (_mode == _Mode.boosted || _mode == _Mode.scrub) {
      if (dx.abs() <= 8 && _mode != _Mode.scrub) return;
      final duration = readDuration();
      if (duration <= Duration.zero) return;
      if (_mode != _Mode.scrub) {
        _mode = _Mode.scrub;
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
      return;
    }
    if (!_moved) {
      if (sqrt(dx * dx + dy * dy) < _startThreshold) return;
      _timer?.cancel();
      _moved = true;
      if (_locked) {
        _mode = _Mode.ignored;
        return;
      }
      if (_landscape && dx.abs() > dy.abs()) {
        _seekOrigin = readPosition();
        _mode = _Mode.scrub;
        onScrubState(true);
        move(pointer, point);
        return;
      }
      if (dy.abs() <= dx.abs()) {
        _mode = _Mode.ignored;
        return;
      }
      _mode = _landscape
          ? (_origin.dx < _size.width * .5 ? _Mode.brightness : _Mode.volume)
          : _origin.dx < _size.width * .34
          ? _Mode.brightness
          : _origin.dx > _size.width * .66
          ? _Mode.volume
          : _Mode.episode;
      onHaptic();
    }
    if (_locked) return;
    switch (_mode) {
      case _Mode.brightness:
        final value = (_initialBrightness - dy / 280).clamp(.03, 1.0);
        onBrightness(value);
        onHud(GestureHud(GestureHudKind.brightness, level: value));
      case _Mode.volume:
        final value = (_initialVolume - dy / 280).clamp(0.0, 1.0);
        onVolume(value);
        onHud(GestureHud(GestureHudKind.volume, level: value));
      case _Mode.episode:
        if (_switched) return;
        onHud(GestureHud(GestureHudKind.episode, next: dy < 0));
        if (dy.abs() >= _episodeThreshold) {
          _switched = true;
          onHaptic();
          onEpisode(dy < 0);
        }
      default:
        break;
    }
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _timer?.cancel();
    _pointer = null;
    if (_mode == _Mode.boosted || _mode == _Mode.scrub) {
      onBoost(false);
      if (_target != null) onSeek(_target!);
      onScrubState(false);
      onHud(null);
    } else if (_mode == _Mode.pending && !_moved) {
      if (_locked) {
        onLockedTap();
      } else {
        onTap();
      }
    }
    _target = null;
    _mode = _Mode.pending;
  }

  /// Pointer cancellation, backgrounding, lock, sheet and route changes must
  /// restore normal rate, and must never commit a seek or synthesize a tap.
  void cancel() {
    _timer?.cancel();
    if (_mode == _Mode.boosted || _mode == _Mode.scrub) {
      onBoost(false);
      onScrubState(false);
      onHud(null);
    }
    _pointer = null;
    _target = null;
    _mode = _Mode.pending;
  }

  void dispose() {
    _timer?.cancel();
    _pointer = null;
  }
}

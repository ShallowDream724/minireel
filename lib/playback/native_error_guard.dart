import 'dart:async';

/// mpv emits codec errors while trying hardware decoders, even when its
/// software fallback succeeds. Only escalate if playback does not recover.
final class NativeErrorGuard {
  NativeErrorGuard({
    required this.onFailure,
    this.grace = const Duration(seconds: 2),
  });
  final void Function() onFailure;
  final Duration grace;
  Timer? _timer;
  Duration _position = Duration.zero;
  Duration? _failedAt;
  bool _playing = true;

  void reportError() {
    if (_failedAt != null) return;
    _failedAt = _position;
    _schedule();
  }

  void _schedule() {
    if (!_playing || _timer != null || _failedAt == null) return;
    _timer = Timer(grace, () {
      _timer = null;
      _failedAt = null;
      onFailure();
    });
  }

  void setPlaying(bool playing) {
    _playing = playing;
    if (playing) {
      _schedule();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void progress(Duration position) {
    _position = position;
    if (_failedAt != null &&
        position > _failedAt! + const Duration(milliseconds: 150)) {
      _timer?.cancel();
      _timer = null;
      _failedAt = null;
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _failedAt = null;
    _position = Duration.zero;
  }

  void dispose() => reset();
}

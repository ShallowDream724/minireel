import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/errors/app_exception.dart';
import '../domain/models/playback_source.dart';
import 'playback_engine.dart';
import 'native_error_guard.dart';

final class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() {
    _errors = NativeErrorGuard(
      grace: const Duration(seconds: 6),
      onFailure: () => _emit(
        state.value.copyWith(
          error: '视频加载失败，请重试或切换下一集',
          playing: false,
          buffering: false,
        ),
      ),
    );
    video = VideoController(player);
    _subscriptions.addAll([
      player.stream.position.listen((v) {
        _errors.progress(v);
        _emit(state.value.copyWith(position: v));
      }),
      player.stream.duration.listen(
        (v) => _emit(state.value.copyWith(duration: v)),
      ),
      player.stream.buffer.listen(
        (v) => _emit(state.value.copyWith(buffer: v)),
      ),
      player.stream.playing.listen(
        (v) => _emit(state.value.copyWith(playing: v)),
      ),
      player.stream.buffering.listen(
        (v) => _emit(state.value.copyWith(buffering: v)),
      ),
      player.stream.completed.listen(
        (v) => _emit(state.value.copyWith(completed: v)),
      ),
      player.stream.error.listen((_) => _errors.reportError()),
    ]);
  }

  final Player player = Player(
    configuration: const PlayerConfiguration(
      title: 'MiniReel',
      bufferSize: 32 * 1024 * 1024,
    ),
  );
  late final VideoController video;
  late final NativeErrorGuard _errors;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  final ValueNotifier<EngineSnapshot> state = ValueNotifier(
    const EngineSnapshot(),
  );
  Future<void> _operations = Future.value();
  bool _disposed = false;

  void _emit(EngineSnapshot next) {
    if (!_disposed) state.value = next;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    // A failed open does not poison subsequent retries or teardown.
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> open(
    PlaybackSource source, {
    required Duration start,
    required bool Function() isCurrent,
  }) => _serialize(() async {
    bool valid() => !_disposed && isCurrent();
    if (!valid()) return;
    _errors.reset();
    _errors.setPlaying(false);
    await player.stop();
    if (!valid()) return;
    final native = player.platform;
    if (native is NativePlayer) {
      if (source.kind == PlaybackKind.cenc && source.contentKey?.length != 16) {
        throw const AppException('本集播放信息不完整，请重试');
      }
      // Clear the previous key for EVERY open, including unencrypted media.
      await native.setProperty(
        'demuxer-lavf-o',
        [
          'reconnect=1',
          'reconnect_streamed=1',
          'reconnect_on_network_error=1',
          'reconnect_delay_max=2',
          if (source.kind == PlaybackKind.cenc)
            'decryption_key=${source.keyHex}',
        ].join(','),
      );
      await native.setProperty('network-timeout', '20');
    } else if (source.kind == PlaybackKind.cenc) {
      throw const AppException('当前设备暂不支持这个视频格式');
    }
    if (!valid()) return;
    _emit(const EngineSnapshot(buffering: true));
    // Always open paused: a late network response can never start audio
    // behind a sheet, in the background, or after the viewer leaves.
    await player.open(
      Media(
        source.uri.toString(),
        httpHeaders: source.headers,
        start: start > Duration.zero ? start : null,
      ),
      play: false,
    );
    if (!valid()) await player.stop();
  });

  @override
  Future<void> stop() => _serialize(() async {
    if (_disposed) return;
    _errors.reset();
    _errors.setPlaying(false);
    await player.stop();
    _emit(const EngineSnapshot());
  });

  @override
  Future<void> setPlaying(bool playing) async {
    if (_disposed) return;
    _errors.setPlaying(playing);
    if (playing) {
      await player.play();
    } else {
      await player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_disposed) await player.seek(position);
  }

  @override
  Future<void> setRate(double rate) async {
    if (!_disposed) await player.setRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_disposed) await player.setVolume(volume * 100);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _errors.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _operations;
    await player.dispose();
    state.dispose();
  }
}

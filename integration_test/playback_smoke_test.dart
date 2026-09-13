import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:minireel/core/config/source_config.dart';
import 'package:minireel/core/errors/app_exception.dart';
import 'package:minireel/core/network/app_http_client.dart';
import 'package:minireel/data/sources/hongguo/hongguo_adapter.dart';
import 'package:minireel/domain/models/drama.dart';
import 'package:minireel/domain/models/playback_source.dart';
import 'package:minireel/playback/media_kit_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets(
    '${Platform.operatingSystem} resolves a real drama, plays, seeks, pauses, and switches episodes',
    (tester) async {
      final raw = jsonDecode(
        await rootBundle.loadString('assets/config/sources.json'),
      );
      final config = SourceConfig.fromJson(
        raw['sources']['hongguo'] as Map<String, dynamic>,
      );
      final client = AppHttpClient(config);
      final adapter = HongguoAdapter(config, client);
      final engine = MediaKitEngine();
      final diagnostics = engine.player.stream.error.listen((message) {
        final safe = message
            .replaceAll(RegExp(r'https?://\S+'), '<media-url>')
            .replaceAll(RegExp(r'\b[a-fA-F0-9]{32,}\b'), '<redacted>');
        debugPrint('Native diagnostic: $safe');
      });
      var stage = 'catalog';
      Future<void> waitUntil(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 35));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            final state = engine.state.value;
            throw StateError(
              '$stage: position=${state.position}, duration=${state.duration}, '
              'playing=${state.playing}, buffering=${state.buffering}, error=${state.error}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Video(
              controller: engine.video,
              controls: NoVideoControls,
              pauseUponEnteringBackgroundMode: false,
              resumeUponEnteringForegroundMode: false,
            ),
          ),
        ),
      );
      try {
        await tester.runAsync(() async {
          final catalog = await adapter.fetchCatalog(DramaChannel.real, 1);
          expect(catalog, isNotEmpty);
          final detail = await adapter.fetchDetail(catalog.first);
          expect(detail.episodes.length, greaterThan(1));
          for (final episode in detail.episodes.take(2)) {
            stage = 'direct episode ${episode.index}';
            debugPrint('Checking $stage');
            final options = await adapter.resolvePlayback(
              detail.drama,
              episode,
            );
            await engine.open(
              options.sources.first,
              start: Duration.zero,
              isCurrent: () => true,
            );
            await engine.setPlaying(true);
            await waitUntil(
              () => engine.state.value.position > const Duration(seconds: 1),
            );
            expect(engine.state.value.duration, greaterThan(Duration.zero));
            expect(engine.state.value.error, isNull);
            await engine.setPlaying(false);
            await waitUntil(() => !engine.state.value.playing);
            await engine.seek(const Duration(seconds: 10));
            await engine.setPlaying(true);
            await waitUntil(
              () => engine.state.value.position >= const Duration(seconds: 10),
            );
            await engine.setRate(2);
            await engine.setRate(1);
          }
          final fallback = HongguoAdapter(config, _FallbackClient(client));
          for (final episode in detail.episodes.take(2)) {
            stage = 'CENC episode ${episode.index}';
            debugPrint('Checking $stage');
            final options = await fallback.resolvePlayback(
              detail.drama,
              episode,
            );
            expect(options.sources.first.kind, PlaybackKind.cenc);
            await engine.open(
              options.sources.first,
              start: Duration.zero,
              isCurrent: () => true,
            );
            await engine.setPlaying(true);
            await waitUntil(
              () => engine.state.value.position > const Duration(seconds: 1),
            );
            expect(engine.state.value.error, isNull);
            final frame = await engine.player.screenshot(format: 'image/png');
            expect(
              frame,
              isNotNull,
              reason: 'CENC must render a real video frame',
            );
            final decoded = image.decodePng(frame!)!;
            final colors = <int>{};
            for (var y = 0; y < decoded.height; y += 80) {
              for (var x = 0; x < decoded.width; x += 80) {
                final p = decoded.getPixel(x, y);
                colors.add(
                  (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt(),
                );
              }
            }
            expect(
              colors.length,
              greaterThan(12),
              reason: 'CENC output must not be a blank frame',
            );
            final cache = await getTemporaryDirectory();
            await File('${cache.path}/cenc-frame.png').writeAsBytes(frame);
            debugPrint(
              'CENC rendered ${decoded.width}x${decoded.height} with ${colors.length} sampled colors',
            );
            await engine.seek(const Duration(seconds: 15));
            await waitUntil(
              () => engine.state.value.position >= const Duration(seconds: 15),
            );
            await engine.setPlaying(false);
            await engine.setPlaying(true);
          }
          // CENC -> unencrypted opens must clear the previous content key.
          stage = 'CENC to direct';
          final direct = await adapter.resolvePlayback(
            detail.drama,
            detail.episodes.first,
          );
          await engine.open(
            direct.sources.first,
            start: Duration.zero,
            isCurrent: () => true,
          );
          await engine.setPlaying(true);
          await waitUntil(
            () => engine.state.value.position > const Duration(seconds: 1),
          );
          expect(engine.state.value.error, isNull);
          // Exercise native HLS demuxing as well as the provider's MP4 streams.
          stage = 'HLS';
          await engine.open(
            PlaybackSource(
              uri: Uri.parse(
                'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
              ),
              kind: PlaybackKind.hls,
              headers: const {},
            ),
            start: Duration.zero,
            isCurrent: () => true,
          );
          await engine.setPlaying(true);
          await waitUntil(
            () => engine.state.value.position > const Duration(seconds: 1),
          );
          expect(engine.state.value.error, isNull);
        });
      } finally {
        await diagnostics.cancel();
        await tester.runAsync(engine.dispose);
        client.close();
      }
    },
  );
}

final class _FallbackClient implements TextClient {
  const _FallbackClient(this.client);
  final TextClient client;
  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    if (uri.path.startsWith('/player/')) {
      throw const AppException('Exercise fallback');
    }
    return client.getText(uri, headers: headers, cancelToken: cancelToken);
  }
}

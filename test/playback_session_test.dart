import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/app/app_controller.dart';
import 'package:minireel/data/repositories/drama_repository.dart';
import 'package:minireel/data/sources/source_adapter.dart';
import 'package:minireel/domain/models/playback_source.dart';
import 'package:minireel/domain/models/preferences.dart';
import 'package:minireel/domain/models/watch_record.dart';
import 'package:minireel/playback/playback_session.dart';

import 'support/fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryStore store;
  late FakeSource source;
  late FakeEngine engine;
  late AppController app;
  late PlaybackSession session;

  setUp(() async {
    store = MemoryStore();
    source = FakeSource();
    engine = FakeEngine();
    app = AppController(
      store,
      DramaRepository(SourceRegistry([source]), store),
    );
    await app.initialize();
    session = PlaybackSession(app: app, engine: engine, drama: sampleDrama);
  });
  tearDown(() async {
    await session.close();
    session.dispose();
    app.repository.dispose();
    app.dispose();
  });

  PlaybackOptions fallbackOptions() => PlaybackOptions([
    for (final quality in ['1080P', '720P'])
      PlaybackSource(
        uri: Uri.parse('https://example.invalid/fallback-$quality.mp4'),
        kind: PlaybackKind.direct,
        route: PlaybackRoute.fallback,
        quality: quality,
        headers: const {},
      ),
  ]);

  test(
    'native load failure switches to fallback, preserves position and caps retries',
    () async {
      source.fallback = (_, _) async => fallbackOptions();
      await session.initialize();
      engine.tick(24);
      engine.state.value = engine.state.value.copyWith(
        error: 'failed',
        playing: false,
      );
      await flush();
      await flush();
      expect(source.fallbackRequests, [false, true]);
      expect(engine.opened.last, '/fallback-1080P.mp4');
      expect(engine.starts.last, const Duration(seconds: 24));
      engine.state.value = engine.state.value.copyWith(
        error: 'failed',
        playing: false,
      );
      await flush();
      await flush();
      expect(engine.opened.last, '/fallback-720P.mp4');
      expect(source.fallbackRequests, [false, true, true]);
      engine.state.value = engine.state.value.copyWith(
        error: 'failed',
        playing: false,
      );
      await flush();
      await flush();
      expect(session.error, isNotNull);
      expect(engine.opened, hasLength(3));
      expect(engine.state.value.duration, Duration.zero);
    },
  );

  test(
    'leaving during automatic fallback cannot reopen the old episode',
    () async {
      final pending = Completer<PlaybackOptions>();
      source.fallback = (_, _) => pending.future;
      await session.initialize();
      engine.state.value = engine.state.value.copyWith(
        error: 'failed',
        playing: false,
      );
      await flush();
      await session.close();
      pending.complete(fallbackOptions());
      await flush();
      expect(engine.opened, ['/1.mp4']);
    },
  );

  test(
    'an automatic recovery behind a sheet does not start playback',
    () async {
      source.fallback = (_, _) async => fallbackOptions();
      await session.initialize();
      session.hold('sheet');
      await flush();
      engine.state.value = engine.state.value.copyWith(
        error: 'failed',
        playing: false,
      );
      await flush();
      await flush();
      expect(session.playing, false);
      session.release('sheet');
      await flush();
      expect(session.playing, true);
    },
  );

  test('late resolve cannot override a newer episode', () async {
    await session.initialize();
    final second = Completer<PlaybackOptions>();
    final third = Completer<PlaybackOptions>();
    source.resolve = (ep, _) => ep.index == 2 ? second.future : third.future;
    final a = session.playEpisode(1);
    await flush();
    final b = session.playEpisode(2);
    await flush();
    third.complete(mediaFor(sampleEpisodes[2]));
    await b;
    second.complete(mediaFor(sampleEpisodes[1]));
    await a;
    expect(session.episode!.index, 3);
    expect(engine.opened, ['/1.mp4', '/3.mp4']);
    expect(session.playing, true);
  });

  test('closing during resolve never opens media or resumes audio', () async {
    await session.initialize();
    final pending = Completer<PlaybackOptions>();
    source.resolve = (_, _) => pending.future;
    final next = session.next();
    await flush();
    await session.close();
    pending.complete(mediaFor(sampleEpisodes[1]));
    await next;
    expect(engine.opened, ['/1.mp4']);
    expect(engine.disposed, true);
  });

  test(
    'background and sheet pause reasons preserve user intent independently',
    () async {
      await session.initialize();
      session.hold('sheet');
      session.hold('background');
      await flush();
      expect(session.playing, false);
      session.release('background');
      await flush();
      expect(session.playing, false);
      session.release('sheet');
      await flush();
      expect(session.playing, true);
      session.togglePlay();
      await flush();
      session.hold('sheet');
      session.release('sheet');
      await flush();
      expect(session.playing, false);
    },
  );

  test(
    'progress persists at pause and resumes the correct episode and timestamp',
    () async {
      store.history[sampleDrama.id] = WatchRecord(
        drama: sampleDrama,
        episodeId: sampleEpisodes[1].id,
        episodeIndex: 2,
        position: const Duration(seconds: 26),
        duration: const Duration(seconds: 120),
        updatedAt: DateTime.now(),
      );
      await app.initialize();
      await session.initialize();
      expect(session.episode!.index, 2);
      expect(engine.starts.last, const Duration(seconds: 26));
      engine.tick(41);
      session.togglePlay();
      await flush();
      await app.flush();
      expect(
        store.history[sampleDrama.id]!.position,
        const Duration(seconds: 41),
      );
    },
  );

  test(
    'temporary 2x restores the selected speed instead of forcing 1x',
    () async {
      app.setPreferences(const Preferences(speed: 1.5));
      await session.initialize();
      session.boost(true);
      session.boost(false);
      expect(engine.rates, [1.5, 2, 1.5]);
    },
  );

  test('completion auto-advances once; the final episode stops', () async {
    await session.initialize();
    engine.complete();
    await flush();
    await flush();
    expect(session.episode!.index, 2);
    expect(engine.opened, ['/1.mp4', '/2.mp4']);
    await session.playEpisode(3);
    engine.complete();
    await flush();
    expect(session.episode!.index, 4);
    expect(session.playing, false);
  });

  test('remember and auto-next preferences are respected', () async {
    app.setPreferences(
      const Preferences(rememberProgress: false, autoNext: false),
    );
    await session.initialize();
    engine.tick(40);
    session.saveProgress();
    engine.complete();
    await flush();
    expect(app.history, isEmpty);
    expect(session.episode!.index, 1);
    expect(session.playing, false);
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/domain/models/preferences.dart';
import 'package:minireel/features/player/gesture_controller.dart';

class _Harness {
  final taps = <String>[];
  final boosts = <bool>[];
  final seeks = <Duration>[];
  final brightness = <double>[];
  final volumes = <double>[];
  final episodes = <bool>[];
  final scrub = <bool>[];
  GestureHud? hud;
  late final controller = PlayerGestureController(
    onTap: () => taps.add('tap'),
    onLockedTap: () => taps.add('locked'),
    onMenu: () => taps.add('menu'),
    onBoost: boosts.add,
    onSeek: seeks.add,
    onScrubState: scrub.add,
    onBrightness: brightness.add,
    onVolume: volumes.add,
    onEpisode: episodes.add,
    onHud: (value) => hud = value,
    onHaptic: () {},
    readPosition: () => const Duration(seconds: 30),
    readDuration: () => const Duration(seconds: 90),
  );
  void down(
    double x,
    double y, {
    bool locked = false,
    int pointer = 1,
    bool landscape = false,
  }) => controller.down(
    pointer: pointer,
    point: Offset(x, y),
    size: landscape ? const Size(800, 400) : const Size(400, 800),
    locked: locked,
    brightness: .5,
    volume: .5,
    sensitivity: GestureSensitivity.medium,
    landscape: landscape,
  );
}

void main() {
  testWidgets(
    'landscape horizontal drag seeks without a long press or episode change',
    (tester) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.down(400, 200, landscape: true);
      h.controller.move(1, const Offset(520, 202));
      expect(h.hud!.kind, GestureHudKind.seek);
      expect(h.hud!.position, greaterThan(const Duration(seconds: 30)));
      h.controller.up(1);
      expect(h.seeks, hasLength(1));
      expect(h.episodes, isEmpty);
      expect(h.taps, isEmpty);
      expect(h.boosts.contains(true), false);
    },
  );

  testWidgets(
    'landscape vertical drags use two halves and long press always boosts',
    (tester) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.down(350, 200, landscape: true);
      h.controller.move(1, const Offset(350, 100));
      h.controller.up(1);
      expect(h.brightness, isNotEmpty);
      expect(h.episodes, isEmpty);
      h.down(450, 200, landscape: true);
      h.controller.move(1, const Offset(450, 300));
      h.controller.up(1);
      expect(h.volumes, isNotEmpty);
      expect(h.episodes, isEmpty);
      h.down(400, 100, landscape: true);
      await tester.pump(const Duration(milliseconds: 400));
      h.controller.up(1);
      expect(h.boosts, [true, false]);
      expect(h.taps, isEmpty);
    },
  );

  testWidgets('cancelled landscape seek and locked landscape remain inert', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.down(400, 200, landscape: true);
    h.controller.move(1, const Offset(500, 200));
    h.controller.cancel();
    expect(h.seeks, isEmpty);
    expect(h.scrub.last, false);
    h.down(400, 200, landscape: true, locked: true);
    h.controller.move(1, const Offset(520, 200));
    await tester.pump(const Duration(milliseconds: 400));
    h.controller.up(1);
    expect(h.seeks, isEmpty);
    expect(h.boosts.contains(true), false);
    expect(h.episodes, isEmpty);
  });

  testWidgets('tap pauses; top hold opens menu without a trailing tap', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.down(200, 200);
    h.controller.up(1);
    expect(h.taps, ['tap']);
    h.down(200, 200);
    await tester.pump(const Duration(milliseconds: 380));
    h.controller.up(1);
    expect(h.taps, ['tap', 'menu']);
    expect(h.boosts, isEmpty);
  });

  testWidgets(
    'bottom hold boosts and restores; horizontal scrub clamps and commits once',
    (tester) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.down(200, 650);
      await tester.pump(const Duration(milliseconds: 380));
      expect(h.boosts, [true]);
      h.controller.move(1, const Offset(1000, 650));
      expect(h.hud!.position, const Duration(seconds: 90));
      h.controller.up(1);
      expect(h.boosts, [true, false]);
      expect(h.seeks, [const Duration(seconds: 90)]);
      expect(h.scrub, [true, false]);
      expect(h.taps, isEmpty);
    },
  );

  testWidgets('cancelled or multi-touch scrub never seeks or taps', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.down(200, 650);
    await tester.pump(const Duration(milliseconds: 380));
    h.controller.move(1, const Offset(230, 650));
    h.down(240, 670, pointer: 2);
    h.controller.up(1);
    h.controller.up(2);
    expect(h.boosts, [true, false]);
    expect(h.seeks, isEmpty);
    expect(h.taps, isEmpty);
    expect(h.scrub.last, false);
  });

  testWidgets(
    'safe edges and lock suppress long press, volume and episode changes',
    (tester) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      for (final x in [10.0, 390.0]) {
        h.down(x, 600);
        await tester.pump(const Duration(milliseconds: 500));
        h.controller.move(1, Offset(x, 200));
        h.controller.up(1);
      }
      h.down(200, 200, locked: true);
      await tester.pump(const Duration(milliseconds: 500));
      h.controller.up(1);
      h.down(340, 650, locked: true);
      await tester.pump(const Duration(milliseconds: 500));
      h.controller.move(1, const Offset(340, 200));
      h.controller.up(1);
      expect(h.taps, ['locked']);
      expect(h.boosts, isEmpty);
      expect(h.volumes, isEmpty);
      expect(h.episodes, isEmpty);
    },
  );

  testWidgets('left and right vertical drags adjust only their own controls', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.down(80, 400);
    h.controller.move(1, const Offset(80, 260));
    h.controller.up(1);
    expect(h.brightness.last, 1);
    expect(h.volumes, isEmpty);
    h.down(330, 400);
    h.controller.move(1, const Offset(330, 540));
    h.controller.up(1);
    expect(h.volumes.last, 0);
    expect(h.episodes, isEmpty);
    h.down(80, 400);
    h.controller.move(1, const Offset(240, 405));
    h.controller.up(1);
    expect(h.brightness.length, 1);
    expect(h.taps, isEmpty);
  });

  testWidgets(
    'center drag switches at most one episode and cancels pending hold',
    (tester) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.down(200, 400);
      h.controller.move(1, const Offset(200, 300));
      h.controller.move(1, const Offset(200, 150));
      await tester.pump(const Duration(milliseconds: 500));
      h.controller.up(1);
      expect(h.episodes, [true]);
      expect(h.taps, isEmpty);
      expect(h.boosts, isEmpty);
    },
  );
}

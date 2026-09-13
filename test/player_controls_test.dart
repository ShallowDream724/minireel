import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/app/theme.dart';
import 'package:minireel/features/player/player_controls.dart';

void main() {
  testWidgets(
    'portrait progress is labeled and dragging downward moves forward',
    (tester) async {
      double value = .25;
      double? committed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ReelTheme.make(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, update) => SizedBox(
                  height: 570,
                  child: PortraitPlayerControls(
                    playing: true,
                    episode: 1,
                    episodeCount: 217,
                    position: Duration(seconds: (120 * value).round()),
                    duration: const Duration(seconds: 120),
                    value: value,
                    right: true,
                    onCollapse: () {},
                    onPrevious: null,
                    onPlayPause: () {},
                    onNext: () {},
                    onLandscape: () {},
                    onLock: () {},
                    onSeekStart: (_) {},
                    onSeek: (v) => update(() => value = v),
                    onSeekEnd: (v) => committed = v,
                    onSeekCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('进度'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      final rect = tester.getRect(find.byKey(const ValueKey('rail-progress')));
      final drag = await tester.startGesture(
        Offset(rect.center.dx, rect.top + rect.height * .30),
      );
      await drag.moveBy(Offset(0, rect.height * .35));
      await drag.up();
      await tester.pump();
      expect(committed, isNotNull);
      expect(committed!, greaterThan(.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape controls expose time, episodes and orientation without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var exited = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ReelTheme.make(Brightness.dark),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LandscapePlayerControls(
                    playing: false,
                    position: const Duration(seconds: 10),
                    duration: const Duration(seconds: 120),
                    value: .1,
                    speed: 1.5,
                    onPrevious: null,
                    onPlayPause: () {},
                    onNext: () {},
                    onEpisodes: () {},
                    onSpeed: () {},
                    onPortrait: () => exited = true,
                    onLock: () {},
                    onSeekStart: (_) {},
                    onSeek: (_) {},
                    onSeekEnd: (_) {},
                    onSeekCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('00:10'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('选集'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      await tester.tap(find.byTooltip('切回竖屏'));
      expect(exited, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lock affordance remains compact with no label or tooltip bubble',
    (tester) async {
      var unlocked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlayerLockButton(onUnlock: () => unlocked = true),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('player-unlock'))),
        const Size(44, 44),
      );
      expect(find.text('轻触解锁'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
      await tester.tap(find.byKey(const ValueKey('player-unlock')));
      expect(unlocked, true);
    },
  );
}

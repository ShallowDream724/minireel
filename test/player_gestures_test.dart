import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/domain/models/preferences.dart';
import 'package:minireel/features/player/episode_pager.dart';
import 'package:minireel/features/player/gesture_controller.dart';
import 'package:minireel/features/player/player_gesture_surface.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, this.landscape = false});
  final bool landscape;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool playing = true;
  bool topVisible = false;
  bool menu = false;
  bool locked = false;
  bool _closing = false;
  int index = 0;
  GestureHud? hud;
  final boosts = <bool>[];
  final seeks = <Duration>[];
  final scrubs = <bool>[];
  final selected = <int>[];
  final scrolling = <bool>[];
  late final controller = PlayerGestureController(
    onTap: () => setState(() {
      if (!widget.landscape) playing = !playing;
      topVisible = true;
    }),
    onMenu: () => setState(() => menu = true),
    onBoost: boosts.add,
    onSeek: seeks.add,
    onScrubState: scrubs.add,
    onHud: (value) {
      if (!_closing && mounted) setState(() => hud = value);
    },
    onHaptic: () {},
    readPosition: () => const Duration(seconds: 30),
    readDuration: () => const Duration(seconds: 90),
  );

  void lock() {
    controller.cancel();
    setState(() => locked = true);
  }

  @override
  void dispose() {
    _closing = true;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: widget.landscape ? 600 : 360,
          height: widget.landscape ? 320 : 500,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlayerGestureSurface(
                key: const ValueKey('surface'),
                controller: controller,
                enabled: !menu,
                locked: locked,
                landscape: widget.landscape,
                sensitivity: GestureSensitivity.medium,
                child: widget.landscape
                    ? const ColoredBox(color: Colors.black)
                    : EpisodePager(
                        index: index,
                        count: 4,
                        enabled: !locked && !menu && hud == null,
                        onSelected: (value) {
                          selected.add(value);
                          setState(() => index = value);
                        },
                        onScrollingChanged: (value) {
                          scrolling.add(value);
                          if (value) controller.cancel();
                        },
                        itemBuilder: (_, index) => ColoredBox(
                          color: Colors.primaries[index],
                          child: Center(child: Text('Episode $index')),
                        ),
                      ),
              ),
              if (topVisible)
                const Positioned(
                  top: 8,
                  left: 40,
                  right: 40,
                  child: IgnorePointer(child: Text('Top controls')),
                ),
              if (menu)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(child: Text('Playback menu')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Offset point(WidgetTester tester, double x, double y) {
  final rect = tester.getRect(find.byKey(const ValueKey('surface')));
  return Offset(rect.left + rect.width * x, rect.top + rect.height * y);
}

void main() {
  testWidgets(
    'tap with a real PageView toggles playback and shows top controls',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.tapAt(point(tester, .5, .7));
      await tester.pump();
      expect(key.currentState!.playing, isFalse);
      expect(find.text('Top controls'), findsOneWidget);
      expect(key.currentState!.scrolling, isEmpty);
      expect(key.currentState!.selected, isEmpty);
      await tester.tapAt(point(tester, .5, .7));
      await tester.pump();
      expect(key.currentState!.playing, isTrue);
      expect(key.currentState!.boosts, isEmpty);
    },
  );

  testWidgets(
    'upper long press opens the menu without starting the pager or tapping',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final touch = await tester.startGesture(point(tester, .5, .25));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Playback menu'), findsOneWidget);
      expect(key.currentState!.scrolling, isEmpty);
      expect(key.currentState!.boosts, isEmpty);
      await touch.up();
      await tester.pump();
      expect(key.currentState!.playing, isTrue);
      expect(key.currentState!.topVisible, isFalse);
    },
  );

  testWidgets(
    'lower hold owns horizontal and vertical movement until seek is committed',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final touch = await tester.startGesture(point(tester, .5, .75));
      await tester.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.boosts, [true]);
      expect(key.currentState!.hud!.kind, GestureHudKind.boost);
      await touch.moveBy(const Offset(100, -180));
      await tester.pump();
      expect(key.currentState!.hud!.kind, GestureHudKind.seek);
      expect(key.currentState!.seeks, isEmpty);
      expect(key.currentState!.selected, isEmpty);
      expect(key.currentState!.scrolling, isEmpty);
      await touch.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.boosts, [true, false]);
      expect(
        key.currentState!.seeks.single,
        greaterThan(const Duration(seconds: 30)),
      );
      expect(key.currentState!.scrubs, [true, false]);
      expect(key.currentState!.hud, isNull);
      expect(key.currentState!.playing, isTrue);
      expect(key.currentState!.topVisible, isFalse);
    },
  );

  testWidgets(
    'a vertical drag wins over pending tap and hold and settles on the next episode',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final touch = await tester.startGesture(point(tester, .5, .75));
      await touch.moveBy(const Offset(0, -310));
      await tester.pump(const Duration(milliseconds: 500));
      expect(key.currentState!.boosts, isEmpty);
      expect(key.currentState!.menu, isFalse);
      expect(key.currentState!.selected, isEmpty);
      await touch.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, [1]);
      expect(key.currentState!.scrolling, [true, false]);
      expect(key.currentState!.topVisible, isFalse);
      expect(key.currentState!.playing, isTrue);
    },
  );

  testWidgets(
    'cancelled hold and multi-touch restore speed without committing a seek',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      var touch = await tester.startGesture(point(tester, .5, .75));
      await tester.pump(const Duration(milliseconds: 400));
      await touch.moveBy(const Offset(70, 0));
      await tester.pump();
      await touch.cancel();
      await tester.pumpAndSettle();
      expect(key.currentState!.boosts, [true, false]);
      expect(key.currentState!.seeks, isEmpty);
      expect(key.currentState!.hud, isNull);
      touch = await tester.startGesture(point(tester, .5, .75), pointer: 2);
      await tester.pump(const Duration(milliseconds: 400));
      final second = await tester.startGesture(
        point(tester, .65, .75),
        pointer: 3,
      );
      await second.up();
      await touch.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.boosts, [true, false, true, false]);
      expect(key.currentState!.seeks, isEmpty);
      expect(key.currentState!.playing, isTrue);
      expect(key.currentState!.topVisible, isFalse);
    },
  );

  testWidgets(
    'locking during a hold restores speed and suppresses subsequent input',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final touch = await tester.startGesture(point(tester, .5, .75));
      await tester.pump(const Duration(milliseconds: 400));
      key.currentState!.lock();
      await tester.pump();
      await touch.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.boosts, [true, false]);
      await tester.tapAt(point(tester, .5, .75));
      await tester.dragFrom(point(tester, .5, .75), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(key.currentState!.playing, isTrue);
      expect(key.currentState!.topVisible, isFalse);
      expect(key.currentState!.seeks, isEmpty);
      expect(key.currentState!.selected, isEmpty);
    },
  );

  testWidgets('long press scrubbing clamps at the end of the episode', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key));
    final touch = await tester.startGesture(point(tester, .5, .75));
    await tester.pump(const Duration(milliseconds: 400));
    await touch.moveBy(const Offset(1000, 0));
    await tester.pump();
    expect(key.currentState!.hud!.position, const Duration(seconds: 90));
    await touch.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.seeks, [const Duration(seconds: 90)]);
    expect(key.currentState!.selected, isEmpty);
  });

  testWidgets(
    'landscape keeps horizontal seek and hold while both vertical edges are inert',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, landscape: true));
      await tester.dragFrom(point(tester, .5, .5), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(key.currentState!.seeks, hasLength(1));
      expect(
        key.currentState!.seeks.single,
        greaterThan(const Duration(seconds: 30)),
      );
      for (final x in [.2, .8]) {
        await tester.dragFrom(point(tester, x, .7), const Offset(0, -100));
        await tester.pumpAndSettle();
      }
      expect(key.currentState!.seeks, hasLength(1));
      expect(key.currentState!.hud, isNull);
      expect(key.currentState!.boosts, isEmpty);
      final touch = await tester.startGesture(point(tester, .5, .2));
      await tester.pump(const Duration(milliseconds: 400));
      await touch.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.boosts, [true, false]);
      expect(key.currentState!.menu, isFalse);
      expect(find.byType(EpisodePager), findsNothing);
    },
  );
}

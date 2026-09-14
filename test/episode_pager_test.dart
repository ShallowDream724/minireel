import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/features/player/episode_pager.dart';

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;
  bool enabled = true;
  final selected = <int>[];
  final scrolling = <bool>[];

  void select(int value) => setState(() => index = value);
  void lock() => setState(() => enabled = false);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 500,
          child: EpisodePager(
            index: index,
            count: 4,
            enabled: enabled,
            onSelected: (value) {
              selected.add(value);
              select(value);
            },
            onScrollingChanged: scrolling.add,
            itemBuilder: (_, index) => ColoredBox(
              color: Colors.primaries[index],
              child: Center(child: Text('Episode $index')),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pages follow the finger and select only after settling', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key));
    final pager = find.byKey(const ValueKey('episode-pager'));
    final before = tester.getCenter(find.text('Episode 0'));
    final drag = await tester.startGesture(tester.getCenter(pager));
    await drag.moveBy(const Offset(0, -310));
    await tester.pump();
    expect(
      tester.getCenter(find.text('Episode 0')).dy,
      lessThan(before.dy - 100),
    );
    expect(key.currentState!.selected, isEmpty);
    expect(key.currentState!.scrolling.first, isTrue);
    await drag.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.selected, [1]);
    expect(key.currentState!.scrolling.last, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short drag returns to the same episode without a selection', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key));
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('episode-pager'))),
    );
    await drag.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 250));
    await drag.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.selected, isEmpty);
    expect(key.currentState!.index, 0);
    expect(key.currentState!.scrolling.last, isFalse);
  });

  testWidgets(
    'an external episode selection moves the viewport without selecting twice',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      key.currentState!.select(3);
      await tester.pumpAndSettle();
      final center = tester.getCenter(
        find.byKey(const ValueKey('episode-pager')),
      );
      expect(
        tester.getCenter(find.text('Episode 3')).dy,
        closeTo(center.dy, 1),
      );
      expect(key.currentState!.selected, isEmpty);
      key.currentState!.select(2);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Episode 2')).dy,
        closeTo(center.dy, 1),
      );
      expect(key.currentState!.selected, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'locking during a drag restores the active page without changing episodes',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final pager = find.byKey(const ValueKey('episode-pager'));
      final drag = await tester.startGesture(tester.getCenter(pager));
      await drag.moveBy(const Offset(0, -310));
      await tester.pump();
      key.currentState!.lock();
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, isEmpty);
      expect(
        tester.getCenter(find.text('Episode 0')).dy,
        closeTo(tester.getCenter(pager).dy, 1),
      );
      expect(key.currentState!.scrolling.last, isFalse);
      await tester.drag(pager, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, isEmpty);
    },
  );
}

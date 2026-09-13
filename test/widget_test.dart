import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/app/app.dart';
import 'package:minireel/app/app_controller.dart';
import 'package:minireel/data/repositories/drama_repository.dart';
import 'package:minireel/data/sources/source_adapter.dart';
import 'package:minireel/domain/models/preferences.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'library, search, favorites and settings work on a compact Android screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..favorites[sampleDrama.id] = sampleDrama;
      final app = AppController(
        store,
        DramaRepository(SourceRegistry([FakeSource()]), store),
      );
      await app.initialize();
      await tester.pumpWidget(MiniReelApp(controller: app));
      await tester.pumpAndSettle();
      expect(find.text('雨夜重逢'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '雨夜');
      await tester.pumpAndSettle();
      expect(find.text('已加载剧库中找到 1 部'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('收藏 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('默认倍速'), findsOneWidget);
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(app.preferences.appearance, AppAppearance.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      app.repository.dispose();
      app.dispose();
    },
  );

  testWidgets('large text keeps settings usable at 360 dp', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore()
      ..preferences = const Preferences(largeText: true);
    final app = AppController(
      store,
      DramaRepository(SourceRegistry([FakeSource()]), store),
    );
    await app.initialize();
    await tester.pumpWidget(MiniReelApp(controller: app));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.repository.dispose();
    app.dispose();
  });
}

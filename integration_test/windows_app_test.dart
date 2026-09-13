import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:minireel/app/app_controller.dart';
import 'package:minireel/desktop/desktop_window.dart';
import 'package:minireel/features/library/library_screen.dart';
import 'package:minireel/features/player/desktop_player_screen.dart';
import 'package:minireel/features/shared/widgets.dart';
import 'package:minireel/main.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows app plays real video and retains state across native window changes',
    (tester) async {
      await DesktopWindow.instance.initialize();
      MediaKit.ensureInitialized();
      final screenshot = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: screenshot, child: const MiniReelBootstrap()),
      );

      Future<void> until(bool Function() condition, String stage) async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) fail('Timed out: $stage');
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<void> capture(String name) async {
        const directory = String.fromEnvironment('MINIREEL_QA_DIR');
        if (directory.isEmpty) return;
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(() async {
          final boundary =
              screenshot.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await until(
        () => find.byType(DramaCard).evaluate().isNotEmpty,
        'catalog',
      );
      expect(find.byKey(const ValueKey('desktop-navigation')), findsOneWidget);
      await capture('library');
      final app = AppScope.read(tester.element(find.byType(LibraryScreen)));
      final drama = tester
          .widget<DramaCard>(find.byType(DramaCard).first)
          .drama;
      await tester.tap(find.byType(DramaCard).first);
      await until(
        () => find.byType(DesktopPlayerScreen).evaluate().isNotEmpty,
        'desktop player',
      );
      final player = tester.widget<Video>(find.byType(Video)).controller.player;
      await until(
        () => player.state.position > const Duration(seconds: 1),
        'real video playback',
      );
      await capture('player');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await until(() => !player.state.playing, 'space pauses');
      final paused = player.state.position;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await until(
        () => player.state.position >= paused + const Duration(seconds: 4),
        'arrow seek',
      );
      expect(player.state.playing, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await until(() => DesktopWindow.instance.fullScreen, 'native fullscreen');
      expect(await windowManager.isFullScreen(), true);
      await capture('fullscreen');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await until(() => !DesktopWindow.instance.fullScreen, 'exit fullscreen');

      await DesktopWindow.instance.changePlayerMode(
        PlayerWindowMode.mini,
        9 / 16,
      );
      expect(await windowManager.isAlwaysOnTop(), true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.state.playing, false);
      await capture('mini');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await until(
        () => DesktopWindow.instance.mode == PlayerWindowMode.normal,
        'restore window',
      );

      await tester.runAsync(() async {
        await windowManager.minimize();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await windowManager.restore();
        await windowManager.focus();
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.state.playing, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await until(() => player.state.playing, 'resume after window restore');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('desktop-player-panel')),
        findsOneWidget,
      );
      expect(player.state.playing, true);
      await capture('episodes');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await until(
        () =>
            player.state.position > const Duration(seconds: 1) &&
            find.textContaining('第 2 集').evaluate().isNotEmpty,
        'next episode',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await until(
        () => find.byType(DesktopPlayerScreen).evaluate().isEmpty,
        'back to library',
      );
      await app.flush();
      expect(
        (await app.store.readHistory()).any(
          (record) => record.drama.id == drama.id && record.episodeIndex == 2,
        ),
        true,
      );
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pump(const Duration(milliseconds: 300));
      await capture('settings');
      expect(tester.takeException(), isNull);
    },
    skip: !Platform.isWindows,
  );
}

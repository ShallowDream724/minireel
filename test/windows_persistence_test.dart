import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/data/local/sqlite_app_store.dart';
import 'package:minireel/desktop/desktop_window.dart';
import 'package:minireel/domain/models/preferences.dart';
import 'package:minireel/domain/models/watch_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fakes.dart';

void main() {
  test(
    'Windows SQLite keeps preferences, favorites and progress after reopening',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'minireel-sqlite-test-',
      );
      final databasePath = '${directory.path}/minireel.db';
      addTearDown(() => directory.delete(recursive: true));
      final store = await SqliteAppStore.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      await store.savePreferences(
        const Preferences(desktopVolume: .35, pauseWhenMinimized: false),
      );
      await store.setFavorite(sampleDrama, true);
      await store.saveRecord(
        WatchRecord(
          drama: sampleDrama,
          episodeId: sampleEpisodes[1].id,
          episodeIndex: 2,
          position: const Duration(seconds: 42),
          duration: const Duration(seconds: 120),
          updatedAt: DateTime.now(),
        ),
      );
      await store.close();
      final reopened = await SqliteAppStore.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      addTearDown(reopened.close);
      final preferences = await reopened.readPreferences();
      expect(preferences.desktopVolume, .35);
      expect(preferences.pauseWhenMinimized, false);
      expect((await reopened.readFavorites()).single.id, sampleDrama.id);
      final history = (await reopened.readHistory()).single;
      expect(history.episodeIndex, 2);
      expect(history.position.inSeconds, 42);
    },
  );

  test('old preferences migrate and invalid desktop volume stays bounded', () {
    expect(Preferences.fromJson({}).desktopVolume, .75);
    expect(Preferences.fromJson({}).pauseWhenMinimized, true);
    expect(Preferences.fromJson({'desktopVolume': 4}).desktopVolume, 1);
    expect(
      Preferences.fromJson({'desktopVolume': double.nan}).desktopVolume,
      .75,
    );
  });

  test('window restore stays reachable after removing a monitor', () {
    const area = Rect.fromLTWH(0, 0, 1280, 720);
    final restored = fitWindowBounds(
      const Rect.fromLTWH(2200, 1400, 1600, 1000),
      [area],
    );
    expect(restored, area);
    const leftMonitor = Rect.fromLTWH(-1920, 0, 1920, 1040);
    const previous = Rect.fromLTWH(-1700, 60, 1100, 760);
    expect(fitWindowBounds(previous, [area, leftMonitor]), previous);
  });

  test(
    'successive fullscreen commands retain the final requested state',
    () async {
      final window = DesktopWindow();
      await Future.wait([window.toggleFullScreen(), window.toggleFullScreen()]);
      expect(window.fullScreen, false);
      window.dispose();
    },
  );
}

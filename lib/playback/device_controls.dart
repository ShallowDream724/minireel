import 'dart:io';

import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'playback_engine.dart';

/// Platform-specific capabilities stay outside the player and source adapters.
final class DeviceControls {
  DeviceControls(this.engine);
  final PlaybackEngine engine;
  bool _disposed = false;
  double brightness = .8;
  double volume = .5;
  bool applicationBrightnessAvailable = true;
  void Function(double)? onVolumeChanged;

  Future<void> initialize() async {
    if (Platform.isWindows) {
      applicationBrightnessAvailable = false;
      brightness = 1;
      volume = 1;
      return;
    }
    try {
      brightness = (await ScreenBrightness.instance.application).clamp(
        .03,
        1.0,
      );
    } on PlatformException {
      applicationBrightnessAvailable = false;
    } on MissingPluginException {
      applicationBrightnessAvailable = false;
    }
    if (Platform.isAndroid) {
      try {
        final controller = VolumeController.instance;
        controller.showSystemUI = false;
        volume = await controller.getVolume();
        if (!_disposed) {
          controller.addListener((value) {
            volume = value;
            if (!_disposed) onVolumeChanged?.call(value);
          });
        }
      } on PlatformException {
        volume = .5;
      }
    } else {
      volume = 1;
    }
  }

  Future<void> setBrightness(double value) async {
    brightness = value.clamp(.03, 1.0);
    if (_disposed || !applicationBrightnessAvailable) return;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness,
      );
    } on PlatformException {
      applicationBrightnessAvailable = false;
    }
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 1);
    if (_disposed) return;
    if (Platform.isAndroid) {
      try {
        await VolumeController.instance.setVolume(volume);
      } on PlatformException {
        await engine.setVolume(volume);
      }
    } else {
      await engine.setVolume(volume);
    }
  }

  Future<void> keepAwake(bool enabled) async {
    if (_disposed && enabled) return;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on PlatformException {
      /* Some desktop shells do not expose this capability. */
    } on MissingPluginException {
      /* Optional in headless tests. */
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (Platform.isAndroid) {
      VolumeController.instance.removeListener();
      VolumeController.instance.showSystemUI = true;
    }
    if (!Platform.isWindows) {
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } on PlatformException {
        /* Brightness was never overridden. */
      } on MissingPluginException {
        /* Optional capability on future platforms. */
      }
    }
    await keepAwake(false);
  }
}

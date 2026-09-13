import 'dart:io';

import 'package:image/image.dart' as img;

/// Deterministic app icons derived from the user's original artwork.
void main(List<String> arguments) {
  final logo = img.decodePng(File('assets/logo.png').readAsBytesSync())!;
  final legacy = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fill(legacy, color: img.ColorRgba8(16, 19, 24, 255));
  img.compositeImage(
    legacy,
    img.copyResize(
      logo,
      width: 820,
      height: 820,
      interpolation: img.Interpolation.cubic,
    ),
    dstX: 102,
    dstY: 102,
  );
  const densities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  final windows = Directory('windows/runner/resources')
    ..createSync(recursive: true);
  File('${windows.path}/app_icon.ico').writeAsBytesSync(
    img.encodeIco(img.copyResize(legacy, width: 256, height: 256)),
  );
  if (arguments.contains('--windows-only')) {
    stdout.writeln('Generated Windows icon from assets/logo.png');
    return;
  }
  for (final entry in densities.entries) {
    final dir = Directory('android/app/src/main/res/mipmap-${entry.key}')
      ..createSync(recursive: true);
    File('${dir.path}/ic_launcher.png').writeAsBytesSync(
      img.encodePng(
        img.copyResize(
          legacy,
          width: entry.value,
          height: entry.value,
          interpolation: img.Interpolation.average,
        ),
      ),
    );
  }
  final foreground = img.Image(width: 432, height: 432, numChannels: 4);
  img.compositeImage(
    foreground,
    img.copyResize(
      logo,
      width: 300,
      height: 300,
      interpolation: img.Interpolation.cubic,
    ),
    dstX: 66,
    dstY: 66,
  );
  final dir = Directory('android/app/src/main/res/drawable-nodpi')
    ..createSync(recursive: true);
  File(
    '${dir.path}/ic_launcher_foreground.png',
  ).writeAsBytesSync(img.encodePng(foreground));
  final previewDir = Directory('output/qa')..createSync(recursive: true);
  File('${previewDir.path}/launcher-icon.png').writeAsBytesSync(
    img.encodePng(img.copyResize(legacy, width: 256, height: 256)),
  );
  stdout.writeln('Generated Windows and Android icons from assets/logo.png');
}

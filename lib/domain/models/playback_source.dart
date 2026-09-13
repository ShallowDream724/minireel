import 'dart:typed_data';

enum PlaybackKind { direct, hls, cenc }

enum PlaybackRoute { primary, fallback }

/// Ephemeral data. Deliberately has no JSON/storage representation.
final class PlaybackSource {
  const PlaybackSource({
    required this.uri,
    required this.kind,
    required this.headers,
    this.quality = '原画',
    this.contentKey,
    this.keyId,
    this.duration,
    this.route = PlaybackRoute.primary,
  });

  final Uri uri;
  final PlaybackKind kind;
  final Map<String, String> headers;
  final String quality;
  final Uint8List? contentKey;
  final String? keyId;
  final Duration? duration;
  final PlaybackRoute route;

  String get keyHex =>
      contentKey
          ?.map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join() ??
      '';
}

final class PlaybackOptions {
  PlaybackOptions(List<PlaybackSource> sources)
    : sources = List.unmodifiable(sources) {
    if (sources.isEmpty) {
      throw ArgumentError('Playback sources cannot be empty');
    }
  }
  final List<PlaybackSource> sources;

  PlaybackSource select(String preference) {
    if (preference == '自动' || sources.length == 1) return sources.first;
    return sources.firstWhere(
      (source) => source.quality == preference,
      orElse: () => sources.first,
    );
  }
}

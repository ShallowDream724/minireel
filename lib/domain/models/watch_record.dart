import 'drama.dart';

final class WatchRecord {
  const WatchRecord({
    required this.drama,
    required this.episodeId,
    required this.episodeIndex,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final Drama drama;
  final String episodeId;
  final int episodeIndex;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  bool get completed =>
      duration > Duration.zero &&
      position >= duration - const Duration(seconds: 1);

  double get progress => duration.inMilliseconds > 0
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0;

  Map<String, dynamic> toJson() => {
    'drama': drama.toJson(),
    'episodeId': episodeId,
    'episodeIndex': episodeIndex,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory WatchRecord.fromJson(Map<String, dynamic> json) => WatchRecord(
    drama: Drama.fromJson(json['drama'] as Map<String, dynamic>),
    episodeId: json['episodeId'] as String,
    episodeIndex: json['episodeIndex'] as int,
    position: Duration(milliseconds: json['positionMs'] as int),
    duration: Duration(milliseconds: json['durationMs'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
  );
}

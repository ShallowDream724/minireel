import '../../../domain/models/drama.dart';
import 'hongguo_parser.dart';

double? hongguoNumber(String value) {
  final match = RegExp(
    r'(-?\d+(?:\.\d+)?)\s*(亿|万|[kKmM])?',
  ).firstMatch(value.replaceAll(',', ''));
  if (match == null) return null;
  final number = double.tryParse(match[1]!);
  if (number == null || !number.isFinite || number < 0) return null;
  final multiplier = switch (match[2]?.toLowerCase()) {
    '亿' => 100000000,
    '万' => 10000,
    'k' => 1000,
    'm' => 1000000,
    _ => 1,
  };
  final result = number * multiplier;
  return result.isFinite ? result : null;
}

DateTime? hongguoOnlineDate(Map<String, dynamic> row, {DateTime? now}) {
  final timestamp = num.tryParse(field(row, ['first_visible_time']));
  if (timestamp != null && timestamp.isFinite && timestamp > 0) {
    final millis = timestamp < 100000000000 ? timestamp * 1000 : timestamp;
    if (millis < 4102444800000) {
      final china = DateTime.fromMillisecondsSinceEpoch(
        millis.round(),
        isUtc: true,
      ).add(const Duration(hours: 8));
      return DateTime.utc(china.year, china.month, china.day);
    }
  }
  final chinaNow = (now ?? DateTime.now()).toUtc().add(
    const Duration(hours: 8),
  );
  final today = DateTime.utc(chinaNow.year, chinaNow.month, chinaNow.day);
  for (final item in anyList(row['sub_title_list'])) {
    final label = field(objectMap(item), ['content']);
    if (label == '今日上新') return today;
    if (label == '昨日上新') return today.subtract(const Duration(days: 1));
    final match = RegExp(
      r'^(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?上新$',
    ).firstMatch(label);
    if (match == null) continue;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);
    if (date.year == year && date.month == month && date.day == day) {
      return date;
    }
  }
  return null;
}

DramaChannel hongguoChannel(
  Map<String, dynamic> row, {
  DramaChannel fallback = DramaChannel.real,
}) {
  final data = {...row, ...objectMap(row['video_data'])};
  final kind = field(data, [
    'genre',
    'genre_name',
    'channel_name',
    'category_name',
  ]);
  if (kind == 'ai_series' || kind.contains('AI剧')) return DramaChannel.ai;
  if (kind == 'comic_series' || kind.contains('漫剧')) {
    return DramaChannel.comicDrama;
  }
  if (kind == 'short_play' || kind.contains('真人剧')) return DramaChannel.real;
  if (kind == '动漫') return DramaChannel.animation;
  return fallback;
}

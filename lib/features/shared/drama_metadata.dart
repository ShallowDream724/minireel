import '../../domain/models/catalog_order.dart';
import '../../domain/models/drama.dart';

String compactCount(num value) {
  if (value >= 100000000) return '${(value / 100000000).toStringAsFixed(1)}亿';
  if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}

String calendarDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<String> dramaMetadata(Drama drama) => [
  if (drama.score != null) '评分 ${drama.score!.toStringAsFixed(1)}',
  if (drama.heat != null) '${compactCount(drama.heat!)} 热度',
  if (drama.views != null) '${compactCount(drama.views!)} 次播放',
  if (drama.onlineDate != null) '${calendarDate(drama.onlineDate!)} 上线',
];

String? sortMetric(Drama drama, CatalogOrder order) => switch (order) {
  CatalogOrder.latest =>
    drama.onlineDate == null
        ? '上线日期暂无'
        : '${calendarDate(drama.onlineDate!)} 上线',
  CatalogOrder.heat =>
    drama.heat == null ? '热度暂无' : '${compactCount(drama.heat!)} 热度',
  CatalogOrder.views =>
    drama.views == null ? '播放量暂无' : '${compactCount(drama.views!)} 次播放',
  _ => null,
};

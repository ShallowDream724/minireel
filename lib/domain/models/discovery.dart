import 'drama.dart';

final class SearchResult {
  SearchResult({
    required List<Drama> items,
    required this.total,
    this.warnings = const [],
  }) : items = List.unmodifiable(items);
  final List<Drama> items;
  final int total;
  final List<String> warnings;
}

enum RankingType {
  hot('总热播'),
  realDrama('真人剧'),
  comicDrama('漫剧'),
  aiDrama('AI剧');

  const RankingType(this.label);
  final String label;
}

final class RankingItem {
  const RankingItem({
    required this.rank,
    required this.drama,
    this.metric = '',
  });
  final int rank;
  final Drama drama;
  final String metric;
}

final class RankingPage {
  RankingPage({
    required this.type,
    required this.page,
    required List<RankingItem> items,
    required this.totalPages,
    this.updatedText = '',
  }) : items = List.unmodifiable(items);
  final RankingType type;
  final int page;
  final List<RankingItem> items;
  final int totalPages;
  final String updatedText;
  bool get hasMore => page < totalPages;
}

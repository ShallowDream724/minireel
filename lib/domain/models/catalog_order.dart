import 'drama.dart';

enum CatalogOrder {
  recommended('默认'),
  latest('最新上线'),
  heat('热度'),
  views('播放量'),
  title('剧名'),
  short('集数少优先');

  const CatalogOrder(this.label);
  final String label;
}

/// Missing values always sort last; ties retain their original catalog order.
void sortCatalog(List<Drama> items, CatalogOrder order) {
  if (order == CatalogOrder.recommended) return;
  final positions = {for (var i = 0; i < items.length; i++) items[i].id: i};
  int numeric(num? a, num? b, {bool ascending = false}) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return ascending ? a.compareTo(b) : b.compareTo(a);
  }

  items.sort((a, b) {
    final result = switch (order) {
      CatalogOrder.latest => numeric(
        a.onlineDate?.millisecondsSinceEpoch,
        b.onlineDate?.millisecondsSinceEpoch,
      ),
      CatalogOrder.heat => numeric(a.heat, b.heat),
      CatalogOrder.views => numeric(a.views, b.views),
      CatalogOrder.title => a.title.compareTo(b.title),
      CatalogOrder.short => numeric(
        a.episodeCount > 0 ? a.episodeCount : null,
        b.episodeCount > 0 ? b.episodeCount : null,
        ascending: true,
      ),
      CatalogOrder.recommended => 0,
    };
    return result == 0 ? positions[a.id]!.compareTo(positions[b.id]!) : result;
  });
}

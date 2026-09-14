import 'drama.dart';

final class CatalogCursor {
  const CatalogCursor({
    this.offset = 0,
    this.sessionId = '',
    this.lastId = '',
    this.initialized = false,
    this.exhausted = false,
    this.updatedAt,
    this.webPage = 0,
    this.webExhausted = false,
  });
  final int offset;
  final String sessionId;
  final String lastId;
  final bool initialized;
  final bool exhausted;
  final DateTime? updatedAt;
  final int webPage;
  final bool webExhausted;
  Map<String, dynamic> toJson() => {
    'offset': offset,
    'sessionId': sessionId,
    'lastId': lastId,
    'initialized': initialized,
    'exhausted': exhausted,
    'updatedAt': updatedAt?.toIso8601String(),
    'webPage': webPage,
    'webExhausted': webExhausted,
  };
  factory CatalogCursor.fromJson(Map<String, dynamic> json) => CatalogCursor(
    offset: ((json['offset'] as num?)?.toInt() ?? 0).clamp(0, 1000000),
    sessionId: json['sessionId'] as String? ?? '',
    lastId: json['lastId'] as String? ?? '',
    initialized: json['initialized'] == true,
    exhausted: json['exhausted'] == true,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    webPage: ((json['webPage'] as num?)?.toInt() ?? 0).clamp(0, 100),
    webExhausted: json['webExhausted'] == true,
  );
}

final class CatalogPage {
  const CatalogPage(this.items, this.cursor, {required this.hasMore});
  final List<Drama> items;
  final CatalogCursor cursor;
  final bool hasMore;
}

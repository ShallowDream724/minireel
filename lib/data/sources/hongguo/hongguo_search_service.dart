import 'package:dio/dio.dart';

import '../../../core/config/source_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_cache.dart';
import '../../../domain/models/discovery.dart';
import '../../../domain/models/drama.dart';
import 'hongguo_metadata.dart';
import 'hongguo_parser.dart';

final class HongguoSearchService {
  HongguoSearchService(this.config, this.client);
  final SourceConfig config;
  final TextClient client;
  final _cache = RequestCache<SearchResult>();
  void clear() => _cache.clear();

  Future<SearchResult> search(String query, {CancelToken? cancelToken}) {
    final keyword = query.trim();
    if (keyword.isEmpty ||
        keyword.runes.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(keyword)) {
      throw const AppException('请输入 1 至 80 个字符的搜索词');
    }
    return _cache.get(keyword, (token) async {
      final uri = config.baseUrl.replace(
        pathSegments: ['', 'search', keyword],
        query: '',
        fragment: '',
      );
      final html = await client.getText(uri, cancelToken: token);
      return parse(html, keyword);
    }, cancelToken: cancelToken);
  }

  SearchResult parse(String html, String keyword) {
    const parser = HongguoParser();
    final page = parser.loader(parser.routerData(html), [
      'search_(keyword)/page',
      'search_',
    ]);
    final rows = page['searchList'];
    if (page['isSuccess'] != true ||
        rows is! List ||
        field(page, ['query']) != keyword) {
      throw const AppException('搜索未返回有效结果，请稍后重试');
    }
    final items = <String, Drama>{};
    for (final row in rows) {
      final data = objectMap(row);
      if (objectMap(data['video_data']).isEmpty) continue;
      final drama = parser.dramaFrom(data, hongguoChannel(data));
      if (drama != null && RegExp(r'^[0-9]{1,32}$').hasMatch(drama.sourceId)) {
        items[drama.id] = drama;
      }
    }
    if (rows.isNotEmpty && items.isEmpty) {
      throw const AppException('搜索结果暂时无法读取');
    }
    final total = int.tryParse(field(page, ['totalCount'])) ?? items.length;
    return SearchResult(
      items: items.values.toList(),
      total: total < items.length ? items.length : total,
    );
  }
}

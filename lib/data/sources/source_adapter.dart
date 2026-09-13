import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/drama.dart';
import '../../domain/models/playback_source.dart';

abstract interface class DramaSourceAdapter {
  String get id;
  String get displayName;
  int get maxPages;
  int get pageSize;

  Future<List<Drama>> fetchCatalog(
    DramaChannel channel,
    int page, {
    CancelToken? cancelToken,
  });
  Future<DramaDetail> fetchDetail(Drama drama, {CancelToken? cancelToken});
  Future<PlaybackOptions> resolvePlayback(
    Drama drama,
    Episode episode, {
    CancelToken? cancelToken,
    bool fallbackOnly = false,
  });
}

final class SourceRegistry {
  SourceRegistry(Iterable<DramaSourceAdapter> adapters)
    : _adapters = {for (final adapter in adapters) adapter.id: adapter};

  final Map<String, DramaSourceAdapter> _adapters;
  Iterable<DramaSourceAdapter> get all => _adapters.values;
  DramaSourceAdapter require(String id) =>
      _adapters[id] ?? (throw const AppException('这个剧库暂不可用'));
}

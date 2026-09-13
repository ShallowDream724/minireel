import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/drama.dart';
import '../../domain/models/playback_source.dart';
import '../local/app_store.dart';
import '../sources/source_adapter.dart';

final class DramaRepository extends ChangeNotifier {
  DramaRepository(this.registry, this.store);

  final SourceRegistry registry;
  final AppStore store;
  final Map<String, Drama> _catalog = {};
  final Map<String, int> _pages = {};
  final Set<String> _exhausted = {};
  final Map<String, Set<String>> _previousPageIds = {};
  final Map<String, String> errors = {};
  CancelToken? _catalogToken;
  int _generation = 0;
  bool _disposed = false;
  bool refreshing = false;
  bool loadingMore = false;
  DateTime? lastRefresh;

  List<Drama> get catalog => List.unmodifiable(_catalog.values);
  bool get hasMore => registry.all.any(
    (source) => DramaChannel.values.any(
      (channel) => !_exhausted.contains('${source.id}:${channel.name}'),
    ),
  );

  bool hasMoreFor(DramaChannel? channel) => registry.all.any(
    (source) => (channel == null ? DramaChannel.values : [channel]).any(
      (channel) => !_exhausted.contains('${source.id}:${channel.name}'),
    ),
  );

  Future<void> loadCache() async {
    for (final drama in await store.readCatalog()) {
      _catalog[drama.id] = drama;
    }
    lastRefresh = await store.readLastRefresh();
    _notify();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    final generation = ++_generation;
    _catalogToken?.cancel();
    final token = _catalogToken = CancelToken();
    refreshing = true;
    loadingMore = false;
    errors.clear();
    _pages.clear();
    _exhausted.clear();
    _previousPageIds.clear();
    _notify();
    await Future.wait([
      for (final source in registry.all)
        for (final channel in DramaChannel.values)
          _fetchPage(source, channel, 1, token, generation),
    ]);
    if (_disposed || generation != _generation) return;
    refreshing = false;
    if (_pages.isNotEmpty) {
      lastRefresh = DateTime.now();
      await store.saveLastRefresh(lastRefresh!);
    }
    _notify();
  }

  Future<void> loadMore({DramaChannel? channel}) async {
    if (loadingMore || refreshing || !hasMoreFor(channel)) return;
    final generation = _generation;
    final token = _catalogToken ??= CancelToken();
    loadingMore = true;
    _notify();
    await Future.wait([
      for (final source in registry.all)
        for (final item in channel == null ? DramaChannel.values : [channel])
          if (!_exhausted.contains('${source.id}:${item.name}'))
            _fetchPage(
              source,
              item,
              (_pages['${source.id}:${item.name}'] ?? 0) + 1,
              token,
              generation,
            ),
    ]);
    if (_disposed || generation != _generation) return;
    loadingMore = false;
    _notify();
  }

  Future<void> _fetchPage(
    DramaSourceAdapter source,
    DramaChannel channel,
    int page,
    CancelToken token,
    int generation,
  ) async {
    final key = '${source.id}:${channel.name}';
    try {
      final items = await source.fetchCatalog(
        channel,
        page,
        cancelToken: token,
      );
      if (_disposed || generation != _generation || token.isCancelled) return;
      // Never clear cached rows before receiving a successful response. Pages
      // are merged; favorites/history carry independent metadata snapshots.
      await store.saveCatalog(items);
      if (_disposed || generation != _generation) return;
      final ids = items.map((drama) => drama.id).toSet();
      final repeatedPage = setEquals(ids, _previousPageIds[key]);
      _previousPageIds[key] = ids;
      for (final drama in items) {
        _catalog[drama.id] = drama;
      }
      _pages[key] = page;
      errors.remove(key);
      if (items.length < source.pageSize ||
          page >= source.maxPages ||
          repeatedPage) {
        _exhausted.add(key);
      }
      _notify();
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        errors[key] = '网络连接失败，请重试';
      }
    } on AppException catch (error) {
      if (!_disposed && generation == _generation) errors[key] = error.message;
    }
  }

  Future<DramaDetail> getDetail(Drama drama, {CancelToken? cancelToken}) async {
    try {
      final detail = await registry
          .require(drama.source)
          .fetchDetail(drama, cancelToken: cancelToken);
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      await store.saveDetail(detail);
      return detail;
    } on AppException {
      final cached = await store.readDetail(drama.id);
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<PlaybackOptions> resolve(
    Drama drama,
    Episode episode, {
    CancelToken? cancelToken,
    bool fallbackOnly = false,
  }) => registry
      .require(drama.source)
      .resolvePlayback(
        drama,
        episode,
        cancelToken: cancelToken,
        fallbackOnly: fallbackOnly,
      );

  Future<void> clearCache() async {
    ++_generation;
    _catalogToken?.cancel();
    refreshing = false;
    loadingMore = false;
    await store.clearCache();
    _catalog.clear();
    _pages.clear();
    _exhausted.clear();
    _previousPageIds.clear();
    errors.clear();
    lastRefresh = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _catalogToken?.cancel();
    super.dispose();
  }
}

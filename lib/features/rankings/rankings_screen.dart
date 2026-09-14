import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/models/discovery.dart';
import '../../domain/models/drama.dart';
import '../detail/detail_sheet.dart';
import '../shared/drama_list_tile.dart';
import '../shared/widgets.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, required this.onPlay});
  final void Function(Drama, [int?]) onPlay;
  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  RankingType _type = RankingType.hot;
  final _items = <RankingItem>[];
  CancelToken? _token;
  int _generation = 0;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  String _updated = '';
  String? _error;
  bool _retryRefresh = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading && !refresh) return;
    final generation = ++_generation;
    _token?.cancel();
    final token = _token = CancelToken();
    final page = refresh ? 1 : _page + 1;
    _retryRefresh = refresh;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AppScope.read(context).repository.getRanking(
        _type,
        page: page,
        refresh: refresh,
        cancelToken: token,
      );
      if (!mounted || generation != _generation) return;
      if (!refresh &&
          _items.any(
            (old) => result.items.any((item) => old.drama.id == item.drama.id),
          )) {
        _retryRefresh = true;
        throw const AppException('榜单分页返回重复内容，请刷新榜单');
      }
      setState(() {
        if (refresh) _items.clear();
        _items.addAll(result.items);
        _page = page;
        _hasMore = result.hasMore;
        _updated = result.updatedText;
      });
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) &&
          mounted &&
          generation == _generation) {
        setState(() => _error = '网络连接失败，请重试');
      }
    } on Exception catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = readableError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(RankingType type) {
    if (type == _type) return;
    _token?.cancel();
    setState(() {
      _type = type;
      _items.clear();
      _page = 0;
      _hasMore = true;
      _updated = '';
      _loading = false;
    });
    unawaited(_load());
  }

  void _play(Drama drama, [int? episode]) {
    Navigator.of(context).pop();
    widget.onPlay(drama, episode);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('热播榜'),
      actions: [
        IconButton(
          tooltip: '刷新榜单',
          onPressed: _loading ? null : () => _load(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                for (final type in RankingType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.label),
                      selected: type == _type,
                      onSelected: (_) => _select(type),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView(
                key: ValueKey(_type),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  if (_updated.isNotEmpty)
                    Text(
                      _updated,
                      style: TextStyle(color: context.muted, fontSize: 12),
                    ),
                  for (final item in _items)
                    DramaListTile(
                      drama: item.drama,
                      rank: item.rank,
                      metric: item.metric,
                      onTap: () => _play(item.drama),
                      onLongPress: () =>
                          showDramaDetail(context, item.drama, _play),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.muted),
                          ),
                          TextButton(
                            onPressed: () => _load(
                              refresh: _retryRefresh || _page == 0 || !_hasMore,
                            ),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_loading && _error == null && _items.isEmpty)
                    const EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: '暂无榜单内容',
                      subtitle: '稍后下拉刷新再看看',
                    ),
                  if (!_loading && _error == null && _items.isNotEmpty)
                    Center(
                      child: _hasMore
                          ? TextButton(
                              onPressed: _load,
                              child: const Text('加载更多'),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                '已显示全部榜单',
                                style: TextStyle(
                                  color: context.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

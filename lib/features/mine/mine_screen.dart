import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../domain/models/drama.dart';
import '../shared/widgets.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key, required this.onPlay, required this.onExplore});
  final void Function(Drama, [int?]) onPlay;
  final VoidCallback onExplore;
  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  int _tab = 0;
  bool _managing = false;
  final Set<String> _selection = {};

  void _select(String id) => setState(() {
    if (!_selection.add(id)) _selection.remove(id);
  });
  void _manage(String id) => setState(() {
    _managing = true;
    _selection.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final ids = _tab == 0
        ? app.favorites.map((drama) => drama.id).toList()
        : app.history.map((record) => record.drama.id).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
          child: Row(
            children: [
              Text(
                _managing ? '已选 ${_selection.length} 项' : '我的',
                style: TextStyle(
                  fontSize: _managing ? 21 : 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (ids.isNotEmpty || _managing)
                TextButton(
                  onPressed: () => setState(() {
                    _managing = !_managing;
                    _selection.clear();
                  }),
                  child: Text(
                    _managing ? '取消' : '管理',
                    style: TextStyle(color: context.muted),
                  ),
                ),
              if (_managing)
                TextButton(
                  onPressed: () => setState(() {
                    if (_selection.length == ids.length) {
                      _selection.clear();
                    } else {
                      _selection.addAll(ids);
                    }
                  }),
                  child: Text(_selection.length == ids.length ? '取消全选' : '全选'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.chipColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _segment(
                  '收藏${app.favorites.isEmpty ? '' : ' ${app.favorites.length}'}',
                  0,
                ),
                _segment(
                  '历史${app.history.isEmpty ? '' : ' ${app.history.length}'}',
                  1,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ids.isEmpty
              ? EmptyState(
                  icon: _tab == 0
                      ? Icons.favorite_border_rounded
                      : Icons.history_rounded,
                  title: _tab == 0 ? '把喜欢的故事留在这里' : '从一部好剧开始',
                  subtitle: _tab == 0 ? '收藏短剧，下次打开就能接着看' : '观看记录会自动保存，精彩随时继续',
                  action: '去发现短剧',
                  onAction: widget.onExplore,
                )
              : _tab == 0
              ? LayoutBuilder(
                  builder: (context, constraints) => MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    crossAxisCount: dramaColumns(constraints.maxWidth),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    itemCount: app.favorites.length,
                    itemBuilder: (context, index) {
                      final drama = app.favorites[index];
                      final record = app.historyOf(drama.id);
                      return DramaCard(
                        drama: drama,
                        favorite: true,
                        selecting: _managing,
                        selected: _selection.contains(drama.id),
                        onTap: () => _managing
                            ? _select(drama.id)
                            : widget.onPlay(drama),
                        onLongPress: () => _manage(drama.id),
                        footer: record == null
                            ? null
                            : Text(
                                '看到第 ${record.episodeIndex} 集',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.primary,
                                ),
                              ),
                      );
                    },
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 3, 16, 30),
                  itemCount: app.history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = app.history[index];
                    return Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _managing
                            ? _select(record.drama.id)
                            : widget.onPlay(record.drama),
                        onLongPress: () => _manage(record.drama.id),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            children: [
                              if (_managing)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Icon(
                                    _selection.contains(record.drama.id)
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: _selection.contains(record.drama.id)
                                        ? context.colors.primary
                                        : context.muted,
                                    size: 22,
                                  ),
                                ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 57,
                                  height: 80,
                                  child: CoverImage(drama: record.drama),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.drama.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '第 ${record.episodeIndex} 集 · ${formatTime(record.position)} / ${formatTime(record.duration)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: record.progress,
                                        minHeight: 3,
                                        backgroundColor: context.chipColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      relativeTime(record.updatedAt),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: context.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_managing)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 29,
                                    color: context.colors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_managing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selection.isEmpty ? null : () => _remove(app),
                child: Text(
                  _tab == 0
                      ? '取消收藏 ${_selection.length} 部'
                      : '删除 ${_selection.length} 条记录',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _segment(String label, int tab) => Expanded(
    child: Material(
      color: _tab == tab ? context.colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() {
          _tab = tab;
          _managing = false;
          _selection.clear();
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: _tab == tab ? context.colors.onSurface : context.muted,
                fontWeight: _tab == tab ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _remove(AppController app) async {
    final confirmed = await showReelSheet<bool>(
      context,
      builder: (context) => SheetFrame(
        title: _tab == 0 ? '取消收藏' : '删除观看记录',
        footer: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认删除'),
        ),
        child: Text(
          _tab == 0
              ? '将从收藏中移除选中的 ${_selection.length} 部短剧。'
              : '删除选中的 ${_selection.length} 条记录后，将不再记忆这些短剧的观看进度。',
          style: TextStyle(color: context.muted, height: 1.6),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_tab == 0) {
      app.removeFavorites(_selection);
    } else {
      app.removeHistory(_selection);
    }
    setState(() {
      _selection.clear();
      _managing = false;
    });
  }
}

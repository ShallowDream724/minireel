import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../domain/models/drama.dart';
import '../shared/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onPlay});
  final void Function(Drama, [int?]) onPlay;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setQuery(String text) => setState(() {
    _query.text = text;
    _query.selection = TextSelection.collapsed(offset: text.length);
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: app.addSearch,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '搜索剧名、题材或标签',
                        filled: true,
                        fillColor: context.chipColor,
                        hintStyle: TextStyle(color: context.muted),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: context.muted,
                        ),
                        suffixIcon: _query.text.isNotEmpty
                            ? IconButton(
                                tooltip: '清空搜索',
                                onPressed: () => _setQuery(''),
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: app.repository,
                builder: (context, _) {
                  final query = _query.text.trim();
                  final results = app.repository.catalog
                      .where((drama) => drama.matches(query))
                      .toList();
                  if (query.isEmpty) {
                    final tags = app.repository.catalog
                        .expand((drama) => drama.tags)
                        .toSet()
                        .take(10)
                        .toList();
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          '热门题材',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.muted,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            for (final tag in tags)
                              TagPill(tag, onTap: () => _setQuery(tag)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              '搜索历史',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.muted,
                              ),
                            ),
                            const Spacer(),
                            if (app.searches.isNotEmpty)
                              IconButton(
                                tooltip: '清除搜索历史',
                                onPressed: app.clearSearches,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: context.muted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            for (final text in app.searches)
                              TagPill(text, onTap: () => _setQuery(text)),
                          ],
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                    children: [
                      Text(
                        '已加载剧库中找到 ${results.length} 部',
                        style: TextStyle(color: context.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      for (final drama in results)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 5,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: SizedBox(
                              width: 42,
                              height: 60,
                              child: CoverImage(drama: drama),
                            ),
                          ),
                          title: Text(
                            drama.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              drama.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.muted,
                              ),
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: context.muted,
                          ),
                          onTap: () {
                            app.addSearch(query);
                            FocusScope.of(context).unfocus();
                            Navigator.of(context).pop();
                            widget.onPlay(drama);
                          },
                        ),
                      if (results.isEmpty)
                        EmptyState(
                          icon: Icons.search_off_rounded,
                          title: '还没找到「$query」',
                          subtitle: '试试更短的剧名，或加载更多短剧后再搜索',
                        ),
                      if (app.repository.hasMore)
                        Center(
                          child: TextButton(
                            onPressed:
                                app.repository.loadingMore ||
                                    app.repository.refreshing
                                ? null
                                : app.repository.loadMore,
                            child: Text(
                              app.repository.loadingMore
                                  ? '正在加载更多短剧…'
                                  : '加载更多短剧继续搜索',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

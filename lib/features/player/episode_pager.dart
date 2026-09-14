import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;

/// A real vertical viewport. Playback changes only after a page has settled.
class EpisodePager extends StatefulWidget {
  const EpisodePager({
    super.key,
    required this.index,
    required this.count,
    required this.enabled,
    required this.itemBuilder,
    required this.onSelected,
    required this.onScrollingChanged,
  });

  final int index;
  final int count;
  final bool enabled;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelected;
  final ValueChanged<bool> onScrollingChanged;

  @override
  State<EpisodePager> createState() => _EpisodePagerState();
}

class _EpisodePagerState extends State<EpisodePager> {
  late final PageController _controller;
  late int _settled;
  bool _scrolling = false;
  bool _synchronizing = false;
  int _syncGeneration = 0;

  @override
  void initState() {
    super.initState();
    _settled = widget.index;
    _controller = PageController(initialPage: widget.index, keepPage: false);
  }

  @override
  void didUpdateWidget(EpisodePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && widget.index != _settled) {
      _syncPage(animate: true);
    } else if (oldWidget.enabled && !widget.enabled && _scrolling) {
      _syncPage(animate: false);
    }
  }

  void _syncPage({required bool animate}) {
    final generation = ++_syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          generation != _syncGeneration ||
          !_controller.hasClients) {
        return;
      }
      final index = widget.index;
      final current = _controller.page ?? _settled.toDouble();
      _synchronizing = true;
      if (animate && widget.enabled && (current - index).abs() <= 1.01) {
        await _controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _controller.jumpToPage(index);
      }
      if (!mounted || generation != _syncGeneration) return;
      _settled = index;
      _synchronizing = false;
      _setScrolling(false);
    });
  }

  void _setScrolling(bool value) {
    if (_scrolling == value) return;
    _scrolling = value;
    widget.onScrollingChanged(value);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        ++_syncGeneration;
        _synchronizing = false;
      }
      _setScrolling(true);
    } else if (notification is ScrollEndNotification && !_synchronizing) {
      final page = _controller.hasClients ? _controller.page : null;
      if (page != null && widget.enabled) {
        final index = page.round().clamp(0, widget.count - 1);
        if ((page - index).abs() < .01) {
          _settled = index;
          if (index != widget.index) widget.onSelected(index);
        }
      }
      _setScrolling(false);
    }
    return false;
  }

  @override
  void dispose() {
    ++_syncGeneration;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: PageView.builder(
            key: const ValueKey('episode-pager'),
            controller: _controller,
            scrollDirection: Axis.vertical,
            dragStartBehavior: DragStartBehavior.down,
            allowImplicitScrolling: true,
            physics: widget.enabled
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.count,
            itemBuilder: widget.itemBuilder,
          ),
        ),
      );
}

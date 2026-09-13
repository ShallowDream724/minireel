import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/shared/widgets.dart';

class DesktopNavigation extends StatelessWidget {
  const DesktopNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('desktop-navigation'),
    width: 68,
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 18),
        const BrandMark(size: 34),
        const SizedBox(height: 26),
        _destination(
          context,
          0,
          '短剧库',
          Icons.movie_outlined,
          Icons.movie_rounded,
        ),
        const SizedBox(height: 12),
        _destination(
          context,
          1,
          '我的',
          Icons.person_outline_rounded,
          Icons.person_rounded,
        ),
        const Spacer(),
        _destination(context, 2, '设置', Icons.tune_rounded, Icons.tune_rounded),
        const SizedBox(height: 18),
      ],
    ),
  );

  Widget _destination(
    BuildContext context,
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
  ) => Semantics(
    selected: selected == index,
    child: IconButton(
      key: ValueKey('tab-$index'),
      tooltip: label,
      onPressed: () => onSelect(index),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: selected == index
            ? context.colors.primary.withValues(alpha: .1)
            : Colors.transparent,
        foregroundColor: selected == index
            ? context.colors.primary
            : context.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: Icon(selected == index ? activeIcon : icon, size: 22),
    ),
  );
}

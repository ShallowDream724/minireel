import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models/drama.dart';
import 'widgets.dart';

class DramaListTile extends StatelessWidget {
  const DramaListTile({
    super.key,
    required this.drama,
    required this.onTap,
    this.onLongPress,
    this.rank,
    this.metric = '',
  });
  final Drama drama;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? rank;
  final String metric;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 5),
    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank != null)
          SizedBox(
            width: 35,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: rank! <= 3 ? context.colors.primary : context.muted,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 42,
            height: 60,
            child: CoverImage(drama: drama),
          ),
        ),
      ],
    ),
    title: Text(
      drama.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      [drama.subtitle, if (metric.isNotEmpty) metric].join('\n'),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: context.muted),
    ),
    trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.muted),
    onTap: onTap,
    onLongPress: onLongPress,
  );
}

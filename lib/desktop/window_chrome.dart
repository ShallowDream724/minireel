import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'desktop_window.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key, this.window, this.light = false});
  final DesktopWindow? window;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final controller = window ?? DesktopWindow.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(context, '最小化', Icons.remove_rounded, controller.minimize),
          _button(
            context,
            controller.maximized ? '还原窗口' : '最大化',
            controller.maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            controller.toggleMaximized,
          ),
          _button(
            context,
            '关闭窗口',
            Icons.close_rounded,
            controller.close,
            close: true,
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback action, {
    bool close = false,
  }) => SizedBox(
    width: 44,
    height: 36,
    child: IconButton(
      tooltip: label,
      onPressed: action,
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => close && states.contains(WidgetState.hovered) || light
              ? Colors.white
              : context.colors.onSurface,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => close && states.contains(WidgetState.hovered)
              ? const Color(0xFFC42B1C)
              : Colors.transparent,
        ),
      ),
      icon: Icon(icon, size: 16),
    ),
  );
}

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => DesktopWindow.instance.startDragging(),
              onDoubleTap: DesktopWindow.instance.toggleMaximized,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MiniReel',
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ),
              ),
            ),
          ),
          const WindowButtons(),
        ],
      ),
    ),
  );
}

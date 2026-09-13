import 'package:flutter/material.dart';

abstract final class ReelTheme {
  static const accent = Color(0xFFFF3D6B);
  static const darkAccent = Color(0xFFFF4D74);
  static const gold = Color(0xFFFFD66F);

  static ThemeData make(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0B0D12) : const Color(0xFFF5F6F8);
    final surface = dark ? const Color(0xFF12151C) : Colors.white;
    final text = dark ? const Color(0xFFF2F4F8) : const Color(0xFF101318);
    final sub = dark ? const Color(0xFF868FA0) : const Color(0xFF7B8494);
    final color = dark ? darkAccent : accent;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: color,
            brightness: brightness,
          ).copyWith(
            primary: color,
            onPrimary: Colors.white,
            surface: surface,
            onSurface: text,
            onSurfaceVariant: sub,
            surfaceContainerHighest: dark
                ? const Color(0xFF1E222C)
                : const Color(0xFFEEEFF2),
            outlineVariant: dark
                ? const Color(0xFF252932)
                : const Color(0xFFE7E9ED),
          ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: dark
          ? Colors.white.withValues(alpha: .08)
          : Colors.black.withValues(alpha: .06),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF171A22) : Colors.white,
        modalBackgroundColor: dark ? const Color(0xFF171A22) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF2B303B)
            : const Color(0xFF242833),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? color : background,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: color,
        thumbColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: color),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: color,
        selectionHandleColor: color,
        selectionColor: color.withValues(alpha: .2),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    );
  }
}

extension ReelColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  Color get muted => colors.onSurfaceVariant;
  Color get chipColor => colors.onSurface.withValues(alpha: .05);
  bool get dark => Theme.of(this).brightness == Brightness.dark;
}

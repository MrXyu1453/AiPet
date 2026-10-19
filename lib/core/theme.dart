import 'package:flutter/material.dart';

/// 篝火营地配色：深蓝夜空 + 暖橙火光。
class AppColors {
  static const bg = Color(0xFF0B0E14);
  static const surface = Color(0xFF141823);
  static const surface2 = Color(0xFF1B2030);
  static const surface3 = Color(0xFF212635);
  static const border = Color(0xFF262B38);
  static const text = Color(0xFFE8EAF0);
  static const muted = Color(0xFF8B93A7);
  static const dim = Color(0xFF6A7286);
  static const ember = Color(0xFFFF9E3D);
  static const emberSoft = Color(0xFFFFC46B);
  static const blue = Color(0xFF6EA8FE);
  static const success = Color(0xFF7BC97B);
  static const danger = Color(0xFFE05B6A);
  static const bubble = Color(0xF220242F);
  static const bubbleSolid = Color(0xFF20242F);

  static Color charTint(Color c, [double alpha = 0.28]) =>
      c.withValues(alpha: alpha);
}

class AppRadius {
  static const s = 10.0;
  static const m = 14.0;
  static const l = 20.0;
  static const xl = 26.0;
}

class AppGap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E5AA8),
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.blue,
    secondary: AppColors.ember,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleLarge: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
      bodyMedium:
          const TextStyle(fontSize: 14, height: 1.45, color: AppColors.text),
      bodySmall: const TextStyle(fontSize: 12, color: AppColors.muted),
      labelSmall: const TextStyle(fontSize: 11, color: AppColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface3,
      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.dim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        borderSide: BorderSide(color: AppColors.ember.withValues(alpha: 0.55)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface3,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.text),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ember,
        foregroundColor: const Color(0xFF20160B),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface3,
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 13),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

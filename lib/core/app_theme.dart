import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// 熊毛浅棕：图表、运动等品牌图形。
  static const Color caramel = Color(0xFFC4895A);

  /// 稍深的浅棕：主按钮和选中态，白字可读。
  static const Color caramelDeep = Color(0xFFA56B42);

  /// 秋叶黄：热量、均线、连续打卡。
  static const Color honey = Color(0xFFF0B429);

  /// 腮红粉：收藏等轻强调。
  static const Color blush = Color(0xFFE4899C);

  /// 喝水。保留天蓝，方便和热量、体重区分。
  static const Color water = Color(0xFF6AA8D1);

  static const Color warning = Color(0xFFE09A2B);
  static const Color danger = Color(0xFFE06A6A);
  static const Color lightBackground = Color(0xFFFFF8F2);
  static const Color darkBackground = Color(0xFF1C1612);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.caramel,
      brightness: brightness,
      primary: isDark ? const Color(0xFFE8C09A) : AppColors.caramelDeep,
      onPrimary: isDark ? const Color(0xFF3E2918) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF5C4030) : const Color(0xFFFFE7C4),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFE7C4) : const Color(0xFF5A3518),
      secondary: isDark ? const Color(0xFFFFC1CC) : AppColors.blush,
      onSecondary: const Color(0xFF5A2432),
      secondaryContainer:
          isDark ? const Color(0xFF5E3642) : const Color(0xFFFFE6EC),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFE6EC) : const Color(0xFF6A3140),
      tertiary: isDark ? const Color(0xFFFFD56A) : AppColors.honey,
      onTertiary: const Color(0xFF3E2C08),
      tertiaryContainer:
          isDark ? const Color(0xFF5C4814) : const Color(0xFFFFF1CC),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFF1CC) : const Color(0xFF5A3E08),
      surface: isDark ? const Color(0xFF2A211C) : Colors.white,
      onSurface: isDark ? const Color(0xFFF7F0E8) : const Color(0xFF3D2C24),
      onSurfaceVariant:
          isDark ? const Color(0xFFD4C3B6) : const Color(0xFF8A7366),
      outline: isDark ? const Color(0xFF9A8678) : const Color(0xFFD9C6B6),
      outlineVariant: isDark ? const Color(0xFF4A3B32) : const Color(0xFFEADCCF),
      error: isDark ? const Color(0xFFFFB4AB) : AppColors.danger,
      onError: isDark ? const Color(0xFF690005) : Colors.white,
    );
    final background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF342820) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            isDark ? const Color(0xFF4A382C) : const Color(0xFF4A3428),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: isDark ? const Color(0xFFFFD56A) : AppColors.honey,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF2A211C) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2A211C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

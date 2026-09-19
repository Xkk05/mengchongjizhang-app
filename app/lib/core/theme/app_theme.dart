import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 由令牌构建的浅色/深色主题。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: c.coral,
      brightness: brightness,
    ).copyWith(
      primary: c.coral,
      surface: c.surface,
      onSurface: c.ink,
      error: c.coralDeep,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.appBg,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(c),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: c.ink,
        titleTextStyle: TextStyle(
          fontSize: AppFontSizes.xl,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: AppFontSizes.xxs,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? c.coralText : c.ink3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? c.coral : c.ink3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.coral,
          foregroundColor: c.onCoral,
          textStyle: const TextStyle(
            fontSize: AppFontSizes.lg,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.coralText,
          textStyle: const TextStyle(
            fontSize: AppFontSizes.md,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: TextStyle(color: c.ink3, fontSize: AppFontSizes.md),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: c.coral, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: c.surface, fontSize: AppFontSizes.md),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
    );
  }

  static TextTheme _textTheme(AppColors c) {
    TextStyle s(double size, FontWeight weight, {Color? color, double? h}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color ?? c.ink,
          height: h,
        );

    return TextTheme(
      displaySmall: s(AppFontSizes.display, FontWeight.w800, h: 1.15),
      headlineSmall: s(AppFontSizes.xxl, FontWeight.w700),
      titleLarge: s(AppFontSizes.xl, FontWeight.w700),
      titleMedium: s(AppFontSizes.lg, FontWeight.w600),
      titleSmall: s(AppFontSizes.md, FontWeight.w600),
      bodyLarge: s(AppFontSizes.lg, FontWeight.w500, h: 1.45),
      bodyMedium: s(AppFontSizes.md, FontWeight.w500, h: 1.45),
      bodySmall: s(AppFontSizes.sm, FontWeight.w500, color: c.ink2, h: 1.4),
      labelLarge: s(AppFontSizes.md, FontWeight.w600),
      labelMedium: s(AppFontSizes.sm, FontWeight.w500, color: c.ink2),
      labelSmall: s(AppFontSizes.xs, FontWeight.w500, color: c.ink3),
    );
  }
}

import 'package:flutter/material.dart';

/// 几何与排版令牌 —— 浅色/深色通用，不随主题切换。
///
/// 数值直接对齐 HTML 原型 v0.4 收敛后的档位，保证 Flutter 端与设计稿一致。
class AppRadii {
  const AppRadii._();
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double pill = 999;
}

class AppFontSizes {
  const AppFontSizes._();
  static const double xxs = 10.5;
  static const double xs = 12;
  static const double sm = 13;
  static const double base = 14;
  static const double md = 15.5;
  static const double lg = 17;
  static const double xl = 20;
  static const double xxl = 24;
  static const double display = 30;
}

class AppSpacing {
  const AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 语义色令牌 —— 随浅色/深色切换。
///
/// 颜色值取自原型 v0.4 并通过 WCAG AA 对比度校验。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.coral,
    required this.coralDeep,
    required this.coralText,
    required this.onCoral,
    required this.mint,
    required this.mintDeep,
    required this.mintText,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.appBg,
    required this.pageBg,
    required this.goldSoft,
    required this.onWarm1,
    required this.onWarm2,
    required this.border,
    required this.shadow,
    required this.sceneTop,
    required this.sceneMid,
    required this.sceneBottom,
  });

  /// 品牌珊瑚红（主 CTA / 强调）。
  final Color coral;
  final Color coralDeep;

  /// 承载文字用的深珊瑚（浅色下为深红，深色下为亮珊瑚）。
  final Color coralText;

  /// 压在珊瑚渐变上的文字色。
  final Color onCoral;

  /// 辅助薄荷绿。
  final Color mint;
  final Color mintDeep;
  final Color mintText;

  /// 三级文字色：正文 / 次级 / 弱化。
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// 表面：卡片 / 次级表面 / 三级表面。
  final Color surface;
  final Color surface2;
  final Color surface3;

  /// 应用底色与页面底色。
  final Color appBg;
  final Color pageBg;

  /// 暖色（金币 / 奖励）底与文字。
  final Color goldSoft;
  final Color onWarm1;
  final Color onWarm2;

  final Color border;
  final Color shadow;

  /// 主页自然场景背景三段渐变。
  final Color sceneTop;
  final Color sceneMid;
  final Color sceneBottom;

  static const AppColors light = AppColors(
    coral: Color(0xFFE2584A),
    coralDeep: Color(0xFFB4352A),
    coralText: Color(0xFFC2402F),
    onCoral: Color(0xFFFFFFFF),
    mint: Color(0xFF2E9E77),
    mintDeep: Color(0xFF177A57),
    mintText: Color(0xFF177A57),
    ink: Color(0xFF23282B),
    ink2: Color(0xFF697175),
    ink3: Color(0xFF8A9195),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F6F7),
    surface3: Color(0xFFEEF0F1),
    appBg: Color(0xFFF5F6F7),
    pageBg: Color(0xFFF5F6F7),
    goldSoft: Color(0xFFFFF1D4),
    onWarm1: Color(0xFF5E4206),
    onWarm2: Color(0xFF8A6206),
    border: Color(0xFFECEFF0),
    shadow: Color(0x1015232B),
    sceneTop: Color(0xFF8FD4F5),
    sceneMid: Color(0xFFCFEBDF),
    sceneBottom: Color(0xFFF5F6F7),
  );

  static const AppColors dark = AppColors(
    coral: Color(0xFFE2584A),
    coralDeep: Color(0xFFB4352A),
    coralText: Color(0xFFFF9A82),
    onCoral: Color(0xFFFFFFFF),
    mint: Color(0xFF3FA982),
    mintDeep: Color(0xFF63D6AB),
    mintText: Color(0xFF63D6AB),
    ink: Color(0xFFE8EBEC),
    ink2: Color(0xFFA9B0B3),
    ink3: Color(0xFF8B9397),
    surface: Color(0xFF1B1F21),
    surface2: Color(0xFF24292C),
    surface3: Color(0xFF2A2F33),
    appBg: Color(0xFF121416),
    pageBg: Color(0xFF121416),
    goldSoft: Color(0xFF3A3222),
    onWarm1: Color(0xFFFFD98A),
    onWarm2: Color(0xFFE8C67A),
    border: Color(0xFF2E3437),
    shadow: Color(0x66000000),
    sceneTop: Color(0xFF1E2A38),
    sceneMid: Color(0xFF23323A),
    sceneBottom: Color(0xFF121416),
  );

  @override
  AppColors copyWith({
    Color? coral,
    Color? coralDeep,
    Color? coralText,
    Color? onCoral,
    Color? mint,
    Color? mintDeep,
    Color? mintText,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? appBg,
    Color? pageBg,
    Color? goldSoft,
    Color? onWarm1,
    Color? onWarm2,
    Color? border,
    Color? shadow,
    Color? sceneTop,
    Color? sceneMid,
    Color? sceneBottom,
  }) {
    return AppColors(
      coral: coral ?? this.coral,
      coralDeep: coralDeep ?? this.coralDeep,
      coralText: coralText ?? this.coralText,
      onCoral: onCoral ?? this.onCoral,
      mint: mint ?? this.mint,
      mintDeep: mintDeep ?? this.mintDeep,
      mintText: mintText ?? this.mintText,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      appBg: appBg ?? this.appBg,
      pageBg: pageBg ?? this.pageBg,
      goldSoft: goldSoft ?? this.goldSoft,
      onWarm1: onWarm1 ?? this.onWarm1,
      onWarm2: onWarm2 ?? this.onWarm2,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      sceneTop: sceneTop ?? this.sceneTop,
      sceneMid: sceneMid ?? this.sceneMid,
      sceneBottom: sceneBottom ?? this.sceneBottom,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      coral: Color.lerp(coral, other.coral, t)!,
      coralDeep: Color.lerp(coralDeep, other.coralDeep, t)!,
      coralText: Color.lerp(coralText, other.coralText, t)!,
      onCoral: Color.lerp(onCoral, other.onCoral, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintDeep: Color.lerp(mintDeep, other.mintDeep, t)!,
      mintText: Color.lerp(mintText, other.mintText, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      appBg: Color.lerp(appBg, other.appBg, t)!,
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      onWarm1: Color.lerp(onWarm1, other.onWarm1, t)!,
      onWarm2: Color.lerp(onWarm2, other.onWarm2, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      sceneTop: Color.lerp(sceneTop, other.sceneTop, t)!,
      sceneMid: Color.lerp(sceneMid, other.sceneMid, t)!,
      sceneBottom: Color.lerp(sceneBottom, other.sceneBottom, t)!,
    );
  }
}

/// 便捷访问：`context.colors.coral`
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

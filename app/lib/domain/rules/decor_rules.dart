/// 装扮外观映射 —— 纯函数，便于单测。
///
/// 数据库里存的是商品 `code`（字符串），绘制层需要的是**有限的枚举**：
/// 这样以后加商品只要往映射表里补一行，绘制代码不用动。
library;

/// 穿在宠物身上的装饰（画在宠物图层内）。
enum PetAccessory {
  /// 红蝴蝶结 —— 头顶偏右
  ribbon,

  /// 小王冠 —— 头顶正中
  crown,

  /// 金铃铛 —— 颈部项圈
  bell,
}

/// 场景皮肤（换掉主页背景）。
enum SceneSkin {
  /// 默认草甸
  meadow,

  /// 樱花庭院 —— 粉雾 + 飘落花瓣
  sakura,

  /// 星空夜 —— 深蓝夜空 + 月亮 + 星星
  night,
}

class DecorRules {
  const DecorRules._();

  static const Map<String, PetAccessory> _accessories = {
    'decor_ribbon': PetAccessory.ribbon,
    'decor_crown': PetAccessory.crown,
    'decor_bell': PetAccessory.bell,
  };

  static const Map<String, SceneSkin> _skins = {
    'decor_sakura': SceneSkin.sakura,
    'decor_night': SceneSkin.night,
  };

  /// 头饰 / 颈部装饰的 code → 外观；为空或不认识则返回 null（不画）。
  ///
  /// 未知 code 选择「不画」而不是报错：商品目录以后会扩，旧版本客户端遇到
  /// 新商品时只是看不见装饰，不该整页崩掉。
  static PetAccessory? accessoryFor(String? code) =>
      code == null ? null : _accessories[code];

  /// 场景皮肤的 code → 皮肤；为空或不认识则回落到默认草甸。
  static SceneSkin skinFor(String? code) =>
      code == null ? SceneSkin.meadow : _skins[code] ?? SceneSkin.meadow;
}

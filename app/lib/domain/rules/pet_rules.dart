/// 养成规则引擎 —— 纯函数，便于单测。
///
/// 规则：每记一笔账 → 宠物得经验 + 金币；经验累计到阈值即升级。
/// 金币的出口是商店（买食物 / 装扮），食物再转化为饱食与经验。
class PetRules {
  const PetRules._();

  /// 单笔记账奖励。
  static const int expPerRecord = 10;
  static const int coinPerRecord = 2;

  /// 升到下一级所需经验。
  static int expNeeded(int level) => 100 + (level - 1) * 40;

  /// 等级上限。
  static const int maxLevel = 99;

  /// 饱食度 / 心情值上限。
  static const int maxHunger = 100;
  static const int maxMood = 100;

  /// 累加经验并按阈值连续升级，返回结算后的 `(level, exp)`。
  ///
  /// 到顶级后经验封顶，避免无限膨胀。
  static (int level, int exp) applyExp({
    required int level,
    required int exp,
    required int gain,
  }) {
    var lv = level;
    var e = exp + gain;

    while (lv < maxLevel && e >= expNeeded(lv)) {
      e -= expNeeded(lv);
      lv += 1;
    }
    if (lv >= maxLevel) {
      e = e.clamp(0, expNeeded(maxLevel));
    }
    return (lv, e);
  }

  /// 记账奖励。
  static PetDelta onRecord({required int level, required int exp}) {
    final r = applyExp(level: level, exp: exp, gain: expPerRecord);
    return PetDelta(level: r.$1, exp: r.$2, coinGained: coinPerRecord);
  }

  /// 喂食（直接花金币）：消耗金币换饱食度与经验。
  static PetDelta onFeed(
      {required int level, required int exp, required int cost}) {
    final r = applyExp(level: level, exp: exp, gain: 6);
    return PetDelta(level: r.$1, exp: r.$2, coinGained: -cost);
  }

  /// 使用背包里的食物道具。
  ///
  /// 金币在**购买时**已扣，这里只结算属性。
  static PetUseResult onUseFood({
    required int level,
    required int exp,
    required int hunger,
    required int mood,
    required int expGain,
    required int hungerGain,
    required int moodGain,
  }) {
    final r = applyExp(level: level, exp: exp, gain: expGain);
    return PetUseResult(
      level: r.$1,
      exp: r.$2,
      hunger: (hunger + hungerGain).clamp(0, maxHunger),
      mood: (mood + moodGain).clamp(0, maxMood),
    );
  }

  static double levelProgress({required int level, required int exp}) {
    final need = expNeeded(level);
    if (need <= 0) return 1;
    return (exp / need).clamp(0.0, 1.0);
  }

  static String stageName(int level) {
    if (level < 5) return '幼崽期';
    if (level < 15) return '成长期';
    if (level < 30) return '少年期';
    if (level < 60) return '成熟期';
    return '大师期';
  }

  /// 阶段体型 —— 让「长大」在画面上真看得见。
  ///
  /// 高度锚在脚底，所以变大时是往上长，不会浮空。
  /// 幼崽头大身小，越往后越匀称。
  static PetBody bodyFor(int level) {
    if (level < 5) {
      return const PetBody(overall: 0.90, head: 1.14, body: 0.86);
    }
    if (level < 15) {
      return const PetBody(overall: 0.95, head: 1.08, body: 0.93);
    }
    if (level < 30) {
      return const PetBody(overall: 0.98, head: 1.03, body: 0.98);
    }
    if (level < 60) {
      return const PetBody(overall: 1.00, head: 1.00, body: 1.00);
    }
    return const PetBody(overall: 1.04, head: 0.97, body: 1.05);
  }

  /// 开心（弯月眼）：心情和饱食都得够。
  static bool isHappy({required int mood, required int hunger}) =>
      mood >= 50 && hunger >= 30;

  /// 蔫掉（饿坏了或心情差）：半闭眼 + 嘴角下垂。
  static bool isDown({required int mood, required int hunger}) =>
      mood < 30 || hunger < 25;

  /// 饱食 / 心情上限的展示用百分比。
  static int percentOf(int value, int max) =>
      max <= 0 ? 0 : (value * 100 / max).round().clamp(0, 100);

  /// 由「心情 + 饱食 + 时段」推演宠物此刻该演的**状态化动作**。
  ///
  /// 优先级：饿 > 困 > 满足 > 待机。又饿又困时先表现饿（更紧急）。
  /// - 饿：饱食 < 25（随时可见，跟喂食闭环挂钩）；
  /// - 困：深夜 / 凌晨时段（22:00–05:59），用 [hour] 驱动，不需要额外的精力字段；
  /// - 满足：心情 >= 70 且饱食 >= 60（比 isHappy 更高的奖励阈值）；
  /// - [hour] 传 -1 表示「不看时段」（静态预览 / 测试友好）。
  static PetAction actionFor({
    required int mood,
    required int hunger,
    int hour = -1,
  }) {
    if (hunger < 25) return PetAction.hungry;
    if (hour != -1 && (hour >= 22 || hour < 6)) return PetAction.sleepy;
    if (mood >= 70 && hunger >= 60) return PetAction.content;
    return PetAction.idle;
  }
}

/// 宠物的状态化待机动作。
///
/// 与 [PetRules.isHappy] / [PetRules.isDown] 的表情不同，这是一组**触发式演出**：
/// 饿了下厨摸肚子、深夜犯困打哈欠、吃饱了心满意足地哼歌，其余时间回到普通待机。
enum PetAction { idle, hungry, sleepy, content }

/// 一个阶段的体型系数。
///
/// [overall] 是整体缩放，[head] / [body] 是头与躯干相对整体的额外系数 ——
/// 拆成三个数而不是一个，是为了保留「幼崽头大身小」的比例语言。
class PetBody {
  const PetBody({
    required this.overall,
    required this.head,
    required this.body,
  });

  final double overall;
  final double head;
  final double body;
}

/// 记账 / 喂食的增量结果。
class PetDelta {
  const PetDelta({
    required this.level,
    required this.exp,
    required this.coinGained,
  });

  final int level;
  final int exp;
  final int coinGained;
}

/// 使用食物道具后的宠物状态。
class PetUseResult {
  const PetUseResult({
    required this.level,
    required this.exp,
    required this.hunger,
    required this.mood,
  });

  final int level;
  final int exp;
  final int hunger;
  final int mood;
}

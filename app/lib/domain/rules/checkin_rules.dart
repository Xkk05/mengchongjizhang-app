/// 签到规则 —— 纯函数，便于单测。
///
/// 7 天一个周期循环发放：金币为主，第 3 / 5 / 7 天额外送道具。
/// 道具用 `store_items.code` 引用，改商品名不影响奖励。
library;

/// 一次签到的奖励。
class CheckinReward {
  const CheckinReward({
    required this.cycleDay,
    required this.coin,
    this.bonusItemCode,
    this.bonusCount = 0,
  });

  /// 周期里的第几天（1..7）。
  final int cycleDay;
  final int coin;

  /// 额外赠送的商品 code（对应 `store_items.code`）；无则为 null。
  final String? bonusItemCode;
  final int bonusCount;

  bool get hasBonus => bonusItemCode != null && bonusCount > 0;
}

/// 签到面板需要的全部状态。
class CheckinState {
  const CheckinState({
    required this.streak,
    required this.claimedDays,
    required this.canCheckIn,
    required this.nextStreak,
    required this.nextReward,
  });

  /// 当前连续签到天数（断签为 0）。
  final int streak;

  /// 本周期已领到第几天（0 = 本周期还没领）。
  final int claimedDays;

  /// 今天是否还能签。
  final bool canCheckIn;

  /// 若现在签，会成为连续第几天。
  final int nextStreak;

  /// 若现在签，能拿到什么。
  final CheckinReward nextReward;

  static CheckinState resolve({
    required int lastStreak,
    required DateTime? lastDay,
    required DateTime today,
  }) {
    final t = CheckinRules.dayOf(today);
    final signedToday = lastDay != null && CheckinRules.dayOf(lastDay) == t;
    // 昨天（或今天）签过 → 连击还活着。
    final gap = lastDay == null ? 999 : t.difference(CheckinRules.dayOf(lastDay)).inDays;
    final alive = gap <= 1;

    final streak = alive ? lastStreak : 0;
    final canCheckIn = !signedToday;
    final nextStreak =
        canCheckIn ? (alive ? lastStreak + 1 : 1) : lastStreak;

    return CheckinState(
      streak: streak,
      claimedDays: alive ? CheckinRules.cycleDayOf(lastStreak) : 0,
      canCheckIn: canCheckIn,
      nextStreak: nextStreak,
      nextReward: CheckinRules.rewardFor(nextStreak),
    );
  }
}

class CheckinRules {
  const CheckinRules._();

  /// 周期长度：7 天一轮，超过后从头循环。
  static const int cycleLength = 7;

  /// 周期奖励表（下标 0 对应第 1 天）。
  static const List<CheckinReward> cycle = [
    CheckinReward(cycleDay: 1, coin: 20),
    CheckinReward(cycleDay: 2, coin: 30),
    CheckinReward(
        cycleDay: 3, coin: 40, bonusItemCode: 'food_fish', bonusCount: 1),
    CheckinReward(cycleDay: 4, coin: 50),
    CheckinReward(
        cycleDay: 5, coin: 60, bonusItemCode: 'food_can', bonusCount: 1),
    CheckinReward(cycleDay: 6, coin: 80),
    CheckinReward(
        cycleDay: 7, coin: 100, bonusItemCode: 'decor_ribbon', bonusCount: 1),
  ];

  /// 归一到「日」粒度，避免同一天因为时分秒不同被当成两天。
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 连续第 [streak] 天落在周期的第几天（1..7）。
  static int cycleDayOf(int streak) {
    if (streak <= 0) return 1;
    return ((streak - 1) % cycleLength) + 1;
  }

  static CheckinReward rewardFor(int streak) => cycle[cycleDayOf(streak) - 1];

  /// 今天是否还能签（同日不可重复签）。
  static bool canCheckIn({required DateTime? lastDay, required DateTime today}) {
    if (lastDay == null) return true;
    return dayOf(today).isAfter(dayOf(lastDay));
  }

  /// 签完之后的新连击：昨天签过则 +1，断签或同日则从 1 重来 / 保持不变。
  static int nextStreak({
    required int lastStreak,
    required DateTime? lastDay,
    required DateTime today,
  }) {
    if (lastDay == null) return 1;
    final gap = dayOf(today).difference(dayOf(lastDay)).inDays;
    if (gap <= 0) return lastStreak; // 今天已签（或时间倒挂），保持原值
    if (gap == 1) return lastStreak + 1;
    return 1;
  }
}

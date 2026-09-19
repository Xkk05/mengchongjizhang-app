import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/checkin_rules.dart';

void main() {
  final today = DateTime(2026, 9, 19);
  DateTime daysAgo(int n) => DateTime(2026, 9, 19 - n);

  group('CheckinRules.cycleDayOf', () {
    test('前 7 天依次落在 1..7', () {
      for (var s = 1; s <= 7; s++) {
        expect(CheckinRules.cycleDayOf(s), s);
      }
    });

    test('超过一个周期后从头循环', () {
      expect(CheckinRules.cycleDayOf(8), 1);
      expect(CheckinRules.cycleDayOf(14), 7);
      expect(CheckinRules.cycleDayOf(15), 1);
    });

    test('异常连击归到第 1 天', () {
      expect(CheckinRules.cycleDayOf(0), 1);
      expect(CheckinRules.cycleDayOf(-3), 1);
    });
  });

  group('CheckinRules.rewardFor', () {
    test('第 3 / 5 / 7 天额外送道具', () {
      expect(CheckinRules.rewardFor(3).bonusItemCode, 'food_fish');
      expect(CheckinRules.rewardFor(5).bonusItemCode, 'food_can');
      expect(CheckinRules.rewardFor(7).bonusItemCode, 'decor_ribbon');
      expect(CheckinRules.rewardFor(7).hasBonus, isTrue);
    });

    test('普通天只发金币', () {
      expect(CheckinRules.rewardFor(1).hasBonus, isFalse);
      expect(CheckinRules.rewardFor(1).coin, 20);
      expect(CheckinRules.rewardFor(6).coin, 80);
    });
  });

  group('CheckinRules.canCheckIn', () {
    test('从没签过可以签', () {
      expect(CheckinRules.canCheckIn(lastDay: null, today: today), isTrue);
    });

    test('同一天不能重复签', () {
      expect(
        CheckinRules.canCheckIn(
            lastDay: DateTime(2026, 9, 19, 8, 30), today: today),
        isFalse,
      );
    });

    test('隔天可以签', () {
      expect(
        CheckinRules.canCheckIn(lastDay: daysAgo(1), today: today),
        isTrue,
      );
    });
  });

  group('CheckinRules.nextStreak', () {
    test('首次签到从 1 开始', () {
      expect(
        CheckinRules.nextStreak(lastStreak: 0, lastDay: null, today: today),
        1,
      );
    });

    test('昨天签过则连击 +1', () {
      expect(
        CheckinRules.nextStreak(
            lastStreak: 4, lastDay: daysAgo(1), today: today),
        5,
      );
    });

    test('断签后从 1 重新计', () {
      expect(
        CheckinRules.nextStreak(
            lastStreak: 9, lastDay: daysAgo(3), today: today),
        1,
      );
    });

    test('今天已签则保持原连击', () {
      expect(
        CheckinRules.nextStreak(lastStreak: 6, lastDay: today, today: today),
        6,
      );
    });
  });

  group('CheckinState.resolve', () {
    test('从没签过：连击 0，今天可签，奖励是第 1 天', () {
      final s = CheckinState.resolve(lastStreak: 0, lastDay: null, today: today);
      expect(s.streak, 0);
      expect(s.claimedDays, 0);
      expect(s.canCheckIn, isTrue);
      expect(s.nextStreak, 1);
      expect(s.nextReward.cycleDay, 1);
      expect(s.nextReward.coin, 20);
    });

    test('昨天签过：连击延续，可签，奖励推进到第 4 天', () {
      final s = CheckinState.resolve(
          lastStreak: 3, lastDay: daysAgo(1), today: today);
      expect(s.streak, 3);
      expect(s.claimedDays, 3);
      expect(s.canCheckIn, isTrue);
      expect(s.nextStreak, 4);
      expect(s.nextReward.cycleDay, 4);
      expect(s.nextReward.coin, 50);
    });

    test('今天已签：不可再签，面板停在已领位置', () {
      final s = CheckinState.resolve(
          lastStreak: 7, lastDay: today, today: today);
      expect(s.canCheckIn, isFalse);
      expect(s.streak, 7);
      expect(s.claimedDays, 7);
      expect(s.nextStreak, 7);
      expect(s.nextReward.hasBonus, isTrue);
    });

    test('断签多天：连击清零，周期奖励回到第 1 天', () {
      final s = CheckinState.resolve(
          lastStreak: 5, lastDay: daysAgo(4), today: today);
      expect(s.streak, 0);
      expect(s.claimedDays, 0);
      expect(s.canCheckIn, isTrue);
      expect(s.nextStreak, 1);
      expect(s.nextReward.cycleDay, 1);
    });
  });
}

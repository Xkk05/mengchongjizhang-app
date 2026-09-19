import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/pet_rules.dart';

void main() {
  group('PetRules.onRecord', () {
    test('单笔记账不入级时只累加经验', () {
      final d = PetRules.onRecord(level: 1, exp: 0);
      expect(d.level, 1);
      expect(d.exp, PetRules.expPerRecord);
      expect(d.coinGained, PetRules.coinPerRecord);
    });

    test('经验越阈值时升级并保留余数', () {
      final need = PetRules.expNeeded(1);
      final d = PetRules.onRecord(level: 1, exp: need - 5);
      expect(d.level, 2);
      expect(d.exp, PetRules.expPerRecord - 5);
    });

    test('一次加成跨多级也正确', () {
      final need1 = PetRules.expNeeded(1);
      final need2 = PetRules.expNeeded(2);
      // 人为给一大笔经验，验证 while 循环能把多级都结算掉。
      final d = PetRules.onRecord(level: 1, exp: need1 + need2 - 10);
      expect(d.level, 3);
      expect(d.exp, PetRules.expPerRecord - 10);
    });

    test('等级上限封顶，不越界', () {
      final d = PetRules.onRecord(level: PetRules.maxLevel, exp: 0);
      expect(d.level, PetRules.maxLevel);
    });
  });

  group('PetRules.levelProgress', () {
    test('经验为 0 时进度为 0', () {
      expect(PetRules.levelProgress(level: 1, exp: 0), 0);
    });

    test('进度落在 0~1 区间', () {
      final p = PetRules.levelProgress(level: 3, exp: 99999);
      expect(p, inInclusiveRange(0.0, 1.0));
    });
  });

  group('PetRules.stageName', () {
    test('按等级返回阶段名', () {
      expect(PetRules.stageName(1), '幼崽期');
      expect(PetRules.stageName(10), '成长期');
      expect(PetRules.stageName(20), '少年期');
      expect(PetRules.stageName(40), '成熟期');
      expect(PetRules.stageName(80), '大师期');
    });
  });

  group('PetRules.applyExp', () {
    test('未越阈值时只累加', () {
      final r = PetRules.applyExp(level: 2, exp: 10, gain: 5);
      expect(r.$1, 2);
      expect(r.$2, 15);
    });

    test('越阈值时升级并保留余数', () {
      final need = PetRules.expNeeded(2);
      final r = PetRules.applyExp(level: 2, exp: need - 4, gain: 10);
      expect(r.$1, 3);
      expect(r.$2, 6);
    });

    test('到达等级上限后经验封顶不越界', () {
      final r = PetRules.applyExp(
          level: PetRules.maxLevel, exp: 0, gain: 999999);
      expect(r.$1, PetRules.maxLevel);
      expect(r.$2, lessThanOrEqualTo(PetRules.expNeeded(PetRules.maxLevel)));
    });

    test('一次加成跨多级也正确', () {
      final need1 = PetRules.expNeeded(1);
      final need2 = PetRules.expNeeded(2);
      final r = PetRules.applyExp(level: 1, exp: 0, gain: need1 + need2 + 3);
      expect(r.$1, 3);
      expect(r.$2, 3);
    });
  });

  group('PetRules.onUseFood', () {
    test('饱食 / 心情按上限封顶', () {
      final r = PetRules.onUseFood(
        level: 1,
        exp: 0,
        hunger: 95,
        mood: 98,
        expGain: 6,
        hungerGain: 18,
        moodGain: 10,
      );
      expect(r.hunger, PetRules.maxHunger);
      expect(r.mood, PetRules.maxMood);
      expect(r.exp, 6);
      expect(r.level, 1);
    });

    test('经验够则升级', () {
      final r = PetRules.onUseFood(
        level: 1,
        exp: PetRules.expNeeded(1) - 2,
        hunger: 10,
        mood: 10,
        expGain: 6,
        hungerGain: 8,
        moodGain: 2,
      );
      expect(r.level, 2);
      expect(r.exp, 4);
      expect(r.hunger, 18);
      expect(r.mood, 12);
    });

    test('道具效果为 0 时不改变属性', () {
      final r = PetRules.onUseFood(
        level: 3,
        exp: 5,
        hunger: 40,
        mood: 50,
        expGain: 0,
        hungerGain: 0,
        moodGain: 0,
      );
      expect(r.hunger, 40);
      expect(r.mood, 50);
      expect(r.exp, 5);
    });
  });
}

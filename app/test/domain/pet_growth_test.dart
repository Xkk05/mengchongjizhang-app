import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/pet_rules.dart';

void main() {
  group('PetRules.bodyFor', () {
    test('整体尺寸随阶段单调不减', () {
      var prev = 0.0;
      for (final level in [1, 5, 10, 15, 25, 30, 50, 60, 80, 99]) {
        final b = PetRules.bodyFor(level);
        expect(b.overall, greaterThanOrEqualTo(prev),
            reason: 'Lv.$level 的体型不该比上一档更小');
        prev = b.overall;
      }
    });

    test('幼崽头大身小，长大趋于匀称', () {
      final baby = PetRules.bodyFor(1);
      final adult = PetRules.bodyFor(60);
      final master = PetRules.bodyFor(80);

      expect(baby.head, greaterThan(baby.body));
      expect(master.head, lessThan(master.body));
      // 头身比随成长收敛
      expect(baby.head, greaterThan(adult.head));
      expect(baby.body, lessThan(adult.body));
    });

    test('阶段切换点前后参数不同', () {
      expect(PetRules.bodyFor(4).overall, PetRules.bodyFor(1).overall);
      expect(PetRules.bodyFor(5).overall, isNot(PetRules.bodyFor(4).overall));
      expect(PetRules.bodyFor(29).overall, PetRules.bodyFor(15).overall);
      expect(PetRules.bodyFor(30).overall, isNot(PetRules.bodyFor(29).overall));
    });

    test('全等级范围参数都在安全区间（不会缩没或撑爆）', () {
      for (var level = 1; level <= PetRules.maxLevel; level++) {
        final b = PetRules.bodyFor(level);
        expect(b.overall, inInclusiveRange(0.8, 1.2), reason: 'Lv.$level');
        expect(b.head, inInclusiveRange(0.8, 1.3), reason: 'Lv.$level');
        expect(b.body, inInclusiveRange(0.8, 1.2), reason: 'Lv.$level');
      }
    });
  });

  group('PetRules 表情判定', () {
    test('心情和饱食都够才算开心', () {
      expect(PetRules.isHappy(mood: 60, hunger: 60), isTrue);
      expect(PetRules.isHappy(mood: 60, hunger: 20), isFalse);
      expect(PetRules.isHappy(mood: 20, hunger: 60), isFalse);
    });

    test('饿坏了或心情差都算蔫', () {
      expect(PetRules.isDown(mood: 80, hunger: 20), isTrue);
      expect(PetRules.isDown(mood: 20, hunger: 80), isTrue);
      expect(PetRules.isDown(mood: 60, hunger: 60), isFalse);
    });

    test('开心与蔫互斥（任何取值组合都不会同时成立）', () {
      for (var mood = 0; mood <= 100; mood += 5) {
        for (var hunger = 0; hunger <= 100; hunger += 5) {
          final happy = PetRules.isHappy(mood: mood, hunger: hunger);
          final down = PetRules.isDown(mood: mood, hunger: hunger);
          expect(happy && down, isFalse, reason: 'mood=$mood hunger=$hunger');
        }
      }
    });
  });

  group('PetRules.percentOf', () {
    test('按上限换算百分比并夹紧到 0~100', () {
      expect(PetRules.percentOf(50, 100), 50);
      expect(PetRules.percentOf(0, 100), 0);
      expect(PetRules.percentOf(100, 100), 100);
      expect(PetRules.percentOf(120, 100), 100);
      expect(PetRules.percentOf(-5, 100), 0);
    });

    test('上限非正时返回 0，不除零', () {
      expect(PetRules.percentOf(50, 0), 0);
      expect(PetRules.percentOf(50, -10), 0);
    });
  });
}

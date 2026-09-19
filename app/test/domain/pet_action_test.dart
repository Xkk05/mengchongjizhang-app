import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/pet_rules.dart';

void main() {
  group('PetAction.actionFor', () {
    test('饿优先：饱食低于 25 无论时段与心情都是 hungry', () {
      expect(
        PetRules.actionFor(mood: 100, hunger: 24, hour: 12),
        PetAction.hungry,
      );
      expect(
        PetRules.actionFor(mood: 0, hunger: 0, hour: 3),
        PetAction.hungry,
      );
    });

    test('饱食恰好 25 不再算饿', () {
      expect(PetRules.actionFor(mood: 40, hunger: 25, hour: 12), isNot(PetAction.hungry));
    });

    test('困：深夜（22 点）与凌晨（5 点）都是 sleepy', () {
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: 22), PetAction.sleepy);
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: 5), PetAction.sleepy);
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: 0), PetAction.sleepy);
    });

    test('困的边界：6 点与 21 点不算困', () {
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: 6), isNot(PetAction.sleepy));
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: 21), isNot(PetAction.sleepy));
    });

    test('满足：心情 >= 70 且饱食 >= 60', () {
      expect(PetRules.actionFor(mood: 70, hunger: 60, hour: 12), PetAction.content);
      expect(PetRules.actionFor(mood: 99, hunger: 100, hour: 15), PetAction.content);
    });

    test('满足的阈值：心情 69 或饱食 59 不算满足', () {
      expect(PetRules.actionFor(mood: 69, hunger: 80, hour: 12), PetAction.idle);
      expect(PetRules.actionFor(mood: 80, hunger: 59, hour: 12), PetAction.idle);
    });

    test('普通状态回到 idle', () {
      expect(PetRules.actionFor(mood: 40, hunger: 40, hour: 12), PetAction.idle);
      expect(PetRules.actionFor(mood: 60, hunger: 30, hour: 12), PetAction.idle);
    });

    test('hour = -1 不看时段：深夜也不会困', () {
      expect(PetRules.actionFor(mood: 40, hunger: 60, hour: -1), PetAction.idle);
      expect(PetRules.actionFor(mood: 80, hunger: 80, hour: -1), PetAction.content);
    });

    test('饿的优先级高于困', () {
      expect(PetRules.actionFor(mood: 40, hunger: 10, hour: 3), PetAction.hungry);
    });

    test('困的优先级高于满足', () {
      expect(PetRules.actionFor(mood: 90, hunger: 90, hour: 23), PetAction.sleepy);
    });
  });
}

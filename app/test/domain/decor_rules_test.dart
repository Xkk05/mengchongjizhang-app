import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/decor_rules.dart';

void main() {
  group('DecorRules.accessoryFor', () {
    test('头饰与颈部能映射到对应外观', () {
      expect(DecorRules.accessoryFor('decor_ribbon'), PetAccessory.ribbon);
      expect(DecorRules.accessoryFor('decor_crown'), PetAccessory.crown);
      expect(DecorRules.accessoryFor('decor_bell'), PetAccessory.bell);
    });

    test('场景皮肤不映射成宠物饰品', () {
      expect(DecorRules.accessoryFor('decor_sakura'), isNull);
      expect(DecorRules.accessoryFor('decor_night'), isNull);
    });

    test('食物与未知 code 都不产生饰品', () {
      expect(DecorRules.accessoryFor('food_fish'), isNull);
      expect(DecorRules.accessoryFor('decor_unknown'), isNull);
      expect(DecorRules.accessoryFor(null), isNull);
      expect(DecorRules.accessoryFor(''), isNull);
    });
  });

  group('DecorRules.skinFor', () {
    test('两款场景皮肤各自映射正确', () {
      expect(DecorRules.skinFor('decor_sakura'), SceneSkin.sakura);
      expect(DecorRules.skinFor('decor_night'), SceneSkin.night);
    });

    test('没装扮或装扮不是皮肤时回落默认草甸', () {
      expect(DecorRules.skinFor(null), SceneSkin.meadow);
      expect(DecorRules.skinFor('decor_crown'), SceneSkin.meadow);
      expect(DecorRules.skinFor('decor_unknown'), SceneSkin.meadow);
      expect(DecorRules.skinFor('food_can'), SceneSkin.meadow);
    });
  });
}

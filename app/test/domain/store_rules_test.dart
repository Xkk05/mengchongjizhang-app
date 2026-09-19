import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/rules/store_rules.dart';

void main() {
  group('StoreRules.canBuy', () {
    test('金币足够可以买', () {
      final r = StoreRules.canBuy(coin: 100, priceCoin: 100);
      expect(r.ok, isTrue);
      expect(r.reason, isEmpty);
    });

    test('金币不足时给出还差多少', () {
      final r = StoreRules.canBuy(coin: 30, priceCoin: 90);
      expect(r.ok, isFalse);
      expect(r.reason, contains('还差 60'));
    });

    test('价格非法直接拒绝', () {
      expect(StoreRules.canBuy(coin: 999, priceCoin: 0).ok, isFalse);
      expect(StoreRules.canBuy(coin: 999, priceCoin: -5).ok, isFalse);
    });
  });

  group('StoreRules.canUse', () {
    test('背包里有就能用', () {
      expect(StoreRules.canUse(quantity: 1).ok, isTrue);
      expect(StoreRules.canUse(quantity: 99).ok, isTrue);
    });

    test('没有则拒绝', () {
      final r = StoreRules.canUse(quantity: 0);
      expect(r.ok, isFalse);
      expect(r.reason, contains('没有'));
    });
  });
}

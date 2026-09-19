import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/utils/money.dart';

void main() {
  group('Money.parseYuan', () {
    test('两位小数正常解析', () {
      expect(Money.parseYuan('12.34'), 1234);
    });

    test('整数与千分位逗号', () {
      expect(Money.parseYuan('100'), 10000);
      expect(Money.parseYuan('1,234.5'), 123450);
    });

    test('四舍五入到分', () {
      expect(Money.parseYuan('0.005'), 1);
      expect(Money.parseYuan('0.004'), 0);
    });

    test('非法输入返回 null', () {
      expect(Money.parseYuan(''), isNull);
      expect(Money.parseYuan('   '), isNull);
      expect(Money.parseYuan('abc'), isNull);
    });
  });

  group('Money 展示', () {
    test('千分位格式化', () {
      expect(Money.yuan(123456), '1,234.56');
      expect(Money.yuan(0), '0.00');
    });

    test('带符号输出', () {
      expect(Money.signed(1234, isExpense: true), '-12.34');
      expect(Money.signed(1234, isExpense: false), '+12.34');
    });

    test('负数金额取绝对值展示符号', () {
      expect(Money.signed(-1234, isExpense: true), '-12.34');
    });
  });
}

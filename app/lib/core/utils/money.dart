import 'package:intl/intl.dart';

/// 金额一律以「分」为整数单位存储，展示时再转成元，避免浮点误差。
class Money {
  const Money._();

  static final NumberFormat _grouped = NumberFormat('#,##0.00');
  static final NumberFormat _plain = NumberFormat('0.00');

  /// 分 -> `1,234.50`
  static String yuan(int cents, {bool grouped = true}) {
    final v = cents / 100.0;
    return (grouped ? _grouped : _plain).format(v);
  }

  /// 分 -> `¥1,234.50`
  static String symbol(int cents, {bool grouped = true}) =>
      '¥${yuan(cents, grouped: grouped)}';

  /// 带正负号：支出 `-1,234.50`，收入 `+1,234.50`
  static String signed(int cents, {required bool isExpense}) =>
      '${isExpense ? '-' : '+'}${yuan(cents.abs())}';

  /// 解析用户输入（元）为分；非法输入返回 null。
  static int? parseYuan(String input) {
    final t = input.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return (v * 100).round();
  }
}

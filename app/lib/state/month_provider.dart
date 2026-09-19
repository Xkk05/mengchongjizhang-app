import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局「当前查看月份」—— 统计页与预算页共用，翻月互相同步。
class MonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// 翻月：-1 上一月，+1 下一月。不允许翻到未来。
  void shift(int months) {
    final next = DateTime(state.year, state.month + months);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    state = next;
  }

  void reset() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month);
  }
}

final selectedMonthProvider =
    NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

/// 月份 → `yyyymm`（如 202609），用作预算表的月份键。
int yearMonthOf(DateTime d) => d.year * 100 + d.month;

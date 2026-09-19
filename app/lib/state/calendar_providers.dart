import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ledger_repository.dart';
import '../domain/calendar/month_calendar.dart';
import 'month_provider.dart';
import 'stats_providers.dart';

/// 当前月份的日历聚合输入。
///
/// 直接复用统计页的月度流水（`statsRangeProvider`）—— 同一个「当前月份」、
/// 同一套取数范围，日历与统计不会出现口径对不上。
final calendarEntriesProvider = Provider<List<CalendarEntry>>((ref) {
  final records = ref.watch(statsRangeProvider).value;
  if (records == null) return const [];
  return records
      .map((r) => (
            at: r.occurredAt,
            isExpense: r.isExpense,
            amountCents: r.amountCents,
          ))
      .toList(growable: false);
});

/// 当前月份的日历网格（补齐首尾，固定 7 的整数倍）。
final calendarGridProvider = Provider<List<CalendarDay>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return MonthCalendar.build(
    year: month.year,
    month: month.month,
    entries: ref.watch(calendarEntriesProvider),
  );
});

/// 选中的那一天。
///
/// `build` 里 watch 了月份 —— 翻月时自动重置：看当前月默认选中今天，
/// 看历史月份则不预选（避免「翻到 3 月却高亮着今天的日期」这种错位）。
class SelectedDayNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final month = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    return isCurrentMonth ? DateTime(now.year, now.month, now.day) : null;
  }

  void select(DateTime day) => state = DateTime(day.year, day.month, day.day);

  void clear() => state = null;
}

final selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, DateTime?>(SelectedDayNotifier.new);

/// 选中那天的流水。
final selectedDayRecordsProvider = Provider<List<TxRecord>>((ref) {
  final day = ref.watch(selectedDayProvider);
  if (day == null) return const [];
  final records = ref.watch(statsRangeProvider).value;
  if (records == null) return const [];
  return records
      .where((r) => MonthCalendar.isSameDay(r.occurredAt, day))
      .toList(growable: false);
});

/// 选中那天的支出 / 收入合计。
final selectedDayTotalsProvider =
    Provider<({int expenseCents, int incomeCents})>((ref) {
  var expense = 0;
  var income = 0;
  for (final r in ref.watch(selectedDayRecordsProvider)) {
    if (r.isExpense) {
      expense += r.amountCents;
    } else {
      income += r.amountCents;
    }
  }
  return (expenseCents: expense, incomeCents: income);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/tables.dart';
import '../data/repositories/ledger_repository.dart';
import '../domain/stats/ledger_stats.dart';
import 'month_provider.dart';
import 'providers.dart';

/// 统计方向：支出 / 收入。
class StatsKindNotifier extends Notifier<TxKind> {
  @override
  TxKind build() => TxKind.expense;

  void set(TxKind kind) => state = kind;
}

final statsKindProvider =
    NotifierProvider<StatsKindNotifier, TxKind>(StatsKindNotifier.new);

/// TxRecord -> 聚合输入。
StatEntry toStatEntry(TxRecord r) => (
      at: r.occurredAt,
      amountCents: r.amountCents,
      isExpense: r.isExpense,
      categoryId: r.row.categoryId,
      categoryName: r.categoryName,
      iconKey: r.categoryIconKey,
      colorValue: r.categoryColor,
    );

/// 当前统计月份的账目。
final statsRangeProvider = StreamProvider<List<TxRecord>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return ref.watch(ledgerRepositoryProvider).watchRange(start, end);
});

/// 本月聚合输入。
final statsEntriesProvider = Provider<List<StatEntry>>((ref) {
  final records = ref.watch(statsRangeProvider).value;
  if (records == null) return const [];
  // 转账不参与收入/支出统计（含分类占比），在入口处过滤掉。
  return records
      .where((r) => !r.isTransfer)
      .map(toStatEntry)
      .toList(growable: false);
});

/// 当前方向下的分类占比（金额降序）。
final statsSlicesProvider = Provider<List<CategorySlice>>((ref) {
  final entries = ref.watch(statsEntriesProvider);
  final isExpense = ref.watch(statsKindProvider) == TxKind.expense;
  return LedgerStats.byCategory(entries, expense: isExpense);
});

/// 本月合计。
final statsTotalsProvider = Provider<StatTotals>((ref) {
  return LedgerStats.totals(ref.watch(statsEntriesProvider));
});

/// 近 7 日区间（跨月，固定以今天收尾）。
final trendRangeProvider = StreamProvider<List<TxRecord>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - 6);
  final end = DateTime(now.year, now.month, now.day + 1);
  return ref.watch(ledgerRepositoryProvider).watchRange(start, end);
});

/// 近 7 日逐日收支。
final trendPointsProvider = Provider<List<DailyPoint>>((ref) {
  final records = ref.watch(trendRangeProvider).value;
  if (records == null) return const [];
  return LedgerStats.dailyTrend(
    records.map(toStatEntry),
    days: 7,
    today: DateTime.now(),
  );
});

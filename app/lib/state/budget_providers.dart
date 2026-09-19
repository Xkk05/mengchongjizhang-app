import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ledger_repository.dart';
import '../domain/budget/budget_plan.dart';
import '../domain/stats/ledger_stats.dart';
import 'month_provider.dart';
import 'providers.dart';
import 'stats_providers.dart';

/// 当前月份的预算记录（含分类元信息）。
final budgetRowsProvider = StreamProvider<List<BudgetRow>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(ledgerRepositoryProvider).watchBudgets(yearMonthOf(month));
});

/// 当月各支出分类的合计（复用统计聚合，口径与统计页一致）。
final budgetSpendProvider = Provider<Map<int, int>>((ref) {
  final entries = ref.watch(statsEntriesProvider);
  final slices = LedgerStats.byCategory(entries, expense: true);
  return {for (final s in slices) s.categoryId: s.totalCents};
});

/// 当月支出的总额。
final budgetTotalSpentProvider = Provider<int>((ref) {
  final spend = ref.watch(budgetSpendProvider);
  return spend.values.fold<int>(0, (sum, v) => sum + v);
});

/// 预算执行计划（总预算 + 分类预算）。
final budgetPlanProvider = Provider<BudgetPlan>((ref) {
  final rows = ref.watch(budgetRowsProvider).value ?? const <BudgetRow>[];
  return BudgetPlan.build(
    targets: rows.map(
      (r) => (
        categoryId: r.categoryId,
        name: r.name,
        iconKey: r.iconKey,
        colorValue: r.colorValue,
        limitCents: r.limitCents,
      ),
    ),
    spentByCategory: ref.watch(budgetSpendProvider),
    totalSpentCents: ref.watch(budgetTotalSpentProvider),
  );
});

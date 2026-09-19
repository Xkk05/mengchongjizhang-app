/// 统计聚合 —— 纯函数，不依赖数据层类型，便于单测。
library;

/// 聚合输入：把数据层的行压成计算所需的最小字段集。
typedef StatEntry = ({
  DateTime at,
  int amountCents,
  bool isExpense,
  int categoryId,
  String categoryName,
  String iconKey,
  int colorValue,
});

/// 分类维度的一条统计。
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.totalCents,
    required this.count,
    required this.ratio,
  });

  final int categoryId;
  final String name;
  final String iconKey;
  final int colorValue;

  /// 该分类合计金额（分）。
  final int totalCents;

  /// 笔数。
  final int count;

  /// 占总额比例，0~1。
  final double ratio;
}

/// 某个自然日的收支。
class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.expenseCents,
    required this.incomeCents,
  });

  final DateTime day;
  final int expenseCents;
  final int incomeCents;

  int get balanceCents => incomeCents - expenseCents;
}

/// 收支合计。
class StatTotals {
  const StatTotals({required this.expenseCents, required this.incomeCents});

  final int expenseCents;
  final int incomeCents;

  int get balanceCents => incomeCents - expenseCents;

  static const StatTotals empty =
      StatTotals(expenseCents: 0, incomeCents: 0);
}

class LedgerStats {
  const LedgerStats._();

  /// 按分类汇总，金额降序；不在 [expense] 方向的记录会被忽略。
  static List<CategorySlice> byCategory(
    Iterable<StatEntry> entries, {
    required bool expense,
  }) {
    final sums = <int, int>{};
    final counts = <int, int>{};
    final meta = <int, StatEntry>{};
    var total = 0;

    for (final e in entries) {
      if (e.isExpense != expense || e.amountCents <= 0) continue;
      sums[e.categoryId] = (sums[e.categoryId] ?? 0) + e.amountCents;
      counts[e.categoryId] = (counts[e.categoryId] ?? 0) + 1;
      // 分类元信息（名称/图标/颜色）在同一分类下必然一致，留最后一条即可。
      meta[e.categoryId] = e;
      total += e.amountCents;
    }

    final ids = sums.keys.toList()
      ..sort((a, b) {
        final byAmount = sums[b]!.compareTo(sums[a]!);
        return byAmount != 0 ? byAmount : a.compareTo(b);
      });

    return ids
        .map(
          (id) => CategorySlice(
            categoryId: id,
            name: meta[id]!.categoryName,
            iconKey: meta[id]!.iconKey,
            colorValue: meta[id]!.colorValue,
            totalCents: sums[id]!,
            count: counts[id]!,
            ratio: total == 0 ? 0 : sums[id]! / total,
          ),
        )
        .toList(growable: false);
  }

  /// 逐日收支，覆盖 [days] 天并以 [today] 结尾；无数据的日期补 0。
  static List<DailyPoint> dailyTrend(
    Iterable<StatEntry> entries, {
    required int days,
    required DateTime today,
  }) {
    assert(days > 0, 'days 必须为正');
    final end = DateTime(today.year, today.month, today.day);
    final start = DateTime(end.year, end.month, end.day - (days - 1));

    final buckets = <DateTime, (int expense, int income)>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      buckets[d] = (0, 0);
    }

    for (final e in entries) {
      if (e.amountCents <= 0) continue;
      final d = DateTime(e.at.year, e.at.month, e.at.day);
      final cur = buckets[d];
      if (cur == null) continue; // 区间之外，忽略
      buckets[d] = e.isExpense
          ? (cur.$1 + e.amountCents, cur.$2)
          : (cur.$1, cur.$2 + e.amountCents);
    }

    final days0 = buckets.keys.toList()..sort();
    return days0
        .map(
          (d) => DailyPoint(
            day: d,
            expenseCents: buckets[d]!.$1,
            incomeCents: buckets[d]!.$2,
          ),
        )
        .toList(growable: false);
  }

  static StatTotals totals(Iterable<StatEntry> entries) {
    var expense = 0;
    var income = 0;
    for (final e in entries) {
      if (e.amountCents <= 0) continue;
      if (e.isExpense) {
        expense += e.amountCents;
      } else {
        income += e.amountCents;
      }
    }
    return StatTotals(expenseCents: expense, incomeCents: income);
  }

  /// 一组数值中的最大值，空集合返回 0 —— 图表定标用。
  static int maxValue(Iterable<int> values) {
    var max = 0;
    for (final v in values) {
      if (v > max) max = v;
    }
    return max;
  }
}

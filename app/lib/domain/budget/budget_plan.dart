/// 预算计划 —— 纯函数聚合，不依赖数据层类型，便于单测。
library;

/// 预算目标：`categoryId` 为空表示该月的总预算。
typedef BudgetTarget = ({
  int? categoryId,
  String name,
  String iconKey,
  int colorValue,
  int limitCents,
});

/// 一条预算的执行情况。
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.limitCents,
    required this.spentCents,
  });

  final int? categoryId;
  final String name;
  final String iconKey;
  final int colorValue;

  /// 预算上限（分）。
  final int limitCents;

  /// 已花（分）。
  final int spentCents;

  bool get isOverall => categoryId == null;

  /// 剩余额度（分），超支时为负。
  int get remainingCents => limitCents - spentCents;

  bool get isOver => spentCents > limitCents;

  /// 使用率；预算为 0 时按 0 处理，避免除零。
  double get ratio => limitCents <= 0 ? 0 : spentCents / limitCents;

  /// 进度条取值，封顶 1.0（超支由 `isOver` 单独标注）。
  double get barValue => ratio.clamp(0.0, 1.0);
}

/// 一个月的完整预算视图。
class BudgetPlan {
  const BudgetPlan({required this.overall, required this.lines});

  /// 总预算；未设置时为 null。
  final BudgetLine? overall;

  /// 分类预算，按使用率降序。
  final List<BudgetLine> lines;

  bool get hasAny => overall != null || lines.isNotEmpty;

  /// 分类预算的额度合计。
  int get totalLimitCents =>
      lines.fold<int>(0, (sum, l) => sum + l.limitCents);

  int get overCount => lines.where((l) => l.isOver).length;

  static const BudgetPlan empty = BudgetPlan(overall: null, lines: []);

  /// 按分类支出归并出预算执行情况。
  ///
  /// [spentByCategory] 为当月各支出分类的合计；
  /// [totalSpentCents] 为当月支出总额（总预算用，避免依赖 map 是否完整）。
  static BudgetPlan build({
    required Iterable<BudgetTarget> targets,
    required Map<int, int> spentByCategory,
    required int totalSpentCents,
  }) {
    BudgetLine? overall;
    final lines = <BudgetLine>[];

    for (final t in targets) {
      if (t.limitCents <= 0) continue;
      final spent = t.categoryId == null
          ? totalSpentCents
          : (spentByCategory[t.categoryId] ?? 0);

      final line = BudgetLine(
        categoryId: t.categoryId,
        name: t.name,
        iconKey: t.iconKey,
        colorValue: t.colorValue,
        limitCents: t.limitCents,
        spentCents: spent,
      );

      if (line.isOverall) {
        // 同月只应有一条总预算；若数据异常，取额度较大的一条。
        if (overall == null || line.limitCents > overall.limitCents) {
          overall = line;
        }
      } else {
        lines.add(line);
      }
    }

    lines.sort((a, b) {
      final byRatio = b.ratio.compareTo(a.ratio);
      if (byRatio != 0) return byRatio;
      final byLimit = b.limitCents.compareTo(a.limitCents);
      if (byLimit != 0) return byLimit;
      return (a.categoryId ?? 0).compareTo(b.categoryId ?? 0);
    });

    return BudgetPlan(overall: overall, lines: lines);
  }
}

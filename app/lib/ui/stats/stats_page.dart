import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/money.dart';
import '../../data/db/tables.dart';
import '../../domain/stats/ledger_stats.dart';
import '../../state/stats_providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../common/month_bar.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final kind = ref.watch(statsKindProvider);
    final slices = ref.watch(statsSlicesProvider);
    final totals = ref.watch(statsTotalsProvider);
    final points = ref.watch(trendPointsProvider);
    final loading = ref.watch(statsRangeProvider).isLoading;

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('统计'),
        backgroundColor: c.pageBg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
        children: [
          const MonthBar(),
          const SizedBox(height: AppSpacing.sm),
          _KindToggle(
            kind: kind,
            onChanged: (k) => ref.read(statsKindProvider.notifier).set(k),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _DonutCard(
              slices: slices,
              kind: kind,
              totalCents: kind == TxKind.expense
                  ? totals.expenseCents
                  : totals.incomeCents,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RankCard(slices: slices, kind: kind),
            const SizedBox(height: AppSpacing.sm),
            _TrendCard(points: points),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 类型切换

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final TxKind kind;
  final ValueChanged<TxKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget seg(String label, TxKind k) {
      final on = k == kind;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? c.coral : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.md,
                fontWeight: FontWeight.w700,
                color: on ? c.onCoral : c.ink2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [seg('支出构成', TxKind.expense), seg('收入构成', TxKind.income)],
      ),
    );
  }
}

// ------------------------------------------------------------------ 饼图

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.slices,
    required this.kind,
    required this.totalCents,
  });

  final List<CategorySlice> slices;
  final TxKind kind;
  final int totalCents;

  /// 只画前 6 个，其余合并成「其他」，避免环上碎片过多。
  static const int _maxSlices = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (slices.isEmpty || totalCents <= 0) {
      return AppCard(
        child: _EmptyHint(
          text: '本月还没有${kind == TxKind.expense ? '支出' : '收入'}记录',
        ),
      );
    }

    final shown = <CategorySlice>[...slices.take(_maxSlices)];
    if (slices.length > _maxSlices) {
      final rest = slices.skip(_maxSlices);
      final restTotal = rest.fold<int>(0, (s, e) => s + e.totalCents);
      shown.add(
        CategorySlice(
          categoryId: -1,
          name: '其他',
          iconKey: 'more',
          // 合并项的配色用固定灰，不参与数据库调色板。
          colorValue: 0xFF7A8B84,
          totalCents: restTotal,
          count: rest.fold<int>(0, (s, e) => s + e.count),
          ratio: totalCents == 0 ? 0 : restTotal / totalCents,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == TxKind.expense ? '支出构成' : '收入构成',
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 188,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 54,
                    startDegreeOffset: -90,
                    sections: [
                      for (final s in shown)
                        PieChartSectionData(
                          value: s.totalCents.toDouble(),
                          color: s.categoryId == -1
                              ? c.ink3
                              : Color(s.colorValue),
                          radius: 24,
                          showTitle: s.ratio >= 0.08,
                          title: '${(s.ratio * 100).round()}%',
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kind == TxKind.expense ? '共支出' : '共收入',
                      style: TextStyle(
                        fontSize: AppFontSizes.xs,
                        color: c.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      child: Text(
                        '¥${Money.yuan(totalCents)}',
                        style: TextStyle(
                          fontSize: AppFontSizes.xl,
                          fontWeight: FontWeight.w800,
                          color: kind == TxKind.expense
                              ? c.coralText
                              : c.mintText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 排行

class _RankCard extends StatelessWidget {
  const _RankCard({required this.slices, required this.kind});

  final List<CategorySlice> slices;
  final TxKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (slices.isEmpty) return const SizedBox.shrink();

    final maxTotal = LedgerStats.maxValue(slices.map((e) => e.totalCents));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分类排行',
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < slices.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _RankRow(slice: slices[i], maxTotal: maxTotal, rank: i + 1),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.slice,
    required this.maxTotal,
    required this.rank,
  });

  final CategorySlice slice;
  final int maxTotal;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = Color(slice.colorValue);
    final barRatio = maxTotal == 0 ? 0.0 : slice.totalCents / maxTotal;

    return Row(
      children: [
        SoftIcon(icon: iconFor(slice.iconKey), color: color, size: 34),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    slice.name,
                    style: TextStyle(
                      fontSize: AppFontSizes.md,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${slice.count} 笔',
                    style: TextStyle(fontSize: AppFontSizes.xs, color: c.ink3),
                  ),
                  const Spacer(),
                  Text(
                    '¥${Money.yuan(slice.totalCents)}',
                    style: TextStyle(
                      fontSize: AppFontSizes.md,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: barRatio.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: c.surface3,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(slice.ratio * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: AppFontSizes.xs,
                        fontWeight: FontWeight.w700,
                        color: c.ink3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 近 7 日

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // dailyTrend 会把无数据的日期补 0，因此「空态」要在全部为 0 时判定。
    final hasData =
        points.any((p) => p.expenseCents > 0 || p.incomeCents > 0);
    if (points.isEmpty || !hasData) {
      return AppCard(child: _EmptyHint(text: '近 7 日暂无记录'));
    }

    // 以「元」为单位定标，留 20% 顶部余量。
    final maxCents = LedgerStats.maxValue(
      points.map((p) =>
          p.expenseCents > p.incomeCents ? p.expenseCents : p.incomeCents),
    );
    final maxY = maxCents <= 0 ? 100.0 : maxCents / 100.0 * 1.2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '近 7 日收支',
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              _LegendDot(color: c.coral, label: '支出'),
              const SizedBox(width: AppSpacing.sm),
              _LegendDot(color: c.mint, label: '收入'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 156,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (v) => FlLine(color: c.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: maxY / 3,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toStringAsFixed(0),
                          style: TextStyle(fontSize: 9, color: c.ink3),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${points[i].day.day}',
                            style: TextStyle(fontSize: 10, color: c.ink3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].expenseCents / 100.0,
                          color: c.coral,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: points[i].incomeCents / 100.0,
                          color: c.mint,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: AppFontSizes.xs, color: c.ink3),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 34, color: c.ink3.withValues(alpha: 0.45)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(fontSize: AppFontSizes.md, color: c.ink3),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/calendar/month_calendar.dart';
import '../../domain/stats/ledger_stats.dart';
import '../../state/calendar_providers.dart';
import '../../state/stats_providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../common/month_bar.dart';

/// 账单日历：按月铺开每天的收支，点某天看当天明细。
///
/// 月份与统计页共享（同一个 `selectedMonthProvider`），翻月互相同步。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final grid = ref.watch(calendarGridProvider);
    final totals = ref.watch(statsTotalsProvider);
    final busiest = MonthCalendar.busiestExpenseDay(grid);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('账单日历'),
        backgroundColor: c.pageBg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
        children: [
          const MonthBar(),
          const SizedBox(height: AppSpacing.sm),
          _MonthSummaryCard(totals: totals, busiest: busiest),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              children: [
                const _WeekdayHeader(),
                const SizedBox(height: 2),
                _MonthGrid(grid: grid),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SelectedDayCard(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 月度汇总

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.totals, required this.busiest});

  final StatTotals totals;
  final CalendarDay? busiest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月概览',
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _MiniStat(
                label: '支出',
                value: '¥${Money.yuan(totals.expenseCents)}',
                color: c.coralText,
              ),
              _MiniStat(
                label: '收入',
                value: '¥${Money.yuan(totals.incomeCents)}',
                color: c.mintText,
              ),
              _MiniStat(
                label: '结余',
                value: '¥${Money.yuan(totals.balanceCents)}',
                color: c.ink,
              ),
            ],
          ),
          if (busiest != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 14, color: c.coral),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '花得最多的一天：${DateLabels.monthDay(busiest!.date)}'
                    '（¥${Money.yuan(busiest!.expenseCents)}）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 日历网格

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final w in MonthCalendar.weekdayHeaders)
          Expanded(
            child: Center(
              child: Text(
                w,
                style: TextStyle(
                  fontSize: AppFontSizes.xs,
                  fontWeight: FontWeight.w700,
                  color: c.ink3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.grid});

  final List<CalendarDay> grid;

  @override
  Widget build(BuildContext context) {
    // 自己按 7 个一行切，不用 GridView —— 避免 childAspectRatio 在
    // 不同画布下把格子压变形，也免得懒构建让测试找不到靠下的日期。
    final rows = <Widget>[];
    for (var i = 0; i < grid.length; i += 7) {
      rows.add(
        Row(
          children: [
            for (var j = i; j < i + 7 && j < grid.length; j++)
              Expanded(
                child: _DayCell(
                  // 稳定的定位键：日期在同一屏里可能重复（邻月补位），
                  // 按「日号文本」找会撞车，测试与无障碍都用这个键更可靠。
                  key: ValueKey(
                    'cal-day-${grid[j].date.year}-${grid[j].date.month}-${grid[j].date.day}',
                  ),
                  day: grid[j],
                ),
              ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({super.key, required this.day});

  final CalendarDay day;

  static const double _height = 54;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(selectedDayProvider);
    final isSelected =
        day.inMonth && selected != null && MonthCalendar.isSameDay(day.date, selected);
    final isToday = day.inMonth && MonthCalendar.isSameDay(day.date, DateTime.now());

    final Color? tint = !day.inMonth
        ? null
        : (isSelected ? c.coral.withValues(alpha: 0.12) : null);
    final Color? border = isSelected
        ? c.coral
        : (isToday ? c.mint.withValues(alpha: 0.75) : null);

    // 邻月日期只做占位，灰掉且不可点。
    final dayColor = day.inMonth ? c.ink : c.ink3.withValues(alpha: 0.35);

    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: tint ?? Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.xs),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.xs),
            onTap: day.inMonth
                ? () => ref.read(selectedDayProvider.notifier).select(day.date)
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xs),
                border: border == null
                    ? null
                    : Border.all(color: border, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.date.day}',
                    style: TextStyle(
                      fontSize: AppFontSizes.sm,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: dayColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (day.hasData)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        MonthCalendar.compactAmount(day.primaryCents),
                        style: TextStyle(
                          fontSize: AppFontSizes.xxs,
                          fontWeight: FontWeight.w700,
                          color: day.primaryIsExpense ? c.coralText : c.mintText,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 选中日明细

class _SelectedDayCard extends ConsumerWidget {
  const _SelectedDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final day = ref.watch(selectedDayProvider);
    final records = ref.watch(selectedDayRecordsProvider);
    final totals = ref.watch(selectedDayTotalsProvider);

    if (day == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 16, color: c.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '点日历里的任意一天，查看当天明细',
                style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateLabels.monthDay(day)} ${DateLabels.weekday(day)}',
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              if (records.isNotEmpty)
                Text(
                  '支出 ¥${Money.yuan(totals.expenseCents)}'
                  '${totals.incomeCents > 0 ? ' · 收入 ¥${Money.yuan(totals.incomeCents)}' : ''}',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w700,
                    color: c.ink3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                '这天还没有记账',
                style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
              ),
            )
          else
            for (final r in records) _DayRecordTile(record: r),
        ],
      ),
    );
  }
}

class _DayRecordTile extends StatelessWidget {
  const _DayRecordTile({required this.record});

  final TxRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = record.note.trim().isEmpty ? record.categoryName : record.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SoftIcon(
            icon: iconFor(record.categoryIconKey),
            color: Color(record.categoryColor),
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                Text(
                  '${record.categoryName} · ${record.accountName}'
                  ' · ${DateLabels.time(record.occurredAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Money.signed(record.amountCents, isExpense: record.isExpense),
              style: TextStyle(
                fontSize: AppFontSizes.md,
                fontWeight: FontWeight.w800,
                color: record.isExpense ? c.coralText : c.mintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

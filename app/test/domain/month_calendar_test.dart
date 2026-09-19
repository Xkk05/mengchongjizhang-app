import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/calendar/month_calendar.dart';

CalendarEntry e(int day, {required bool expense, required int cents}) =>
    (at: DateTime(2026, 9, day), isExpense: expense, amountCents: cents);

void main() {
  group('日期算术', () {
    test('daysInMonth 认得出闰年 2 月', () {
      expect(MonthCalendar.daysInMonth(2026, 9), 30);
      expect(MonthCalendar.daysInMonth(2026, 12), 31);
      expect(MonthCalendar.daysInMonth(2026, 2), 28);
      expect(MonthCalendar.daysInMonth(2024, 2), 29);
      expect(MonthCalendar.daysInMonth(2000, 2), 29, reason: '整百年但能被 400 整除');
      expect(MonthCalendar.daysInMonth(1900, 2), 28);
    });

    test('leadingBlanks 按周一开头算（2026 年 9~12 月逐月校验）', () {
      // 2026-09-01 是周二 → 补 1 格
      expect(MonthCalendar.leadingBlanks(2026, 9), 1);
      expect(MonthCalendar.leadingBlanks(2026, 10), 3);
      expect(MonthCalendar.leadingBlanks(2026, 11), 6, reason: '11 月 1 号是周日');
      expect(MonthCalendar.leadingBlanks(2026, 12), 1);
    });

    test('isSameDay 只看年月日', () {
      expect(
        MonthCalendar.isSameDay(
            DateTime(2026, 9, 19, 0, 1), DateTime(2026, 9, 19, 23, 59)),
        isTrue,
      );
      expect(
        MonthCalendar.isSameDay(DateTime(2026, 9, 19), DateTime(2026, 9, 20)),
        isFalse,
      );
      expect(
        MonthCalendar.isSameDay(DateTime(2025, 9, 19), DateTime(2026, 9, 19)),
        isFalse,
      );
    });
  });

  group('月历网格', () {
    test('格数是 7 的整数倍，且能装下整月', () {
      final grid = MonthCalendar.build(year: 2026, month: 9, entries: const []);
      expect(grid.length % 7, 0);
      expect(grid.length, greaterThanOrEqualTo(30));
      expect(grid.length, 35, reason: '9 月补 1 格 + 30 天 = 31 → 向上取整到 35');
    });

    test('整月的每一天都出现且标记为 inMonth', () {
      final grid = MonthCalendar.build(year: 2026, month: 9, entries: const []);
      final inMonth = grid.where((d) => d.inMonth).toList();
      expect(inMonth, hasLength(30));
      expect(inMonth.map((d) => d.date.day).toList(),
          List.generate(30, (i) => i + 1));
      expect(inMonth.every((d) => d.date.month == 9), isTrue);
    });

    test('首尾补的是邻月日期，标记 inMonth=false 且不带数据', () {
      final grid = MonthCalendar.build(year: 2026, month: 9, entries: const []);
      final padding = grid.where((d) => !d.inMonth).toList();
      expect(padding, hasLength(5));

      final head = grid.first;
      expect(head.inMonth, isFalse);
      expect(head.date, DateTime(2026, 8, 31), reason: '9/1 是周二，前面补 8/31');

      final tail = grid.last;
      expect(tail.inMonth, isFalse);
      expect(tail.date, DateTime(2026, 10, 4));
      expect(padding.every((d) => d.count == 0 && d.primaryCents == 0), isTrue);
    });

    test('补齐行数随月而变（2 月可能只用 4 行）', () {
      // 2026-02-01 是周日 → 补 6 格 + 28 天 = 34 → 35
      final feb = MonthCalendar.build(year: 2026, month: 2, entries: const []);
      expect(feb.length % 7, 0);
      expect(feb.where((d) => d.inMonth), hasLength(28));
    });
  });

  group('每日聚合', () {
    test('同一天的支出累加、收入分开计、笔数正确', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [
          e(3, expense: true, cents: 1200),
          e(3, expense: true, cents: 800),
          e(3, expense: false, cents: 5000),
        ],
      );
      final day = grid.firstWhere((d) => d.inMonth && d.date.day == 3);
      expect(day.expenseCents, 2000);
      expect(day.incomeCents, 5000);
      expect(day.count, 3);
      expect(day.hasData, isTrue);
      expect(day.balanceCents, 3000);
    });

    test('只有收入的一天优先展示收入', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [e(5, expense: false, cents: 12300)],
      );
      final day = grid.firstWhere((d) => d.date.day == 5);
      expect(day.primaryIsExpense, isFalse);
      expect(day.primaryCents, 12300);
    });

    test('有支出时优先展示支出金额', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [
          e(5, expense: false, cents: 999999),
          e(5, expense: true, cents: 1500),
        ],
      );
      final day = grid.firstWhere((d) => d.date.day == 5);
      expect(day.primaryIsExpense, isTrue);
      expect(day.primaryCents, 1500);
    });

    test('其它月份 / 其它年份的流水一律不参与', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [
          (at: DateTime(2026, 8, 31), isExpense: true, amountCents: 111),
          (at: DateTime(2026, 10, 1), isExpense: true, amountCents: 222),
          (at: DateTime(2025, 9, 19), isExpense: true, amountCents: 333),
        ],
      );
      expect(grid.every((d) => d.count == 0), isTrue,
          reason: '邻月与去年同月都不该落进本月格子');
    });

    test('没有任何流水时全是空格子', () {
      final grid = MonthCalendar.build(year: 2026, month: 9, entries: const []);
      expect(grid.every((d) => !d.hasData), isTrue);
      expect(MonthCalendar.busiestExpenseDay(grid), isNull);
    });
  });

  group('支出最高的一天', () {
    test('取支出最大的一天，忽略只有收入的日子', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [
          e(3, expense: true, cents: 1000),
          e(8, expense: true, cents: 5000),
          e(9, expense: false, cents: 99999),
          e(12, expense: true, cents: 2000),
        ],
      );
      final busiest = MonthCalendar.busiestExpenseDay(grid);
      expect(busiest, isNotNull);
      expect(busiest!.date.day, 8);
      expect(busiest.expenseCents, 5000);
    });

    test('只看本月（邻月格子即便有值也不参与）', () {
      final grid = MonthCalendar.build(
        year: 2026,
        month: 9,
        entries: [e(30, expense: true, cents: 4200)],
      );
      expect(MonthCalendar.busiestExpenseDay(grid)!.date.day, 30);
    });
  });

  group('compactAmount', () {
    test('分三档降精度', () {
      expect(MonthCalendar.compactAmount(0), '0.0');
      expect(MonthCalendar.compactAmount(500), '5.0');
      expect(MonthCalendar.compactAmount(1234), '12.3');
      expect(MonthCalendar.compactAmount(20000), '200', reason: '200 元 → 取整');
      expect(MonthCalendar.compactAmount(123456), '1.2k');
      expect(MonthCalendar.compactAmount(123456789), '1234.6k');
    });
  });
}

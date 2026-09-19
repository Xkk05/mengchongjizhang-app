import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/utils/date_labels.dart';
import 'package:suixin_pet_ledger/core/utils/money.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/stats_providers.dart';
import 'package:suixin_pet_ledger/ui/calendar/calendar_page.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  TxRecord rec({
    required int day,
    required bool expense,
    required int cents,
    String note = '',
    String category = '餐饮',
  }) =>
      TxRecord(
        row: TxRow(
          id: day,
          ledgerId: 1,
          accountId: 1,
          categoryId: 1,
          kind: expense ? TxKind.expense : TxKind.income,
          amountCents: cents,
          note: note,
          occurredAt: DateTime(now.year, now.month, day, 12, 30),
          createdAt: DateTime(now.year, now.month, day, 12, 30),
        ),
        categoryName: category,
        categoryIconKey: 'fork',
        categoryColor: 0xFFE2584A,
        accountName: '支付宝',
      );

  ValueKey<String> dayKey(DateTime d) =>
      ValueKey('cal-day-${d.year}-${d.month}-${d.day}');

  Future<void> pump(
    WidgetTester tester,
    List<TxRecord> records,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 页面靠月度流水取数；这里直接喂固定数据，不拉起真数据库。
          statsRangeProvider.overrideWith((ref) => Stream.value(records)),
        ],
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('账单日历', () {
    testWidgets('标题、月份条与周标题都在', (tester) async {
      await pump(tester, const []);
      expect(find.text('账单日历'), findsOneWidget);
      expect(find.text(DateLabels.yearMonth(now)), findsOneWidget);
      for (final w in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(w), findsOneWidget, reason: '周标题缺了「$w」');
      }
    });

    testWidgets('本月网格把整月每一天都铺出来', (tester) async {
      await pump(tester, const []);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      // 用定位键逐日确认（按「日号文本」找会被邻月补位撞车）。
      for (final d in [1, 15, daysInMonth]) {
        expect(
          find.byKey(dayKey(DateTime(now.year, now.month, d))),
          findsOneWidget,
          reason: '$d 号格子不见了',
        );
      }
    });

    testWidgets('月度汇总按本月流水求和', (tester) async {
      final records = [
        rec(day: 5, expense: true, cents: 1200),
        rec(day: 6, expense: false, cents: 5000),
        rec(day: today.day, expense: true, cents: 999),
      ];
      await pump(tester, records);

      final expense = records
          .where((r) => r.isExpense)
          .fold<int>(0, (a, r) => a + r.amountCents);
      final income = records
          .where((r) => !r.isExpense)
          .fold<int>(0, (a, r) => a + r.amountCents);

      expect(find.text('¥${Money.yuan(expense)}'), findsOneWidget);
      expect(find.text('¥${Money.yuan(income)}'), findsOneWidget);
      expect(find.text('¥${Money.yuan(income - expense)}'), findsOneWidget);
    });

    testWidgets('有支出的日子在格子里显示紧凑金额', (tester) async {
      await pump(tester, [rec(day: 20, expense: true, cents: 123456)]);
      expect(find.text('1.2k'), findsOneWidget);
    });

    testWidgets('默认选中今天并显示当天明细', (tester) async {
      await pump(tester, [
        rec(day: today.day, expense: true, cents: 2500, note: '今天的账'),
      ]);
      expect(find.text('${DateLabels.monthDay(today)} ${DateLabels.weekday(today)}'),
          findsOneWidget);
      expect(find.text('今天的账'), findsOneWidget);
    });

    testWidgets('点另一天会切换明细', (tester) async {
      final otherDay = today.day == 5 ? 6 : 5;
      final other = DateTime(now.year, now.month, otherDay);
      await pump(tester, [
        rec(day: otherDay, expense: true, cents: 1200, note: '选定日的账'),
        rec(day: today.day, expense: true, cents: 999, note: '今天的账'),
      ]);

      expect(find.text('今天的账'), findsOneWidget);

      await tester.tap(find.byKey(dayKey(other)));
      await tester.pumpAndSettle();

      expect(find.text('${DateLabels.monthDay(other)} ${DateLabels.weekday(other)}'),
          findsOneWidget);
      expect(find.text('选定日的账'), findsOneWidget);
      expect(find.text('今天的账'), findsNothing, reason: '明细应随选中日切换');
    });

    testWidgets('提示花得最多的一天', (tester) async {
      await pump(tester, [
        rec(day: 5, expense: true, cents: 1200),
        rec(day: 12, expense: true, cents: 8800),
      ]);
      expect(find.textContaining('花得最多的一天'), findsOneWidget);
      expect(find.textContaining('¥${Money.yuan(8800)}'), findsOneWidget);
    });

    testWidgets('没有数据时给空态而不是空白', (tester) async {
      await pump(tester, const []);
      expect(find.text('这天还没有记账'), findsOneWidget);
      expect(find.text('¥${Money.yuan(0)}'), findsWidgets);
      expect(find.textContaining('花得最多的一天'), findsNothing);
    });

    testWidgets('翻到历史月份时不预选日期', (tester) async {
      await pump(tester, [
        rec(day: today.day, expense: true, cents: 999, note: '今天的账'),
      ]);
      expect(find.text('今天的账'), findsOneWidget);

      await tester.tap(find.byTooltip('上一月'));
      await tester.pumpAndSettle();

      expect(find.text('点日历里的任意一天，查看当天明细'), findsOneWidget);
      expect(find.text('今天的账'), findsNothing);
      expect(find.text('这天还没有记账'), findsNothing);
    });
  });
}

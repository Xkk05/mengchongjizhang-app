import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/stats_providers.dart';
import 'package:suixin_pet_ledger/ui/stats/stats_page.dart';

/// 用固定数据源替换真实数据库流 —— 不依赖原生 sqlite，测试可独立运行。
Widget _host(List<TxRecord> records) {
  return ProviderScope(
    overrides: [
      statsRangeProvider.overrideWith((ref) => Stream.value(records)),
      trendRangeProvider.overrideWith((ref) => Stream.value(records)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const StatsPage(),
    ),
  );
}

TxRow _row({
  required int id,
  required int categoryId,
  required int cents,
  required bool isExpense,
}) {
  final now = DateTime.now();
  return TxRow(
    id: id,
    ledgerId: 1,
    accountId: 1,
    categoryId: categoryId,
    kind: isExpense ? TxKind.expense : TxKind.income,
    amountCents: cents,
    note: '',
    occurredAt: now,
    createdAt: now,
  );
}

/// 统计页是竖排长列表，默认 800x600 视口会把走势卡挤出可视区而不构建。
/// 这里放大画布，保证三张卡都进入 widget 树。
Future<void> _pump(WidgetTester tester, List<TxRecord> records) async {
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(records));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('无数据时统计页显示空态且不抛异常', (tester) async {
    await _pump(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('本月还没有支出记录'), findsOneWidget);
    expect(find.text('近 7 日暂无记录'), findsOneWidget);
  });

  testWidgets('有数据时渲染饼图、排行与走势三张卡', (tester) async {
    final records = <TxRecord>[
      TxRecord(
        row: _row(id: 1, categoryId: 1, cents: 3200, isExpense: true),
        categoryName: '餐饮',
        categoryIconKey: 'fork',
        categoryColor: 0xFFE2584A,
        accountName: '支付宝',
      ),
      TxRecord(
        row: _row(id: 2, categoryId: 2, cents: 800, isExpense: true),
        categoryName: '交通',
        categoryIconKey: 'bus',
        categoryColor: 0xFF1677FF,
        accountName: '微信钱包',
      ),
    ];

    await _pump(tester, records);

    expect(tester.takeException(), isNull);
    expect(find.text('分类排行'), findsOneWidget);
    expect(find.text('近 7 日收支'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    // 合计 3200 + 800 = 40.00 元（饼图中心与排行各出现一次）
    expect(find.text('¥40.00'), findsWidgets);
  });

  testWidgets('切到收入方向后回到空态', (tester) async {
    final records = <TxRecord>[
      TxRecord(
        row: _row(id: 1, categoryId: 1, cents: 3200, isExpense: true),
        categoryName: '餐饮',
        categoryIconKey: 'fork',
        categoryColor: 0xFFE2584A,
        accountName: '支付宝',
      ),
    ];

    await _pump(tester, records);

    await tester.tap(find.text('收入构成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('本月还没有收入记录'), findsOneWidget);
  });

  testWidgets('月份条可翻到上一月', (tester) async {
    await _pump(tester, const []);

    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    expect(find.text('${prev.year}年${prev.month}月'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('${prev.year}年${prev.month}月'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/budget_providers.dart';
import 'package:suixin_pet_ledger/state/stats_providers.dart';
import 'package:suixin_pet_ledger/ui/budget/budget_page.dart';

Widget _host(List<BudgetRow> rows, List<TxRecord> records) {
  return ProviderScope(
    overrides: [
      budgetRowsProvider.overrideWith((ref) => Stream.value(rows)),
      statsRangeProvider.overrideWith((ref) => Stream.value(records)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const BudgetPage(),
    ),
  );
}

BudgetRow _row({
  required int id,
  int? categoryId,
  required String name,
  required int limitCents,
}) {
  final now = DateTime.now();
  return BudgetRow(
    budget: Budget(
      id: id,
      yearMonth: now.year * 100 + now.month,
      categoryId: categoryId,
      limitCents: limitCents,
      createdAt: now,
    ),
    name: name,
    iconKey: categoryId == null ? 'budget' : 'fork',
    colorValue: categoryId == null ? 0xFF2E9E77 : 0xFFE2584A,
  );
}

TxRecord _tx({required int id, required int categoryId, required int cents}) {
  final now = DateTime.now();
  return TxRecord(
    row: TxRow(
      id: id,
      ledgerId: 1,
      accountId: 1,
      categoryId: categoryId,
      kind: TxKind.expense,
      amountCents: cents,
      note: '',
      occurredAt: now,
      createdAt: now,
    ),
    categoryName: categoryId == 1 ? '餐饮' : '交通',
    categoryIconKey: 'fork',
    categoryColor: 0xFFE2584A,
    accountName: '支付宝',
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<BudgetRow> rows,
  List<TxRecord> records,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(rows, records));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('未设预算时两处都显示空态', (tester) async {
    await _pump(tester, const [], const []);

    expect(tester.takeException(), isNull);
    expect(find.text('本月还没有总预算'), findsOneWidget);
    expect(find.text('还没有分类预算，给爱超支的分类单独设个上限吧'), findsOneWidget);
  });

  testWidgets('总预算展示已用 / 上限 / 剩余', (tester) async {
    await _pump(
      tester,
      [_row(id: 1, name: '总预算', limitCents: 800000)],
      [
        _tx(id: 1, categoryId: 1, cents: 15000),
        _tx(id: 2, categoryId: 2, cents: 25000),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('总预算'), findsOneWidget);
    expect(find.text('¥400.00'), findsOneWidget); // 已用
    expect(find.text('/ ¥8,000.00'), findsOneWidget);
    expect(find.text('还可用 ¥7,600.00'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
  });

  testWidgets('分类预算超支时出现超支标记', (tester) async {
    await _pump(
      tester,
      [
        _row(id: 1, name: '总预算', limitCents: 800000),
        _row(id: 2, categoryId: 1, name: '餐饮', limitCents: 10000),
      ],
      [
        _tx(id: 1, categoryId: 1, cents: 15000),
        _tx(id: 2, categoryId: 2, cents: 25000),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('超支 ¥50.00'), findsOneWidget);
    expect(find.text('¥150.00'), findsOneWidget); // 分类已用
    expect(find.text('150%'), findsOneWidget);
    // 总预算未超支，不应出现「超支」文案在总预算卡上
    expect(find.text('还可用 ¥7,600.00'), findsOneWidget);
  });

  testWidgets('月份条可翻到上一月且不允许翻到未来', (tester) async {
    await _pump(tester, const [], const []);

    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    expect(find.text('${prev.year}年${prev.month}月'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('${prev.year}年${prev.month}月'), findsOneWidget);

    // 回到当前月后，「下一月」应被禁用
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final nextBtn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(nextBtn.onPressed, isNull);
  });
}

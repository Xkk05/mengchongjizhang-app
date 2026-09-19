import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/domain/assets/account_balance.dart';
import 'package:suixin_pet_ledger/state/asset_providers.dart';
import 'package:suixin_pet_ledger/ui/assets/assets_page.dart';

Widget _host(List<AccountBalance> accounts) {
  return ProviderScope(
    overrides: [
      accountsWithBalanceProvider.overrideWith((ref) => Stream.value(accounts)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const AssetsPage(),
    ),
  );
}

AccountBalance _acc({
  required int id,
  required String name,
  required int initialCents,
  required int flowCents,
  int txCount = 0,
  bool included = true,
}) =>
    AccountBalance(
      id: id,
      name: name,
      iconKey: 'wallet',
      colorValue: 0xFF2E9E77,
      initialCents: initialCents,
      flowCents: flowCents,
      txCount: txCount,
      includedInNetWorth: included,
    );

Future<void> _pump(WidgetTester tester, List<AccountBalance> accounts) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(accounts));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('无账户时显示空态与零净资产', (tester) async {
    await _pump(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('¥0.00'), findsOneWidget);
    expect(find.text('还没有账户'), findsOneWidget);
    expect(find.text('账户明细'), findsNothing);
  });

  testWidgets('有账户时展示派生余额、初始余额与笔数', (tester) async {
    await _pump(tester, [
      _acc(id: 1, name: '现金', initialCents: 12680, flowCents: -1800, txCount: 1),
      _acc(
        id: 2,
        name: '招商银行',
        initialCents: 3200000,
        flowCents: -260000,
        txCount: 1,
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('招商银行'), findsOneWidget);

    // 余额由「初始 + 流水净额」派生
    expect(find.text('¥108.80'), findsOneWidget);
    expect(find.text('¥29,400.00'), findsOneWidget);

    // 净资产 = 10,880 + 2,940,000 分
    expect(find.text('¥29,508.80'), findsOneWidget);
    expect(find.text('初始 ¥126.80 · 1 笔'), findsOneWidget);
  });

  testWidgets('余额为负的账户带负号展示', (tester) async {
    await _pump(tester, [
      _acc(id: 1, name: '信用卡', initialCents: 0, flowCents: -15800, txCount: 2),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('-¥158.00'), findsOneWidget);
  });

  testWidgets('不计入净资产的账户不影响净资产合计', (tester) async {
    await _pump(tester, [
      _acc(id: 1, name: '现金', initialCents: 10000, flowCents: 0, included: true),
      _acc(
        id: 2,
        name: '备用金',
        initialCents: 500000,
        flowCents: 0,
        included: false,
      ),
    ]);

    expect(tester.takeException(), isNull);
    // 净资产只算「现金」的 ¥100.00
    expect(find.text('¥100.00'), findsWidgets);
    expect(find.text('¥5,000.00'), findsWidgets);
  });
}

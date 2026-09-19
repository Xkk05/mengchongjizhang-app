import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/assets/account_balance.dart';

AccountBalance _acc({
  int id = 1,
  String name = '现金',
  int initial = 10000,
  int flow = 0,
  bool included = true,
  int txCount = 0,
}) =>
    AccountBalance(
      id: id,
      name: name,
      iconKey: 'wallet',
      colorValue: 0xFF2E9E77,
      initialCents: initial,
      flowCents: flow,
      txCount: txCount,
      includedInNetWorth: included,
    );

void main() {
  group('AccountBalance', () {
    test('余额 = 初始余额 + 流水净额', () {
      expect(_acc(initial: 10000, flow: -2500).balanceCents, 7500);
      expect(_acc(initial: 0, flow: 3200).balanceCents, 3200);
    });

    test('流水净额可为负，余额随之变负', () {
      expect(_acc(initial: 100, flow: -500).balanceCents, -400);
    });

    test('copyWith 只改流水与笔数，其余字段保留', () {
      final a = _acc(initial: 5000, flow: 100, txCount: 1);
      final b = a.copyWith(flowCents: 900, txCount: 4);
      expect(b.flowCents, 900);
      expect(b.txCount, 4);
      expect(b.initialCents, 5000);
      expect(b.name, a.name);
      expect(b.includedInNetWorth, a.includedInNetWorth);
    });
  });

  group('AccountBalance.netWorth', () {
    test('累加所有账户余额', () {
      final list = [
        _acc(id: 1, initial: 10000, flow: 0), // 100.00
        _acc(id: 2, initial: 50000, flow: -20000), // 300.00
      ];
      expect(AccountBalance.netWorth(list), 40000);
    });

    test('不计入净资产的账户被排除', () {
      final list = [
        _acc(id: 1, initial: 10000, included: true),
        _acc(id: 2, initial: 990000, included: false),
      ];
      expect(AccountBalance.netWorth(list), 10000);
    });

    test('空集合为 0', () {
      expect(AccountBalance.netWorth(const []), 0);
    });
  });
}

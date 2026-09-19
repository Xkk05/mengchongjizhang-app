import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/assets/account_balance.dart';
import 'providers.dart';

/// 账户 + 流水净额 → 实时余额（随数据库变更自动刷新）。
final accountsWithBalanceProvider =
    StreamProvider<List<AccountBalance>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAccountsWithBalance();
});

/// 净资产合计。
final netWorthProvider = Provider<int>((ref) {
  final accounts = ref.watch(accountsWithBalanceProvider).value ?? const [];
  return AccountBalance.netWorth(accounts);
});

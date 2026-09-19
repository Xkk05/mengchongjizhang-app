import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../data/repositories/ledger_repository.dart';
import 'providers.dart';

/// 最近账目（自动跟随数据库变更刷新）。
final recentTransactionsProvider = StreamProvider<List<TxRecord>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchRecent();
});

/// 本月收支合计。
final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchMonthSummary(DateTime.now());
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAccounts();
});

final ledgersProvider = StreamProvider<List<Ledger>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchLedgers();
});

/// 当前账本 id（优先取默认账本）。
final currentLedgerIdProvider = Provider<int?>((ref) {
  final ledgers = ref.watch(ledgersProvider).value;
  if (ledgers == null || ledgers.isEmpty) return null;
  return ledgers.firstWhere((l) => l.isDefault, orElse: () => ledgers.first).id;
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(ledgerRepositoryProvider).categoriesOf(TxKind.expense);
});

final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(ledgerRepositoryProvider).categoriesOf(TxKind.income);
});

/// 宠物养成状态。
final petStateProvider = StreamProvider<PetState>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchPet();
});

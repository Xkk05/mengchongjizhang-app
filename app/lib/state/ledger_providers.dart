import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../data/repositories/ledger_repository.dart';
import 'providers.dart';

/// 最近账目（自动跟随数据库变更刷新）。
final recentTransactionsProvider = StreamProvider<List<TxRecord>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchRecent();
});

/// 账目筛选条件（不可变）。
class TxFilter {
  const TxFilter({
    this.query = '',
    this.categoryIds = const {},
    this.accountIds = const {},
    this.kinds = const {},
  });

  final String query;
  final Set<int> categoryIds;
  final Set<int> accountIds;
  final Set<TxKind> kinds;

  bool get isActive =>
      query.trim().isNotEmpty ||
      categoryIds.isNotEmpty ||
      accountIds.isNotEmpty ||
      kinds.isNotEmpty;

  static const TxFilter empty = TxFilter();

  TxFilter copyWith({
    String? query,
    Set<int>? categoryIds,
    Set<int>? accountIds,
    Set<TxKind>? kinds,
  }) =>
      TxFilter(
        query: query ?? this.query,
        categoryIds: categoryIds ?? this.categoryIds,
        accountIds: accountIds ?? this.accountIds,
        kinds: kinds ?? this.kinds,
      );
}

class TxFilterNotifier extends Notifier<TxFilter> {
  @override
  TxFilter build() => TxFilter.empty;

  void setQuery(String q) => state = state.copyWith(query: q);

  void toggleKind(TxKind k) {
    final next = Set<TxKind>.from(state.kinds);
    next.contains(k) ? next.remove(k) : next.add(k);
    state = state.copyWith(kinds: next);
  }

  void toggleCategory(int id) {
    final next = Set<int>.from(state.categoryIds);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(categoryIds: next);
  }

  void toggleAccount(int id) {
    final next = Set<int>.from(state.accountIds);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(accountIds: next);
  }

  void clear() => state = TxFilter.empty;
}

final txFilterProvider =
    NotifierProvider<TxFilterNotifier, TxFilter>(TxFilterNotifier.new);

/// 带筛选条件的最近账目。
final filteredTransactionsProvider = StreamProvider<List<TxRecord>>((ref) {
  final f = ref.watch(txFilterProvider);
  return ref.watch(ledgerRepositoryProvider).watchRecent(
        query: f.query,
        categoryIds: f.categoryIds.isEmpty ? null : f.categoryIds,
        accountIds: f.accountIds.isEmpty ? null : f.accountIds,
        kinds: f.kinds.isEmpty ? null : f.kinds,
      );
});

/// 批量管理：当前被勾选的账目 id 集合（非空即处于多选模式）。
class TxSelectionNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggle(int id) {
    final next = Set<int>.from(state);
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void addAll(Iterable<int> ids) => state = {...state, ...ids};

  void clear() => state = const {};
}

final txSelectionProvider =
    NotifierProvider<TxSelectionNotifier, Set<int>>(TxSelectionNotifier.new);

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

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchCategories();
});

/// 宠物养成状态。
final petStateProvider = StreamProvider<PetState>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchPet();
});

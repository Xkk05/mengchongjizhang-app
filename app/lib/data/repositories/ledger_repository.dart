import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/assets/account_balance.dart';
import '../../domain/csv/ledger_csv.dart';
import '../../domain/rules/checkin_rules.dart';
import '../../domain/rules/pet_rules.dart';
import '../../domain/rules/store_rules.dart';
import '../db/database.dart';
import '../db/tables.dart';

/// 明细列表用的一行（账目 + 分类 + 账户的连表结果）。
class TxRecord {
  const TxRecord({
    required this.row,
    required this.categoryName,
    required this.categoryIconKey,
    required this.categoryColor,
    required this.accountName,
    this.toAccountName,
  });

  final TxRow row;
  final String categoryName;
  final String categoryIconKey;
  final int categoryColor;
  final String accountName;

  /// 转账的转入账户名；非转账为空。
  final String? toAccountName;

  bool get isExpense => row.kind == TxKind.expense;
  bool get isIncome => row.kind == TxKind.income;
  bool get isTransfer => row.kind == TxKind.transfer;
  int get amountCents => row.amountCents;
  DateTime get occurredAt => row.occurredAt;
  String get note => row.note;
}

/// 某个月的收支合计。
class MonthSummary {
  const MonthSummary({required this.incomeCents, required this.expenseCents});

  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;

  static const MonthSummary empty =
      MonthSummary(incomeCents: 0, expenseCents: 0);
}

/// 预算 + 其分类元信息（连表结果）。
class BudgetRow {
  const BudgetRow({
    required this.budget,
    required this.name,
    required this.iconKey,
    required this.colorValue,
  });

  final Budget budget;
  final String name;
  final String iconKey;
  final int colorValue;

  int get id => budget.id;
  int? get categoryId => budget.categoryId;
  int get limitCents => budget.limitCents;
  bool get isOverall => budget.categoryId == null;
}

/// 商店条目 = 商品 + 我的持有情况。
///
/// 背包与商店共用这一个结构：背包就是 `owned == true` 的子集。
class StoreEntry {
  const StoreEntry({
    required this.item,
    required this.inventoryId,
    required this.quantity,
    required this.equipped,
  });

  final StoreItem item;

  /// 未拥有时为 null。
  final int? inventoryId;
  final int quantity;
  final bool equipped;

  bool get owned => inventoryId != null && quantity > 0;
  bool get isFood => item.kind == ItemKind.food;
  bool get isDecor => item.kind == ItemKind.decor;
}

/// 一次签到的结果。
class CheckinOutcome {
  const CheckinOutcome({
    required this.ok,
    required this.streak,
    required this.coin,
    required this.bonusText,
  });

  final bool ok;

  /// 连续第几天（ok 为 false 时无意义）。
  final int streak;
  final int coin;

  /// 额外道具奖励文案，如「小鱼干 ×1」；无则为空串。
  final String bonusText;

  static const CheckinOutcome rejected =
      CheckinOutcome(ok: false, streak: 0, coin: 0, bonusText: '');
}

/// 导入前预览：先告诉用户「会发生什么」，而不是闷头写库。
class ImportPreview {
  const ImportPreview({
    required this.importable,
    required this.duplicates,
    required this.errors,
    required this.newExpenseCategories,
    required this.newIncomeCategories,
    required this.newAccounts,
  });

  /// 能导入的条数（已剔除与库内重复的）。
  final int importable;

  /// 因与库内已有记录重复而跳过的条数。
  final int duplicates;

  /// 文件里认不出来的行。
  final List<CsvRowError> errors;

  /// 导入时会自动新建的分类 / 账户名。
  final List<String> newExpenseCategories;
  final List<String> newIncomeCategories;
  final List<String> newAccounts;

  int get newCategoryCount =>
      newExpenseCategories.length + newIncomeCategories.length;

  bool get hasContent =>
      importable > 0 || duplicates > 0 || errors.isNotEmpty;
}

/// 导入执行结果。
class ImportOutcome {
  const ImportOutcome({
    required this.inserted,
    required this.duplicates,
    required this.newCategories,
    required this.newAccounts,
  });

  final int inserted;
  final int duplicates;
  final int newCategories;
  final int newAccounts;

  static const ImportOutcome empty = ImportOutcome(
    inserted: 0,
    duplicates: 0,
    newCategories: 0,
    newAccounts: 0,
  );
}

/// 导入计划（内部结构）—— 预览与执行共用同一份计算，保证「看到的 == 导入的」。
class _ImportPlan {
  _ImportPlan({
    required this.fresh,
    required this.duplicates,
    required this.errors,
    required this.catId,
    required this.accId,
    required this.newExpenseCategories,
    required this.newIncomeCategories,
    required this.newAccounts,
  });

  final List<CsvLedgerRow> fresh;
  final int duplicates;
  final List<CsvRowError> errors;

  /// `'分类kind索引|名称'` -> id；值为 `-1` 表示待创建。
  final Map<String, int> catId;

  /// 账户名 -> id；值为 `-1` 表示待创建。
  final Map<String, int> accId;

  final List<String> newExpenseCategories;
  final List<String> newIncomeCategories;
  final List<String> newAccounts;
}

class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  // ------------------------------------------------------------------ 读取

  /// 最近的账目，按时间倒序；支持关键词 / 分类 / 账户 / 类型筛选。
  Stream<List<TxRecord>> watchRecent({
    int limit = 300,
    String query = '',
    Set<int>? categoryIds,
    Set<int>? accountIds,
    Set<TxKind>? kinds,
  }) {
    final toAccount = _db.accounts.createAlias('toAccount');
    final q = _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(toAccount, toAccount.id.equalsExp(_db.transactions.toAccountId)),
    ]);

    final kw = query.trim();
    if (kw.isNotEmpty) {
      final like = '%$kw%';
      q.where(_db.transactions.note.like(like) |
          _db.categories.name.like(like) |
          _db.accounts.name.like(like));
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      q.where(_db.transactions.categoryId.isIn(categoryIds));
    }
    if (accountIds != null && accountIds.isNotEmpty) {
      // 转账的转入账户也计入筛选，避免「转进某账户」被漏掉。
      q.where(_db.transactions.accountId.isIn(accountIds) |
          _db.transactions.toAccountId.isIn(accountIds));
    }
    if (kinds != null && kinds.isNotEmpty) {
      q.where(
          _db.transactions.kind.isIn(kinds.map((k) => k.index).toList()));
    }

    q
      ..orderBy([
        OrderingTerm.desc(_db.transactions.occurredAt),
        OrderingTerm.desc(_db.transactions.id),
      ])
      ..limit(limit);

    return q.watch().map((rows) => _mapJoined(rows, toAccount));
  }

  /// 指定时间区间内的账目（左闭右开）。
  ///
  /// 统计场景按月取数后在内存聚合 —— 个人记账的数据量下足够快，也省去
  /// SQL 侧按「天」分组的方言差异。
  Stream<List<TxRecord>> watchRange(DateTime start, DateTime end) {
    final toAccount = _db.accounts.createAlias('toAccount');
    final q = _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(toAccount, toAccount.id.equalsExp(_db.transactions.toAccountId)),
    ])
      ..where(_db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          _db.transactions.occurredAt.isSmallerThanValue(end))
      ..orderBy([
        OrderingTerm.desc(_db.transactions.occurredAt),
        OrderingTerm.desc(_db.transactions.id),
      ]);

    return q.watch().map((rows) => _mapJoined(rows, toAccount));
  }

  List<TxRecord> _mapJoined(List<TypedResult> rows, TableInfo toAccount) => rows
      .map((r) {
        final cat = r.readTable(_db.categories);
        final target = r.readTableOrNull(toAccount);
        return TxRecord(
          row: r.readTable(_db.transactions),
          categoryName: cat.name,
          categoryIconKey: cat.iconKey,
          categoryColor: cat.colorValue,
          accountName: r.readTable(_db.accounts).name,
          toAccountName: target?.name,
        );
      })
      .toList(growable: false);

  Stream<MonthSummary> watchMonthSummary(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final q = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.kind,
        _db.transactions.amountCents.sum(),
      ])
      ..where(_db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          _db.transactions.occurredAt.isSmallerThanValue(end))
      ..groupBy([_db.transactions.kind]);

    return q.watch().map((rows) {
      var income = 0;
      var expense = 0;
      for (final r in rows) {
        // 聚合查询里读到的是原始 int，不是枚举，需按 index 比较。
        final kindCode = r.read(_db.transactions.kind);
        final sum = r.read(_db.transactions.amountCents.sum()) ?? 0;
        if (kindCode == TxKind.income.index) {
          income = sum;
        } else if (kindCode == TxKind.expense.index) {
          expense = sum;
        }
      }
      return MonthSummary(incomeCents: income, expenseCents: expense);
    });
  }

  Stream<PetState> watchPet() =>
      (_db.select(_db.petStates)..where((t) => t.id.equals(1)))
          .watchSingle();

  Stream<List<Account>> watchAccounts() => (_db.select(_db.accounts)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  /// 账户 + 其流水净额 → 实时余额。
  ///
  /// 转账是「转出账户 -金额、转入账户 +金额」，单靠一条
  /// `账户 LEFT JOIN 流水(accountId)` 算不到转入侧，这里改成分别监听
  /// 账户与流水两个流，在内存里归并——个人记账的数据量下完全够用，
  /// 也天然支持转账双向、且不影响收入/支出统计。
  Stream<List<AccountBalance>> watchAccountsWithBalance() {
    return _latest2(
      (_db.select(_db.accounts)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch(),
      _db.select(_db.transactions).watch(),
    ).map((r) => _computeBalances(r.$1, r.$2));
  }

  List<AccountBalance> _computeBalances(
      List<Account> accounts, List<TxRow> txs) {
    final flow = <int, int>{};
    final count = <int, int>{};

    for (final tx in txs) {
      if (tx.kind == TxKind.transfer) {
        // 转出侧：余额减少；转入侧：余额增加。整笔只计入转出账户的笔数。
        flow[tx.accountId] = (flow[tx.accountId] ?? 0) - tx.amountCents;
        count[tx.accountId] = (count[tx.accountId] ?? 0) + 1;
        final to = tx.toAccountId;
        if (to != null) {
          flow[to] = (flow[to] ?? 0) + tx.amountCents;
        }
      } else {
        final signed = tx.kind == TxKind.income ? tx.amountCents : -tx.amountCents;
        flow[tx.accountId] = (flow[tx.accountId] ?? 0) + signed;
        count[tx.accountId] = (count[tx.accountId] ?? 0) + 1;
      }
    }

    return accounts
        .map((a) => AccountBalance(
              id: a.id,
              name: a.name,
              iconKey: a.iconKey,
              colorValue: a.colorValue,
              initialCents: a.initialBalanceCents,
              flowCents: flow[a.id] ?? 0,
              txCount: count[a.id] ?? 0,
              includedInNetWorth: a.includedInNetWorth,
            ))
        .toList(growable: false);
  }

  /// 两个流的「最新值合并」：任一流有新值就重算。
  ///
  /// 项目未引入 rxdart，这里用最小实现避免额外依赖。
  static Stream<(A, B)> _latest2<A, B>(Stream<A> a, Stream<B> b) {
    late final StreamController<(A, B)> controller;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    A? lastA;
    B? lastB;
    var hasA = false;
    var hasB = false;

    void emit() {
      if (hasA && hasB) controller.add((lastA as A, lastB as B));
    }

    controller = StreamController<(A, B)>(
      onListen: () {
        subA = a.listen((v) {
          lastA = v;
          hasA = true;
          emit();
        });
        subB = b.listen((v) {
          lastB = v;
          hasB = true;
          emit();
        });
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }

  /// 某个月的预算（含分类元信息），总预算排在最前。
  Stream<List<BudgetRow>> watchBudgets(int yearMonth) {
    final q = _db.select(_db.budgets).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ])
      ..where(_db.budgets.yearMonth.equals(yearMonth));

    return q.watch().map((rows) {
      final list = rows.map((r) {
        final b = r.readTable(_db.budgets);
        final cat = r.readTableOrNull(_db.categories);
        return BudgetRow(
          budget: b,
          name: cat?.name ?? '总预算',
          iconKey: cat?.iconKey ?? 'budget',
          colorValue: cat?.colorValue ?? 0xFF2E9E77,
        );
      }).toList();

      list.sort((a, b) {
        if (a.isOverall != b.isOverall) return a.isOverall ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Stream<List<Ledger>> watchLedgers() => _db.select(_db.ledgers).watch();

  /// 商店目录 + 我的持有情况。
  ///
  /// 商品与背包条目是一对一（重复购买只加数量），因此可以直接 LEFT JOIN。
  /// [kind] 为空时返回全部商品。
  Stream<List<StoreEntry>> watchStore({ItemKind? kind}) {
    final q = _db.select(_db.storeItems).join([
      leftOuterJoin(
        _db.inventories,
        _db.inventories.itemId.equalsExp(_db.storeItems.id),
      ),
    ])
      ..orderBy([OrderingTerm.asc(_db.storeItems.sortOrder)]);

    if (kind != null) {
      q.where(_db.storeItems.kind.equalsValue(kind));
    }

    return q.watch().map(
          (rows) => rows.map((r) {
            final item = r.readTable(_db.storeItems);
            final inv = r.readTableOrNull(_db.inventories);
            return StoreEntry(
              item: item,
              inventoryId: inv?.id,
              quantity: inv?.quantity ?? 0,
              equipped: inv?.equipped ?? false,
            );
          }).toList(growable: false),
        );
  }

  /// 最近一次签到（从没签过则为 null）。
  Stream<Checkin?> watchLatestCheckin() => (_db.select(_db.checkins)
        ..orderBy([(t) => OrderingTerm.desc(t.day)])
        ..limit(1))
      .watchSingleOrNull();

  /// 最近的签到记录，按日期倒序。
  Stream<List<Checkin>> watchCheckins({int limit = 14}) =>
      (_db.select(_db.checkins)
            ..orderBy([(t) => OrderingTerm.desc(t.day)])
            ..limit(limit))
          .watch();

  Future<List<Category>> categoriesOf(TxKind kind) => (_db.select(_db.categories)
        ..where((t) => t.kind.equalsValue(kind))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();

  /// 全部分类（按类型、排序），分类管理页用。
  Stream<List<Category>> watchCategories() => (_db.select(_db.categories)
        ..orderBy([
          (t) => OrderingTerm.asc(t.kind),
          (t) => OrderingTerm.asc(t.sortOrder),
        ]))
      .watch();

  // ------------------------------------------------------------------ 写入

  /// 记一笔账：写流水 + 结算宠物奖励，同一事务内完成。
  Future<int> addTransaction({
    required int ledgerId,
    required int accountId,
    required int categoryId,
    required TxKind kind,
    required int amountCents,
    required DateTime occurredAt,
    String note = '',
    int? toAccountId,
  }) {
    assert(amountCents > 0, '金额必须为正数（分）');
    assert(kind != TxKind.transfer || (toAccountId != null && toAccountId != accountId),
        '转账必须指定转入账户且不同于转出账户');

    return _db.transaction(() async {
      final id = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              accountId: accountId,
              categoryId: categoryId,
              kind: kind,
              amountCents: amountCents,
              occurredAt: occurredAt,
              note: Value(note.trim()),
              toAccountId: Value(toAccountId),
            ),
          );

      final pet = await _pet();
      final delta = PetRules.onRecord(level: pet.level, exp: pet.exp);

      await _writePet(
        PetStatesCompanion(
          level: Value(delta.level),
          exp: Value(delta.exp),
          coin: Value(pet.coin + delta.coinGained),
          totalRecorded: Value(pet.totalRecorded + 1),
        ),
      );

      return id;
    });
  }

  Future<void> deleteTransaction(int id) =>
      (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  /// 批量删除账目（多选清理用）。
  Future<void> deleteTransactions(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (_db.delete(_db.transactions)..where((t) => t.id.isIn(ids))).go();
  }

  /// 修改一笔账（不重复结算宠物奖励）。
  Future<void> updateTransaction({
    required int id,
    required int accountId,
    required int categoryId,
    required TxKind kind,
    required int amountCents,
    required DateTime occurredAt,
    String note = '',
    int? toAccountId,
  }) {
    assert(amountCents > 0, '金额必须为正数（分）');
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        kind: Value(kind),
        amountCents: Value(amountCents),
        occurredAt: Value(occurredAt),
        note: Value(note.trim()),
        toAccountId: Value(toAccountId),
      ),
    );
  }

  /// 喂食：扣金币，涨经验与饱食度。
  Future<bool> feedPet({int cost = 20, int hungerGain = 15}) {
    return _db.transaction(() async {
      final pet = await _pet();
      if (pet.coin < cost) return false;

      final delta = PetRules.onFeed(level: pet.level, exp: pet.exp, cost: cost);
      await _writePet(
        PetStatesCompanion(
          level: Value(delta.level),
          exp: Value(delta.exp),
          coin: Value(pet.coin + delta.coinGained),
          hunger: Value((pet.hunger + hungerGain).clamp(0, PetRules.maxHunger)),
          mood: Value((pet.mood + 4).clamp(0, PetRules.maxMood)),
          lastFedAt: Value(DateTime.now()),
        ),
      );
      return true;
    });
  }

  // ------------------------------------------------------------ 分类增删改

  /// 新增分类，排在该类型末尾。
  Future<int> addCategory({
    required TxKind kind,
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final maxOrder = await (_db.selectOnly(_db.categories)
          ..addColumns([_db.categories.sortOrder.max()])
          ..where(_db.categories.kind.equalsValue(kind)))
        .getSingleOrNull();
    final nextOrder =
        (maxOrder?.read(_db.categories.sortOrder.max()) ?? -1) + 1;

    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name.trim(),
            kind: kind,
            iconKey: iconKey,
            colorValue: colorValue,
            sortOrder: Value(nextOrder),
          ),
        );
  }

  /// 改分类的名称 / 图标 / 颜色（内置分类也允许改，只是不让删）。
  Future<void> updateCategory({
    required int id,
    required String name,
    required String iconKey,
    required int colorValue,
  }) =>
      (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name.trim()),
          iconKey: Value(iconKey),
          colorValue: Value(colorValue),
        ),
      );

  /// 删除分类：内置分类、或已有账目的分类不允许删，返回失败原因；成功返回 null。
  Future<String?> deleteCategory(int id) async {
    final cat = await (_db.select(_db.categories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (cat == null) return '分类不存在';
    if (cat.isBuiltIn) return '系统预置分类不可删除';

    final countRow = await (_db.selectOnly(_db.transactions)
          ..addColumns([countAll()])
          ..where(_db.transactions.categoryId.equals(id)))
        .getSingle();
    final used = countRow.read(countAll()) ?? 0;
    if (used > 0) return '该分类下有 $used 笔账目，无法删除';

    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
    return null;
  }

  // ------------------------------------------------------------ 账户增删改

  /// 新增账户，排在最后。
  Future<int> addAccount({
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalanceCents,
  }) async {
    final maxOrder = await (_db.selectOnly(_db.accounts)
          ..addColumns([_db.accounts.sortOrder.max()]))
        .getSingleOrNull();
    final nextOrder =
        (maxOrder?.read(_db.accounts.sortOrder.max()) ?? -1) + 1;

    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            name: name.trim(),
            iconKey: Value(iconKey),
            colorValue: Value(colorValue),
            initialBalanceCents: Value(initialBalanceCents),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalanceCents,
  }) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
        AccountsCompanion(
          name: Value(name.trim()),
          iconKey: Value(iconKey),
          colorValue: Value(colorValue),
          initialBalanceCents: Value(initialBalanceCents),
        ),
      );

  /// 删除账户 —— 外键级联，该账户下的账目会一并删除（UI 侧须明确告知）。
  Future<void> deleteAccount(int id) =>
      (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();

  // ------------------------------------------------------------ 预算读写

  /// 幂等地设置「月份 + 分类」的预算：有则改金额，无则新增。
  ///
  /// [categoryId] 为空表示总预算。
  Future<void> setBudget({
    required int yearMonth,
    int? categoryId,
    required int limitCents,
  }) {
    assert(limitCents > 0, '预算金额必须为正数（分）');

    return _db.transaction(() async {
      final query = _db.select(_db.budgets)
        ..where(
          (t) =>
              t.yearMonth.equals(yearMonth) &
              (categoryId == null
                  ? t.categoryId.isNull()
                  : t.categoryId.equals(categoryId)),
        );
      final existing = await query.getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                yearMonth: yearMonth,
                categoryId: Value(categoryId),
                limitCents: limitCents,
              ),
            );
      } else {
        await (_db.update(_db.budgets)..where((t) => t.id.equals(existing.id)))
            .write(BudgetsCompanion(limitCents: Value(limitCents)));
      }
    });
  }

  Future<void> deleteBudget(int id) =>
      (_db.delete(_db.budgets)..where((t) => t.id.equals(id))).go();

  // ------------------------------------------------------------ 商店 / 背包

  /// 购买商品：校验金币 → 扣币 → 入背包（已有则加数量），同一事务。
  Future<PurchaseResult> buyItem(int itemId) {
    return _db.transaction(() async {
      final item = await (_db.select(_db.storeItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingle();
      final pet = await _pet();

      final check = StoreRules.canBuy(coin: pet.coin, priceCoin: item.priceCoin);
      if (!check.ok) return check;

      final existing = await (_db.select(_db.inventories)
            ..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.inventories)
            .insert(InventoriesCompanion.insert(itemId: itemId));
      } else {
        await (_db.update(_db.inventories)
              ..where((t) => t.id.equals(existing.id)))
            .write(InventoriesCompanion(quantity: Value(existing.quantity + 1)));
      }

      await _writePet(PetStatesCompanion(coin: Value(pet.coin - item.priceCoin)));
      return const PurchaseResult.ok();
    });
  }

  /// 使用背包里的道具。
  ///
  /// - `food`：扣 1 个，结算饱食 / 经验 / 心情；
  /// - `decor`：装备它，**同一佩戴位**同时只留一件使用中（不消耗）。
  ///   头饰 / 颈部 / 场景三个位置互不冲突，可以同时生效。
  Future<PurchaseResult> useItem(int itemId) {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.inventories)
            ..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();
      if (existing == null) return StoreRules.canUse(quantity: 0);

      final item = await (_db.select(_db.storeItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingle();

      if (item.kind == ItemKind.decor) {
        await _equip(itemId, item.decorSlot);
        return const PurchaseResult.ok();
      }

      final pet = await _pet();
      final result = PetRules.onUseFood(
        level: pet.level,
        exp: pet.exp,
        hunger: pet.hunger,
        mood: pet.mood,
        expGain: item.expGain,
        hungerGain: item.hungerGain,
        moodGain: item.moodGain,
      );
      await _writePet(PetStatesCompanion(
        level: Value(result.level),
        exp: Value(result.exp),
        hunger: Value(result.hunger),
        mood: Value(result.mood),
      ));

      if (existing.quantity <= 1) {
        await (_db.delete(_db.inventories)
              ..where((t) => t.id.equals(existing.id)))
            .go();
      } else {
        await (_db.update(_db.inventories)
              ..where((t) => t.id.equals(existing.id)))
            .write(InventoriesCompanion(quantity: Value(existing.quantity - 1)));
      }
      return const PurchaseResult.ok();
    });
  }

  /// 装备 [itemId]，并卸下同佩戴位的其他装扮。
  ///
  /// [slot] 为空（历史脏数据 / 非装扮商品）时退化成「只处置这一件」，
  /// 不做全表卸载 —— 免得一条坏数据把用户所有装扮都脱掉。
  Future<void> _equip(int itemId, DecorSlot? slot) async {
    if (slot == null) {
      await (_db.update(_db.inventories)..where((t) => t.itemId.equals(itemId)))
          .write(const InventoriesCompanion(equipped: Value(true)));
      return;
    }

    final rows = await (_db.select(_db.inventories).join([
      innerJoin(
        _db.storeItems,
        _db.storeItems.id.equalsExp(_db.inventories.itemId),
      ),
    ])
          ..where(_db.storeItems.decorSlot.equalsValue(slot)))
        .get();

    for (final row in rows) {
      final entry = row.readTable(_db.inventories);
      final target = row.readTable(_db.storeItems).id == itemId;
      await (_db.update(_db.inventories)..where((t) => t.id.equals(entry.id)))
          .write(InventoriesCompanion(equipped: Value(target)));
    }
  }

  /// 卸下某件装扮（同位置其他件不受影响）。
  Future<void> unequip(int itemId) =>
      (_db.update(_db.inventories)..where((t) => t.itemId.equals(itemId)))
          .write(const InventoriesCompanion(equipped: Value(false)));

  // ------------------------------------------------------------ 签到

  /// 签到：写记录 + 发金币 + 发额外道具 + 涨心情，同一事务。
  Future<CheckinOutcome> checkIn(DateTime today) {
    return _db.transaction(() async {
      final t = CheckinRules.dayOf(today);
      final latest = await (_db.select(_db.checkins)
            ..orderBy([(c) => OrderingTerm.desc(c.day)])
            ..limit(1))
          .getSingleOrNull();

      if (!CheckinRules.canCheckIn(lastDay: latest?.day, today: t)) {
        return CheckinOutcome.rejected;
      }

      final streak = CheckinRules.nextStreak(
        lastStreak: latest?.streak ?? 0,
        lastDay: latest?.day,
        today: t,
      );
      final reward = CheckinRules.rewardFor(streak);

      var bonusText = '';
      if (reward.hasBonus) {
        final item = await (_db.select(_db.storeItems)
              ..where((s) => s.code.equals(reward.bonusItemCode!)))
            .getSingleOrNull();
        if (item != null) {
          final existing = await (_db.select(_db.inventories)
                ..where((i) => i.itemId.equals(item.id)))
              .getSingleOrNull();
          if (existing == null) {
            await _db.into(_db.inventories).insert(
                  InventoriesCompanion.insert(
                    itemId: item.id,
                    quantity: Value(reward.bonusCount),
                  ),
                );
          } else {
            await (_db.update(_db.inventories)
                  ..where((i) => i.id.equals(existing.id)))
                .write(InventoriesCompanion(
              quantity: Value(existing.quantity + reward.bonusCount),
            ));
          }
          bonusText = '${item.name} ×${reward.bonusCount}';
        }
      }

      await _db.into(_db.checkins).insert(
            CheckinsCompanion.insert(
              day: t,
              streak: streak,
              coinGained: reward.coin,
              bonusText: Value(bonusText),
            ),
          );

      final pet = await _pet();
      await _writePet(PetStatesCompanion(
        coin: Value(pet.coin + reward.coin),
        mood: Value((pet.mood + 3).clamp(0, PetRules.maxMood)),
      ));

      return CheckinOutcome(
        ok: true,
        streak: streak,
        coin: reward.coin,
        bonusText: bonusText,
      );
    });
  }

  // ------------------------------------------------------------ 账单导入导出

  /// 空分类 / 空账户的兜底名（导入时字段缺失也不丢账）。
  static const String _fallbackExpenseCategory = '其他';
  static const String _fallbackIncomeCategory = '其他收入';
  static const String _fallbackAccount = '现金';

  static const int _newCategoryColor = 0xFF7A8B84;
  static const int _newAccountColor = 0xFF2E9E77;

  /// 全量流水，供导出使用（按时间正序）。
  Future<List<CsvLedgerRow>> exportRows() async {
    final records = await _exportRecords();
    return records
        .map((t) => (
              at: t.row.occurredAt,
              isExpense: t.row.kind == TxKind.expense,
              isTransfer: t.row.kind == TxKind.transfer,
              categoryName: t.categoryName,
              accountName: t.accountName,
              toAccountName: t.toAccountName ?? '',
              amountCents: t.row.amountCents,
              note: t.note,
            ))
        .toList(growable: false);
  }

  /// 预演导入：算出「可导入 / 重复跳过 / 异常行 / 将新建的分类账户」。
  ///
  /// 与 [importRows] 共用 [_buildPlan]，因此预览数字与实际导入结果一致。
  Future<ImportPreview> previewImport(CsvParseResult parsed) async {
    final plan = await _buildPlan(parsed);
    return ImportPreview(
      importable: plan.fresh.length,
      duplicates: plan.duplicates,
      errors: plan.errors,
      newExpenseCategories: plan.newExpenseCategories,
      newIncomeCategories: plan.newIncomeCategories,
      newAccounts: plan.newAccounts,
    );
  }

  /// 执行导入（单事务）。
  ///
  /// 两点约定：
  /// - **不发养成奖励**：导入的是历史账单，若按「每笔 +经验 +金币」结算，
  ///   一次导入几百条就会把宠物刷满级，失去养成意义。
  /// - **缺分类 / 缺账户自动建档**：第三方账单里出现本 App 没有的分类是常态，
  ///   自动建一个（灰色 `more` 图标）比整行丢弃更符合预期，且预览里会先告知。
  Future<ImportOutcome> importRows(CsvParseResult parsed) {
    return _db.transaction(() async {
      final plan = await _buildPlan(parsed);
      if (plan.fresh.isEmpty) {
        return ImportOutcome(
          inserted: 0,
          duplicates: plan.duplicates,
          newCategories: 0,
          newAccounts: 0,
        );
      }

      final ledgerId = await defaultLedgerId();

      // 1) 补齐缺失的分类
      for (final name in plan.newExpenseCategories) {
        final id = await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                name: name,
                kind: TxKind.expense,
                iconKey: 'more',
                colorValue: _newCategoryColor,
                sortOrder: const Value(900),
              ),
            );
        plan.catId['${TxKind.expense.index}|$name'] = id;
      }
      for (final name in plan.newIncomeCategories) {
        final id = await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                name: name,
                kind: TxKind.income,
                iconKey: 'more',
                colorValue: _newCategoryColor,
                sortOrder: const Value(900),
              ),
            );
        plan.catId['${TxKind.income.index}|$name'] = id;
      }

      // 2) 补齐缺失的账户
      for (final name in plan.newAccounts) {
        final id = await _db.into(_db.accounts).insert(
              AccountsCompanion.insert(
                name: name,
                type: const Value('cash'),
                iconKey: const Value('wallet'),
                colorValue: const Value(_newAccountColor),
                sortOrder: const Value(900),
              ),
            );
        plan.accId[name] = id;
      }

      // 3) 批量写流水
      final toInsert = <TransactionsCompanion>[];
      int? transferCatId;
      for (final r in plan.fresh) {
        final TxKind kind;
        int? categoryId;
        int? toAccountId;
        if (r.isTransfer) {
          kind = TxKind.transfer;
          transferCatId ??= await transferCategoryId();
          categoryId = transferCatId;
          final toName = r.toAccountName.trim();
          toAccountId = toName.isEmpty ? null : plan.accId[toName];
        } else {
          kind = r.isExpense ? TxKind.expense : TxKind.income;
          categoryId = plan.catId['${kind.index}|${_categoryNameOf(r)}'];
        }
        final accountId = plan.accId[_accountNameOf(r)];
        if (categoryId == null || accountId == null) continue; // 兜底，正常不触发
        // 转账缺少有效转入账户时跳过（解析层已兜底，此处再保险一次）。
        if (kind == TxKind.transfer &&
            (toAccountId == null || toAccountId == accountId)) {
          continue;
        }
        toInsert.add(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            accountId: accountId,
            categoryId: categoryId,
            kind: kind,
            amountCents: r.amountCents,
            occurredAt: r.at,
            note: Value(r.note),
            toAccountId: Value(toAccountId),
          ),
        );
      }
      if (toInsert.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.transactions, toInsert));
      }

      return ImportOutcome(
        inserted: toInsert.length,
        duplicates: plan.duplicates,
        newCategories: plan.newExpenseCategories.length +
            plan.newIncomeCategories.length,
        newAccounts: plan.newAccounts.length,
      );
    });
  }

  Future<List<TxRecord>> _exportRecords() {
    final toAccount = _db.accounts.createAlias('toAccount');
    final q = _db.select(_db.transactions).join([
      innerJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(
          _db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(
          toAccount, toAccount.id.equalsExp(_db.transactions.toAccountId)),
    ])
      ..orderBy([
        OrderingTerm.asc(_db.transactions.occurredAt),
        OrderingTerm.asc(_db.transactions.id),
      ]);
    return q.get().then((rows) => _mapJoined(rows, toAccount));
  }

  /// 计算导入计划：解析现有分类 / 账户 → 按指纹计数去重 → 收集待建分类账户。
  Future<_ImportPlan> _buildPlan(CsvParseResult parsed) async {
    final cats = await _db.select(_db.categories).get();
    final accs = await _db.select(_db.accounts).get();

    final catId = <String, int>{
      for (final c in cats) '${c.kind.index}|${c.name}': c.id,
    };
    final accId = <String, int>{for (final a in accs) a.name: a.id};

    // 库内已有记录的指纹计数 —— 与导入行一一抵消，重复导入同一文件会全部跳过，
    // 而真实的「同分钟多笔」不会被误伤。
    final counts = <String, int>{};
    for (final t in await _exportRecords()) {
      final fp = LedgerCsv.fingerprintOf(
        at: t.row.occurredAt,
        isExpense: t.row.kind == TxKind.expense,
        isTransfer: t.row.kind == TxKind.transfer,
        amountCents: t.row.amountCents,
        categoryName: t.categoryName,
        accountName: t.accountName,
        toAccountName: t.toAccountName ?? '',
        note: t.note,
      );
      counts[fp] = (counts[fp] ?? 0) + 1;
    }

    final fresh = <CsvLedgerRow>[];
    final newExpenseCategories = <String>[];
    final newIncomeCategories = <String>[];
    final newAccounts = <String>[];
    var duplicates = 0;

    for (final r in parsed.rows) {
      final fp = LedgerCsv.fingerprint(r);
      final left = counts[fp] ?? 0;
      if (left > 0) {
        counts[fp] = left - 1;
        duplicates++;
        continue;
      }
      fresh.add(r);

      // 转账不建分类（走内置「转账」占位分类），也不进收/支新建分类列表。
      if (!r.isTransfer) {
        final kind = r.isExpense ? TxKind.expense : TxKind.income;
        final catKey = '${kind.index}|${_categoryNameOf(r)}';
        if (catId[catKey] == null) {
          catId[catKey] = -1; // 占位：待创建
          (r.isExpense ? newExpenseCategories : newIncomeCategories)
              .add(_categoryNameOf(r));
        }
      }
      final accName = _accountNameOf(r);
      if (accId[accName] == null) {
        accId[accName] = -1;
        newAccounts.add(accName);
      }
      // 转账的转入账户也要确保存在，导入时才能解析到账户 id。
      if (r.isTransfer && r.toAccountName.trim().isNotEmpty) {
        final toName = r.toAccountName.trim();
        if (accId[toName] == null) {
          accId[toName] = -1;
          newAccounts.add(toName);
        }
      }
    }

    return _ImportPlan(
      fresh: fresh,
      duplicates: duplicates,
      errors: parsed.errors,
      catId: catId,
      accId: accId,
      newExpenseCategories: newExpenseCategories,
      newIncomeCategories: newIncomeCategories,
      newAccounts: newAccounts,
    );
  }

  static String _categoryNameOf(CsvLedgerRow r) => r.categoryName.isEmpty
      ? (r.isExpense ? _fallbackExpenseCategory : _fallbackIncomeCategory)
      : r.categoryName;

  static String _accountNameOf(CsvLedgerRow r) =>
      r.accountName.isEmpty ? _fallbackAccount : r.accountName;

  /// 当前默认账本 id；库里一条账本都没有时自动补建「日常账本」。
  ///
  /// 直接查库而不是读 UI 侧的账本流，避免「流还没吐第一条数据就保存」
  /// 导致拿到 null（真机表现为点保存报「账本尚未初始化完成」）。
  Future<int> defaultLedgerId() async {
    final row = await (_db.select(_db.ledgers)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row != null) return row.id;
    return _db.into(_db.ledgers).insert(
          LedgersCompanion.insert(
            name: '日常账本',
            isDefault: const Value(true),
          ),
        );
  }

  /// 内置「转账」分类 id（转账流水用它作占位分类；缺失时兜底补建）。
  Future<int> transferCategoryId() async {
    final row = await (_db.select(_db.categories)
          ..where((t) => t.kind.equalsValue(TxKind.transfer)))
        .getSingleOrNull();
    if (row != null) return row.id;
    return _db.into(_db.categories).insert(
          CategoriesCompanion(
            name: const Value('转账'),
            kind: const Value(TxKind.transfer),
            iconKey: const Value('transfer'),
            colorValue: const Value(0xFF7A8B84),
            sortOrder: const Value(0),
            isBuiltIn: const Value(true),
          ),
        );
  }

  // ------------------------------------------------------------ 内部工具

  Future<PetState> _pet() =>
      (_db.select(_db.petStates)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _writePet(PetStatesCompanion patch) =>
      (_db.update(_db.petStates)..where((t) => t.id.equals(1))).write(patch);
}

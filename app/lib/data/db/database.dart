import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Ledgers,
    Accounts,
    Categories,
    Transactions,
    PetStates,
    Budgets,
    StoreItems,
    Inventories,
    Checkins,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// 真机/桌面走原生 sqlite；Web 需要额外提供 wasm 资源，本项目只交付 App。
  static QueryExecutor _open() => driftDatabase(name: 'suixin_pet_ledger');

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 的 accounts.balance_cents 语义是「当前余额」，v2 改为「初始余额」
            // 并新增 budgets 表。旧数据保留为初始余额，历史流水重新参与派生。
            await m.renameColumn(
              accounts,
              'balance_cents',
              accounts.initialBalanceCents,
            );
            await m.createTable(budgets);
          }
          if (from < 3) {
            // v3 新增养成闭环：商品目录 / 背包 / 签到记录。
            await m.createTable(storeItems);
            await m.createTable(inventories);
            await m.createTable(checkins);
            await _seedStoreItems();
          }
          if (from < 4) {
            // v4 给商品加「佩戴位」，让装扮能同时戴多件（头饰 / 颈部 / 场景）。
            // 老装机已有商品行，加完列必须按 code 回填，否则装扮全都无法装备。
            await m.addColumn(storeItems, storeItems.decorSlot);
            await _backfillDecorSlots();
          }
        },
      );

  // ---------------------------------------------------------------- 种子数据

  Future<void> _seed() async {
    final ledgerId = await into(ledgers).insert(
      LedgersCompanion.insert(
        name: '日常账本',
        iconKey: const Value('wallet'),
        isDefault: const Value(true),
      ),
    );

    final accountIds = <String, int>{};
    for (final a in _seedAccounts) {
      accountIds[a.$1] = await into(accounts).insert(a.$2);
    }

    final categoryIds = <String, int>{};
    for (final c in [..._expenseCategories, ..._incomeCategories]) {
      categoryIds[c.name.value] = await into(categories).insert(c);
    }

    await into(petStates).insert(
      const PetStatesCompanion(id: Value(1), coin: Value(welcomeCoin)),
    );

    await _seedStoreItems();

    // 演示种子数据：首次安装即有内容可看，便于比对设计稿。
    // 正式发版前删除该段即可（不影响表结构与逻辑）。
    if (_seedSample) {
      await _seedTransactions(
        ledgerId: ledgerId,
        accountIds: accountIds,
        categoryIds: categoryIds,
      );
      await _seedBudgets(categoryIds: categoryIds);
    }
  }

  // 演示种子数据开关：false = 全新安装不再预置演示流水与预算（结构数据照常）。
  static const bool _seedSample = false;

  /// 新手礼包：初次建档送一点金币，否则新用户要记几十笔才买得起东西。
  static const int welcomeCoin = 60;

  /// 商品目录是结构性的，任何情况下都要播（与 `_seedSample` 无关）。
  ///
  /// `code` 被签到奖励引用，因此这些字符串是**稳定契约**，不要随意改。
  Future<void> _seedStoreItems() async {
    await batch((b) => b.insertAll(storeItems, _catalog));
  }

  static const List<StoreItemsCompanion> _catalog = [
    StoreItemsCompanion(
        code: Value('food_fish'),
        name: Value('小鱼干'),
        kind: Value(ItemKind.food),
        iconKey: Value('fish'),
        priceCoin: Value(10),
        description: Value('团团最爱，一口一条'),
        hungerGain: Value(8),
        expGain: Value(6),
        moodGain: Value(2),
        sortOrder: Value(0)),
    StoreItemsCompanion(
        code: Value('food_can'),
        name: Value('营养罐头'),
        kind: Value(ItemKind.food),
        iconKey: Value('can'),
        priceCoin: Value(25),
        description: Value('扎实管饱，吃完成长快'),
        hungerGain: Value(18),
        expGain: Value(16),
        moodGain: Value(5),
        sortOrder: Value(1)),
    StoreItemsCompanion(
        code: Value('food_cookie'),
        name: Value('手工饼干'),
        kind: Value(ItemKind.food),
        iconKey: Value('cookie'),
        priceCoin: Value(40),
        description: Value('限量烘焙，心情大好'),
        hungerGain: Value(30),
        expGain: Value(28),
        moodGain: Value(10),
        sortOrder: Value(2)),
    StoreItemsCompanion(
        code: Value('decor_ribbon'),
        name: Value('红蝴蝶结'),
        kind: Value(ItemKind.decor),
        iconKey: Value('ribbon'),
        priceCoin: Value(60),
        description: Value('戴上就有过节的心情'),
        decorSlot: Value(DecorSlot.head),
        sortOrder: Value(3)),
    StoreItemsCompanion(
        code: Value('decor_bell'),
        name: Value('金铃铛'),
        kind: Value(ItemKind.decor),
        iconKey: Value('bell'),
        priceCoin: Value(90),
        description: Value('走起路来叮当响'),
        decorSlot: Value(DecorSlot.neck),
        sortOrder: Value(4)),
    StoreItemsCompanion(
        code: Value('decor_crown'),
        name: Value('小王冠'),
        kind: Value(ItemKind.decor),
        iconKey: Value('crown'),
        priceCoin: Value(150),
        description: Value('今天团团的排面'),
        decorSlot: Value(DecorSlot.head),
        sortOrder: Value(5)),
    StoreItemsCompanion(
        code: Value('decor_sakura'),
        name: Value('樱花庭院'),
        kind: Value(ItemKind.decor),
        iconKey: Value('sakura'),
        priceCoin: Value(200),
        description: Value('把家搬进春天的院子'),
        decorSlot: Value(DecorSlot.scene),
        sortOrder: Value(6)),
    StoreItemsCompanion(
        code: Value('decor_night'),
        name: Value('星空夜'),
        kind: Value(ItemKind.decor),
        iconKey: Value('night'),
        priceCoin: Value(260),
        description: Value('深夜记账有星星陪着'),
        decorSlot: Value(DecorSlot.scene),
        sortOrder: Value(7)),
  ];

  /// v3 → v4：给已存在的商品行补上佩戴位（`onCreate` 走新 schema，不需要）。
  ///
  /// 直接读 `_catalog`，不另写一份 code→slot 映射 —— 两边写两遍最容易漂移，
  /// 而漂移的表现是「装扮买了却戴不上」，很难查。
  Future<void> _backfillDecorSlots() async {
    for (final item in _catalog) {
      final slot = item.decorSlot.value;
      if (slot == null) continue;
      await (update(storeItems)..where((t) => t.code.equals(item.code.value)))
          .write(StoreItemsCompanion(decorSlot: Value(slot)));
    }
  }

  static final List<(String, AccountsCompanion)> _seedAccounts = [
    (
      'cash',
      AccountsCompanion.insert(
        name: '现金',
        type: const Value('cash'),
        iconKey: const Value('wallet'),
        colorValue: const Value(0xFF2E9E77),
        initialBalanceCents: const Value(12680),
        sortOrder: const Value(0),
      )
    ),
    (
      'alipay',
      AccountsCompanion.insert(
        name: '支付宝',
        type: const Value('alipay'),
        iconKey: const Value('alipay'),
        colorValue: const Value(0xFF1677FF),
        initialBalanceCents: const Value(486500),
        sortOrder: const Value(1),
      )
    ),
    (
      'wechat',
      AccountsCompanion.insert(
        name: '微信钱包',
        type: const Value('wechat'),
        iconKey: const Value('wechat'),
        colorValue: const Value(0xFF07C160),
        initialBalanceCents: const Value(232200),
        sortOrder: const Value(2),
      )
    ),
    (
      'bank',
      AccountsCompanion.insert(
        name: '招商银行',
        type: const Value('bank'),
        iconKey: const Value('bank'),
        colorValue: const Value(0xFFD2453A),
        initialBalanceCents: const Value(3200000),
        sortOrder: const Value(3),
      )
    ),
  ];

  /// 演示预算：本月总预算 + 两个分类专项预算。
  Future<void> _seedBudgets({required Map<String, int> categoryIds}) async {
    final now = DateTime.now();
    final ym = now.year * 100 + now.month;

    final rows = <BudgetsCompanion>[
      BudgetsCompanion.insert(
        yearMonth: ym,
        limitCents: 800000, // ¥8000 总预算
      ),
      BudgetsCompanion.insert(
        yearMonth: ym,
        categoryId: Value(categoryIds['餐饮']!),
        limitCents: 150000, // ¥1500 餐饮
      ),
      BudgetsCompanion.insert(
        yearMonth: ym,
        categoryId: Value(categoryIds['购物']!),
        limitCents: 100000, // ¥1000 购物
      ),
    ];

    await batch((b) => b.insertAll(budgets, rows));
  }

  Future<void> _seedTransactions({
    required int ledgerId,
    required Map<String, int> accountIds,
    required Map<String, int> categoryIds,
  }) async {
    final now = DateTime.now();
    DateTime at(int daysAgo, int hour, int minute) => DateTime(
          now.year,
          now.month,
          now.day - daysAgo,
          hour,
          minute,
        );

    final rows = <TransactionsCompanion>[
      _tx(ledgerId, accountIds['alipay']!, categoryIds['餐饮']!, TxKind.expense,
          3250, '午饭 · 麻辣烫', at(0, 12, 20)),
      _tx(ledgerId, accountIds['wechat']!, categoryIds['交通']!, TxKind.expense,
          400, '地铁通勤', at(0, 8, 45)),
      _tx(ledgerId, accountIds['alipay']!, categoryIds['餐饮']!, TxKind.expense,
          2800, '下午咖啡', at(0, 15, 10)),
      _tx(ledgerId, accountIds['bank']!, categoryIds['工资']!, TxKind.income,
          1850000, '8 月工资', at(1, 10, 0)),
      _tx(ledgerId, accountIds['wechat']!, categoryIds['购物']!, TxKind.expense,
          12900, '宠物粮 + 猫砂', at(1, 19, 30)),
      _tx(ledgerId, accountIds['alipay']!, categoryIds['娱乐']!, TxKind.expense,
          4500, '电影票', at(2, 20, 5)),
      _tx(ledgerId, accountIds['cash']!, categoryIds['其他']!, TxKind.expense,
          1800, '楼下水果', at(3, 18, 40)),
      _tx(ledgerId, accountIds['bank']!, categoryIds['居住']!, TxKind.expense,
          260000, '房租', at(5, 9, 0)),
    ];

    await batch((b) => b.insertAll(transactions, rows));
  }

  static TransactionsCompanion _tx(
    int ledgerId,
    int accountId,
    int categoryId,
    TxKind kind,
    int amountCents,
    String note,
    DateTime occurredAt,
  ) =>
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        accountId: accountId,
        categoryId: categoryId,
        kind: kind,
        amountCents: amountCents,
        note: Value(note),
        occurredAt: occurredAt,
      );

  static const List<CategoriesCompanion> _expenseCategories = [
    CategoriesCompanion(
        name: Value('餐饮'),
        kind: Value(TxKind.expense),
        iconKey: Value('fork'),
        colorValue: Value(0xFFE2584A),
        sortOrder: Value(0),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('交通'),
        kind: Value(TxKind.expense),
        iconKey: Value('bus'),
        colorValue: Value(0xFF1677FF),
        sortOrder: Value(1),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('购物'),
        kind: Value(TxKind.expense),
        iconKey: Value('bag'),
        colorValue: Value(0xFF9B59D0),
        sortOrder: Value(2),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('娱乐'),
        kind: Value(TxKind.expense),
        iconKey: Value('game'),
        colorValue: Value(0xFFF0A11A),
        sortOrder: Value(3),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('居住'),
        kind: Value(TxKind.expense),
        iconKey: Value('home'),
        colorValue: Value(0xFF2E9E77),
        sortOrder: Value(4),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('宠物'),
        kind: Value(TxKind.expense),
        iconKey: Value('paw'),
        colorValue: Value(0xFFE86A9A),
        sortOrder: Value(5),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('医疗'),
        kind: Value(TxKind.expense),
        iconKey: Value('heart'),
        colorValue: Value(0xFFE2557B),
        sortOrder: Value(6),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('其他'),
        kind: Value(TxKind.expense),
        iconKey: Value('more'),
        colorValue: Value(0xFF7A8B84),
        sortOrder: Value(7),
        isBuiltIn: Value(true)),
  ];

  static const List<CategoriesCompanion> _incomeCategories = [
    CategoriesCompanion(
        name: Value('工资'),
        kind: Value(TxKind.income),
        iconKey: Value('pay'),
        colorValue: Value(0xFF2E9E77),
        sortOrder: Value(0),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('兼职'),
        kind: Value(TxKind.income),
        iconKey: Value('job'),
        colorValue: Value(0xFF1677FF),
        sortOrder: Value(1),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('理财'),
        kind: Value(TxKind.income),
        iconKey: Value('invest'),
        colorValue: Value(0xFFF0A11A),
        sortOrder: Value(2),
        isBuiltIn: Value(true)),
    CategoriesCompanion(
        name: Value('其他收入'),
        kind: Value(TxKind.income),
        iconKey: Value('more'),
        colorValue: Value(0xFF7A8B84),
        sortOrder: Value(3),
        isBuiltIn: Value(true)),
  ];
}

import 'package:drift/drift.dart';

/// 收支类型。存成 int，避免字符串拼写漂移。
enum TxKind { expense, income }

/// 商店商品的类别。
///
/// - `food`：消耗品，使用后转化为宠物的饱食 / 经验 / 心情。
/// - `decor`：装扮，不消耗，装备后同时只能有一件生效。
enum ItemKind { food, decor }

/// 装扮的佩戴位置 —— **同一位置同时只能装备一件**。
///
/// - `head`：头饰（蝴蝶结、王冠）
/// - `neck`：颈部（铃铛）
/// - `scene`：场景皮肤（樱花庭院、星空夜），直接改变主页背景
enum DecorSlot { head, neck, scene }

/// 账本：一个用户可有多个账本（日常 / 旅行 / 装修 …）。
@DataClassName('Ledger')
class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 资金账户：现金 / 银行卡 / 支付宝 / 微信 …
@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get type => text().withDefault(const Constant('cash'))();
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2E9E77))();

  /// 账户**初始**余额（分）—— 建档时填的金额，之后不再改动。
  ///
  /// 当前余额一律由「初始余额 + 该账户流水净额」派生（见 `AccountBalance`），
  /// 这样记账 / 改账 / 删账都天然一致，不存在对不上账的可能。
  IntColumn get initialBalanceCents =>
      integer().withDefault(const Constant(0))();
  BoolColumn get includedInNetWorth =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 分类：支出 / 收入各一套。
@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  IntColumn get kind => intEnum<TxKind>()();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 系统预置分类不允许删除。
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
}

/// 账目流水。
@DataClassName('TxRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId =>
      integer().references(Ledgers, #id, onDelete: KeyAction.cascade)();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get kind => intEnum<TxKind>()();

  /// 金额（分），恒为正；方向由 kind 决定。
  IntColumn get amountCents => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 宠物养成状态（单例，id 恒为 1）。
///
/// 记录养成进度：等级 / 经验 / 金币 / 饱食度 / 心情。
@DataClassName('PetState')
class PetStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withDefault(const Constant('团团'))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get exp => integer().withDefault(const Constant(0))();
  IntColumn get coin => integer().withDefault(const Constant(0))();
  IntColumn get hunger => integer().withDefault(const Constant(60))();
  IntColumn get mood => integer().withDefault(const Constant(70))();
  IntColumn get totalRecorded => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastFedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 预算：按「月份 + 分类」设置支出上限。
///
/// `categoryId` 为空表示该月的**总预算**；非空表示某个支出分类的专项预算。
/// 用 `yearMonth`（形如 202609）而不是日期，避免同月多条记录口径不一。
@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get yearMonth => integer()();
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get limitCents => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 商店商品目录（预置，不随用户变化）。
///
/// `code` 是稳定标识：签到奖励之类的逻辑引用它，改名字不影响奖励发放。
@DataClassName('StoreItem')
class StoreItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  IntColumn get kind => intEnum<ItemKind>()();
  TextColumn get iconKey => text()();
  IntColumn get priceCoin => integer()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 使用后的效果（仅 food 有意义）。
  IntColumn get hungerGain => integer().withDefault(const Constant(0))();
  IntColumn get expGain => integer().withDefault(const Constant(0))();
  IntColumn get moodGain => integer().withDefault(const Constant(0))();

  /// 佩戴位置（仅 decor 有意义；食物为 null）。
  IntColumn get decorSlot => intEnum<DecorSlot>().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 背包：用户拥有的商品。
///
/// 每个商品最多一行 —— 重复购买只加数量，不会堆出多行，因此可以直接与
/// `store_items` 做一对一 LEFT JOIN。
@DataClassName('InventoryEntry')
class Inventories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(StoreItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// 装扮是否正在使用（同类同时只允许一件）。
  BoolColumn get equipped => boolean().withDefault(const Constant(false))();
  DateTimeColumn get acquiredAt => dateTime().withDefault(currentDateAndTime)();
}

/// 签到记录：一天一条。
@DataClassName('Checkin')
class Checkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get day => dateTime()();

  /// 这是连续签到的第几天（断签后从 1 重新计）。
  IntColumn get streak => integer()();
  IntColumn get coinGained => integer()();
  TextColumn get bonusText =>
      text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

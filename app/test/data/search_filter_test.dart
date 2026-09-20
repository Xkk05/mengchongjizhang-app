import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late int ledgerId;
  late Map<String, int> accounts;
  late Map<String, int> cats;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    ledgerId = (await db.select(db.ledgers).getSingle()).id;
    accounts = {
      for (final a in await db.select(db.accounts).get()) a.name: a.id,
    };
    cats = {
      for (final c in await db.select(db.categories).get()) c.name: c.id,
    };

    Future<void> tx(String account, String cat, TxKind kind, int cents,
        String note, DateTime at) {
      return db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              accountId: accounts[account]!,
              categoryId: cats[cat]!,
              kind: kind,
              amountCents: cents,
              note: Value(note),
              occurredAt: at,
            ),
          );
    }

    await tx('支付宝', '餐饮', TxKind.expense, 3250, '午饭 · 麻辣烫',
        DateTime(2026, 9, 1, 12, 0));
    await tx('微信钱包', '交通', TxKind.expense, 400, '地铁',
        DateTime(2026, 9, 2, 8, 0));
    await tx('招商银行', '工资', TxKind.income, 1850000, '8 月工资',
        DateTime(2026, 9, 3, 10, 0));
    await tx('支付宝', '购物', TxKind.expense, 12900, '猫砂',
        DateTime(2026, 9, 4, 19, 0));
  });

  tearDown(() => db.close());

  test('关键词搜索命中备注与分类名', () async {
    final byNote = await repo.watchRecent(query: '麻辣烫').first;
    expect(byNote.map((t) => t.note), contains('午饭 · 麻辣烫'));
    expect(byNote, hasLength(1));

    final byCat = await repo.watchRecent(query: '交通').first;
    expect(byCat.map((t) => t.categoryName), contains('交通'));
  });

  test('分类筛选', () async {
    final foodId = cats['餐饮']!;
    final result = await repo.watchRecent(categoryIds: {foodId}).first;
    expect(result.every((t) => t.categoryName == '餐饮'), isTrue);
    expect(result, hasLength(1));
  });

  test('账户筛选', () async {
    final alipayId = accounts['支付宝']!;
    final result = await repo.watchRecent(accountIds: {alipayId}).first;
    expect(result.every((t) => t.accountName == '支付宝'), isTrue);
    expect(result, hasLength(2), reason: '午饭 + 猫砂');
  });

  test('类型筛选（含转账转入侧账户匹配）', () async {
    final transferCatId = await repo.transferCategoryId();
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            accountId: accounts['支付宝']!,
            categoryId: transferCatId,
            kind: TxKind.transfer,
            amountCents: 50000,
            note: Value('调拨'),
            occurredAt: DateTime(2026, 9, 5, 9, 0),
            toAccountId: Value(accounts['招商银行']),
          ),
        );

    final incomes = await repo.watchRecent(kinds: {TxKind.income}).first;
    expect(incomes.every((t) => t.isIncome), isTrue);

    final transfers = await repo.watchRecent(kinds: {TxKind.transfer}).first;
    expect(transfers, hasLength(1));
    expect(transfers.single.isTransfer, isTrue);

    // 账户筛选应覆盖转入侧：转进招商银行的这笔也能被「招商银行」筛到。
    final bankId = accounts['招商银行']!;
    final toBank = await repo.watchRecent(accountIds: {bankId}).first;
    expect(toBank.any((t) => t.isTransfer), isTrue);
  });

  test('批量删除指定账目，其余保留', () async {
    final all = await repo.watchRecent().first;
    final toDelete = all.take(2).map((t) => t.row.id).toList();

    await repo.deleteTransactions(toDelete);

    final remaining = await repo.watchRecent().first;
    expect(remaining, hasLength(all.length - 2));
    expect(remaining.any((t) => toDelete.contains(t.row.id)), isFalse);
  });
}

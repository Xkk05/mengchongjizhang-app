import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Category>> catsOf(TxKind kind) => repo.categoriesOf(kind);

  test('新增分类排在该类型末尾且为非内置', () async {
    final before = (await catsOf(TxKind.expense)).length;
    final id = await repo.addCategory(
      kind: TxKind.expense,
      name: '宠物医疗',
      iconKey: 'heart',
      colorValue: 0xFFE2557B,
    );

    final after = await catsOf(TxKind.expense);
    expect(after.length, before + 1);
    final added = after.firstWhere((c) => c.id == id);
    expect(added.name, '宠物医疗');
    expect(added.isBuiltIn, isFalse);
  });

  test('改名 / 换图标 / 换颜色', () async {
    final id = await repo.addCategory(
      kind: TxKind.income,
      name: '外快',
      iconKey: 'job',
      colorValue: 0xFF1677FF,
    );

    await repo.updateCategory(
      id: id,
      name: '副业',
      iconKey: 'invest',
      colorValue: 0xFFF0A11A,
    );

    final cat = (await catsOf(TxKind.income)).firstWhere((c) => c.id == id);
    expect(cat.name, '副业');
    expect(cat.iconKey, 'invest');
    expect(cat.colorValue, 0xFFF0A11A);
  });

  test('内置分类不可删除', () async {
    final builtIn = (await catsOf(TxKind.expense))
        .firstWhere((c) => c.isBuiltIn);
    final err = await repo.deleteCategory(builtIn.id);
    expect(err, isNotNull);
    expect(err, contains('不可删除'));
  });

  test('有账目的分类不可删除', () async {
    final id = await repo.addCategory(
      kind: TxKind.expense,
      name: '宠物医疗',
      iconKey: 'heart',
      colorValue: 0xFFE2557B,
    );
    final ledger = await db.select(db.ledgers).getSingle();
    final account = (await db.select(db.accounts).get()).first;

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledger.id,
            accountId: account.id,
            categoryId: id,
            kind: TxKind.expense,
            amountCents: 100,
            occurredAt: DateTime(2020, 1, 1),
          ),
        );

    final err = await repo.deleteCategory(id);
    expect(err, isNotNull);
    expect(err, contains('笔账目'));
  });

  test('无账目的非内置分类可删除', () async {
    final id = await repo.addCategory(
      kind: TxKind.expense,
      name: '临时',
      iconKey: 'more',
      colorValue: 0xFF7A8B84,
    );
    final err = await repo.deleteCategory(id);
    expect(err, isNull);
    expect((await catsOf(TxKind.expense)).any((c) => c.id == id), isFalse);
  });
}

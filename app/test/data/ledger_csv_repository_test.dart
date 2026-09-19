import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/domain/csv/ledger_csv.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    // 演示流水已随 _seedSample 关闭，这里自备同样的 8 笔，测试不再依赖首装数据。
    await _seedDemoRows(db);
  });

  tearDown(() => db.close());

  Future<int> txCount() async =>
      (await db.select(db.transactions).get()).length;

  Future<PetState> pet() async =>
      (db.select(db.petStates)..where((t) => t.id.equals(1))).getSingle();

  Future<List<Category>> allCategories() => db.select(db.categories).get();

  Future<List<Account>> allAccounts() => db.select(db.accounts).get();

  /// 造一行 CSV 文本并解析，模拟「用户选了一个文件」。
  CsvParseResult csv(String body) =>
      LedgerCsv.parse('日期,类型,分类,账户,金额,备注\r\n$body');

  group('导出', () {
    test('导出全部流水，字段与原文一致', () async {
      final rows = await repo.exportRows();
      expect(rows, hasLength(8));

      final lunch = rows.firstWhere((r) => r.note == '午饭 · 麻辣烫');
      expect(lunch.isExpense, isTrue);
      expect(lunch.amountCents, 3250);
      expect(lunch.categoryName, '餐饮');
      expect(lunch.accountName, '支付宝');

      final salary = rows.firstWhere((r) => r.note == '8 月工资');
      expect(salary.isExpense, isFalse);
      expect(salary.amountCents, 1850000);
    });

    test('导出 → 解析 → 再导入，全部识别为重复', () async {
      final text = LedgerCsv.encode(await repo.exportRows());
      final parsed = LedgerCsv.parse(text);

      expect(parsed.errors, isEmpty);
      expect(parsed.rows, hasLength(8));

      final preview = await repo.previewImport(parsed);
      expect(preview.importable, 0);
      expect(preview.duplicates, 8);

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 0);
      expect(outcome.duplicates, 8);
      expect(await txCount(), 8, reason: '重复导入不应产生新记录');
    });

    test('往返后金额与方向无损', () async {
      final before = await repo.exportRows();
      final after = LedgerCsv.parse(LedgerCsv.encode(before)).rows;
      expect(after, hasLength(before.length));
      for (final r in after) {
        final match = before.firstWhere((b) =>
            b.amountCents == r.amountCents &&
            b.isExpense == r.isExpense &&
            b.categoryName == r.categoryName &&
            b.accountName == r.accountName &&
            b.note == r.note);
        expect(match.at, r.at);
      }
    });
  });

  group('导入', () {
    test('新记录入库，条数增加', () async {
      final parsed = csv('2020-01-01 10:00,支出,餐饮,支付宝,10.00,早餐\r\n');
      expect(parsed.errors, isEmpty);

      final preview = await repo.previewImport(parsed);
      expect(preview.importable, 1);
      expect(preview.duplicates, 0);

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 1);
      expect(await txCount(), 9);

      final all = await repo.watchRecent().first;
      final row = all.firstWhere((t) => t.note == '早餐');
      expect(row.isExpense, isTrue);
      expect(row.amountCents, 1000);
      expect(row.categoryName, '餐饮');
      expect(row.accountName, '支付宝');
    });

    test('收入方向正确入库', () async {
      final parsed = csv('2020-02-02 09:00,收入,工资,招商银行,999.00,奖金\r\n');
      await repo.importRows(parsed);

      final row = (await repo.watchRecent().first)
          .firstWhere((t) => t.note == '奖金');
      expect(row.isExpense, isFalse);
      expect(row.amountCents, 99900);
    });

    test('缺分类 / 缺账户会自动建档，并在预览里先告知', () async {
      final parsed = csv('2020-03-03 15:00,支出,奶茶,云闪付,18.50,下午茶\r\n');

      final preview = await repo.previewImport(parsed);
      expect(preview.newExpenseCategories, ['奶茶']);
      expect(preview.newAccounts, ['云闪付']);
      expect(preview.newCategoryCount, 1);

      final outcome = await repo.importRows(parsed);
      expect(outcome.newCategories, 1);
      expect(outcome.newAccounts, 1);
      expect(outcome.inserted, 1);

      final cat = (await allCategories())
          .firstWhere((c) => c.name == '奶茶');
      expect(cat.kind, TxKind.expense);

      final acc = (await allAccounts()).firstWhere((a) => a.name == '云闪付');
      expect(acc.name, '云闪付');

      final row = (await repo.watchRecent().first)
          .firstWhere((t) => t.note == '下午茶');
      expect(row.categoryName, '奶茶');
      expect(row.accountName, '云闪付');
    });

    test('已有分类 / 账户不会被重复创建', () async {
      final before = (await allCategories()).length;
      final parsed = csv('2020-04-04 08:00,支出,餐饮,支付宝,5.00,x\r\n');

      final preview = await repo.previewImport(parsed);
      expect(preview.newExpenseCategories, isEmpty);
      expect(preview.newAccounts, isEmpty);

      await repo.importRows(parsed);
      expect((await allCategories()).length, before);
    });

    test('分类 / 账户为空时走兜底（其他 / 现金）', () async {
      final parsed = csv('2020-05-05 07:00,支出,,,6.00,杂项\r\n');
      await repo.importRows(parsed);

      final row = (await repo.watchRecent().first)
          .firstWhere((t) => t.note == '杂项');
      expect(row.categoryName, '其他');
      expect(row.accountName, '现金');
    });

    test('收入行的空分类兜底到「其他收入」', () async {
      final parsed = csv('2020-05-06 07:00,收入,,,7.00,红包\r\n');
      await repo.importRows(parsed);

      final row = (await repo.watchRecent().first)
          .firstWhere((t) => t.note == '红包');
      expect(row.categoryName, '其他收入');
      expect(row.isExpense, isFalse);
    });

    test('导入不发养成奖励（历史账单不该刷经验）', () async {
      final before = await pet();
      final parsed = csv('2020-06-06 06:00,支出,餐饮,支付宝,1.00,a\r\n'
          '2020-06-07 06:00,支出,餐饮,支付宝,2.00,b\r\n'
          '2020-06-08 06:00,支出,餐饮,支付宝,3.00,c\r\n');

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 3);

      final after = await pet();
      expect(after.level, before.level);
      expect(after.exp, before.exp);
      expect(after.coin, before.coin, reason: '导入不应发金币');
      expect(after.totalRecorded, before.totalRecorded);
    });

    test('异常行不影响好行导入', () async {
      final parsed = csv('不是日期,支出,餐饮,支付宝,1.00,坏行\r\n'
          '2020-07-07 07:00,支出,餐饮,支付宝,7.00,好行\r\n'
          '2020-07-08 07:00,支出,餐饮,支付宝,abc,坏金额\r\n');

      expect(parsed.errors, hasLength(2));
      final preview = await repo.previewImport(parsed);
      expect(preview.importable, 1);
      expect(preview.errors, hasLength(2));

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 1);
      expect(await txCount(), 9);
    });

    test('全部为重复时不写库也不报错', () async {
      final parsed = csv('2020-08-08 08:00,支出,餐饮,支付宝,8.00,dup\r\n');
      expect((await repo.importRows(parsed)).inserted, 1);

      final again = csv('2020-08-08 08:00,支出,餐饮,支付宝,8.00,dup\r\n');
      final preview = await repo.previewImport(again);
      expect(preview.importable, 0);
      expect(preview.duplicates, 1);

      final outcome = await repo.importRows(again);
      expect(outcome.inserted, 0);
      expect(await txCount(), 9);
    });

    test('计数去重：库内 1 条、文件 2 条相同指纹 → 跳过 1 条导入 1 条', () async {
      // 先造一条库内记录（14:30:10 带秒）。
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: 1,
              accountId: (await allAccounts())
                  .firstWhere((a) => a.name == '支付宝')
                  .id,
              categoryId: (await allCategories())
                  .firstWhere((c) => c.name == '餐饮')
                  .id,
              kind: TxKind.expense,
              amountCents: 1000,
              occurredAt: DateTime(2020, 9, 9, 14, 30, 10),
              note: Value('同分钟两笔'),
            ),
          );

      // 文件里两条同分钟（14:30）同字段的行。
      final parsed = csv('2020-09-09 14:30,支出,餐饮,支付宝,10.00,同分钟两笔\r\n'
          '2020-09-09 14:30,支出,餐饮,支付宝,10.00,同分钟两笔\r\n');

      final preview = await repo.previewImport(parsed);
      expect(preview.duplicates, 1, reason: '库内 1 条抵消 1 条');
      expect(preview.importable, 1);

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 1);
      expect(outcome.duplicates, 1);
      expect(await txCount(), 10);
    });

    test('空文件导入是安全 no-op', () async {
      final outcome = await repo.importRows(LedgerCsv.parse(''));
      expect(outcome.inserted, 0);
      expect(await txCount(), 8);
    });

    test('一次导入多个新分类时逐个建档', () async {
      final parsed = csv('2020-10-10 10:00,支出,咖啡,支付宝,20.00,a\r\n'
          '2020-10-11 10:00,支出,健身,支付宝,30.00,b\r\n'
          '2020-10-12 10:00,收入,稿费,支付宝,300.00,c\r\n');

      final preview = await repo.previewImport(parsed);
      expect(preview.newExpenseCategories, ['咖啡', '健身']);
      expect(preview.newIncomeCategories, ['稿费']);
      expect(preview.newCategoryCount, 3);

      final outcome = await repo.importRows(parsed);
      expect(outcome.inserted, 3);
      expect(outcome.newCategories, 3);

      final names = (await allCategories()).map((c) => c.name).toList();
      expect(names, containsAll(['咖啡', '健身', '稿费']));
    });
  });
}

/// 与生产库 `_seedTransactions` 相同的 8 笔演示流水（时间相对当天），
/// 供导出 / 去重用例自备数据，不依赖 `_seedSample` 开关。
Future<void> _seedDemoRows(AppDatabase db) async {
  final ledger = await db.select(db.ledgers).getSingle();
  final accounts = {
    for (final a in await db.select(db.accounts).get()) a.name: a.id,
  };
  final cats = {
    for (final c in await db.select(db.categories).get()) c.name: c.id,
  };

  final now = DateTime.now();
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  Future<void> tx(
    String account,
    String cat,
    TxKind kind,
    int cents,
    String note,
    DateTime occurredAt,
  ) {
    return db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledger.id,
            accountId: accounts[account]!,
            categoryId: cats[cat]!,
            kind: kind,
            amountCents: cents,
            note: Value(note),
            occurredAt: occurredAt,
          ),
        );
  }

  await tx('支付宝', '餐饮', TxKind.expense, 3250, '午饭 · 麻辣烫', at(0, 12, 20));
  await tx('微信钱包', '交通', TxKind.expense, 400, '地铁通勤', at(0, 8, 45));
  await tx('支付宝', '餐饮', TxKind.expense, 2800, '下午咖啡', at(0, 15, 10));
  await tx('招商银行', '工资', TxKind.income, 1850000, '8 月工资', at(1, 10, 0));
  await tx('微信钱包', '购物', TxKind.expense, 12900, '宠物粮 + 猫砂', at(1, 19, 30));
  await tx('支付宝', '娱乐', TxKind.expense, 4500, '电影票', at(2, 20, 5));
  await tx('现金', '其他', TxKind.expense, 1800, '楼下水果', at(3, 18, 40));
  await tx('招商银行', '居住', TxKind.expense, 260000, '房租', at(5, 9, 0));
}

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

  Future<int> idOf(String code) async {
    final row = await (db.select(db.storeItems)
          ..where((t) => t.code.equals(code)))
        .getSingle();
    return row.id;
  }

  Future<InventoryEntry?> invOf(int itemId) async =>
      (db.select(db.inventories)..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

  Future<PetState> pet() async =>
      (db.select(db.petStates)..where((t) => t.id.equals(1))).getSingle();

  Future<StoreEntry> entryOf(String code) async {
    final all = await repo.watchStore().first;
    return all.firstWhere((e) => e.item.code == code);
  }

  /// 直接改宠物金币 —— 装扮测试要买好几件，新手礼包的 60 不够。
  Future<void> grantCoin(int coin) async {
    await (db.update(db.petStates)..where((t) => t.id.equals(1)))
        .write(PetStatesCompanion(coin: Value(coin)));
  }

  group('商品目录与佩戴位', () {
    test('目录预置 8 件商品，装扮都带佩戴位', () async {
      final all = await repo.watchStore().first;
      expect(all.length, 8);

      final decors = all.where((e) => e.isDecor).toList();
      expect(decors.length, 5);
      expect(decors.every((e) => e.item.decorSlot != null), isTrue);

      final foods = all.where((e) => e.isFood).toList();
      expect(foods.every((e) => e.item.decorSlot == null), isTrue);
    });

    test('头饰 / 颈部 / 场景各有归属', () async {
      expect((await entryOf('decor_ribbon')).item.decorSlot, DecorSlot.head);
      expect((await entryOf('decor_crown')).item.decorSlot, DecorSlot.head);
      expect((await entryOf('decor_bell')).item.decorSlot, DecorSlot.neck);
      expect((await entryOf('decor_sakura')).item.decorSlot, DecorSlot.scene);
      expect((await entryOf('decor_night')).item.decorSlot, DecorSlot.scene);
    });
  });

  group('购买', () {
    test('初始金币为新手礼包，购买后扣币并入库', () async {
      expect((await pet()).coin, AppDatabase.welcomeCoin);

      final fish = await idOf('food_fish');
      final r = await repo.buyItem(fish);

      expect(r.ok, isTrue);
      expect((await pet()).coin, AppDatabase.welcomeCoin - 10);
      expect((await invOf(fish))?.quantity, 1);
    });

    test('金币不足时被拒且不扣币、不入库', () async {
      final crown = await idOf('decor_crown'); // 150 金币 > 新手礼包 60
      final before = (await pet()).coin;

      final r = await repo.buyItem(crown);

      expect(r.ok, isFalse);
      expect(r.reason, contains('还差'));
      expect((await pet()).coin, before);
      expect(await invOf(crown), isNull);
    });

    test('重复购买只加数量，不堆出多行', () async {
      final fish = await idOf('food_fish');
      await repo.buyItem(fish);
      await repo.buyItem(fish);

      final rows = await (db.select(db.inventories)
            ..where((t) => t.itemId.equals(fish)))
          .get();
      expect(rows.length, 1);
      expect(rows.single.quantity, 2);
      expect((await pet()).coin, AppDatabase.welcomeCoin - 20);
    });
  });

  group('使用道具', () {
    test('没拥有的道具无法使用', () async {
      final r = await repo.useItem(await idOf('food_fish'));
      expect(r.ok, isFalse);
      expect(r.reason, contains('没有'));
    });

    test('食物消耗 1 个并结算饱食 / 经验 / 心情', () async {
      final can = await idOf('food_can');
      await repo.buyItem(can);

      final before = await pet();
      final r = await repo.useItem(can);
      final after = await pet();

      expect(r.ok, isTrue);
      expect(after.hunger, greaterThan(before.hunger));
      expect(after.exp, greaterThan(before.exp));
      expect(after.mood, greaterThan(before.mood));
      // 最后一个吃完，条目整行移除
      expect(await invOf(can), isNull);
    });

    test('吃食物不额外扣金币', () async {
      final can = await idOf('food_can');
      await repo.buyItem(can);
      final afterBuy = (await pet()).coin;

      await repo.useItem(can);

      expect((await pet()).coin, afterBuy);
    });
  });

  group('装扮装备', () {
    // 装扮单价 60~260，新手礼包买不齐，先补足金币再测装备逻辑本身。
    setUp(() => grantCoin(2000));

    test('同一佩戴位互斥：换头饰会卸下前一件', () async {
      final ribbon = await idOf('decor_ribbon');
      final crown = await idOf('decor_crown');
      await repo.buyItem(ribbon);
      await repo.buyItem(crown);

      await repo.useItem(ribbon);
      expect((await invOf(ribbon))?.equipped, isTrue);

      await repo.useItem(crown);
      expect((await invOf(crown))?.equipped, isTrue);
      expect((await invOf(ribbon))?.equipped, isFalse);
    });

    test('不同佩戴位可以同时生效', () async {
      final crown = await idOf('decor_crown'); // head
      final bell = await idOf('decor_bell'); // neck
      final sakura = await idOf('decor_sakura'); // scene
      await repo.buyItem(crown);
      await repo.buyItem(bell);
      await repo.buyItem(sakura);

      await repo.useItem(crown);
      await repo.useItem(bell);
      await repo.useItem(sakura);

      expect((await invOf(crown))?.equipped, isTrue);
      expect((await invOf(bell))?.equipped, isTrue);
      expect((await invOf(sakura))?.equipped, isTrue);
    });

    test('装备装扮不消耗数量', () async {
      final bell = await idOf('decor_bell');
      await repo.buyItem(bell);
      await repo.useItem(bell);

      expect((await invOf(bell))?.quantity, 1);
    });

    test('脱下只影响自己，其他佩戴位不动', () async {
      final crown = await idOf('decor_crown');
      final bell = await idOf('decor_bell');
      await repo.buyItem(crown);
      await repo.buyItem(bell);
      await repo.useItem(crown);
      await repo.useItem(bell);

      await repo.unequip(bell);

      expect((await invOf(bell))?.equipped, isFalse);
      expect((await invOf(crown))?.equipped, isTrue);
    });

    test('已装备信息能通过 watchStore 读回', () async {
      final crown = await idOf('decor_crown');
      await repo.buyItem(crown);
      await repo.useItem(crown);

      final entry = await entryOf('decor_crown');
      expect(entry.owned, isTrue);
      expect(entry.equipped, isTrue);
    });
  });

  group('签到', () {
    final day1 = DateTime(2026, 9, 10);
    DateTime day(int n) => DateTime(2026, 9, 10 + n - 1);

    test('首次签到发第 1 天奖励并记连击 1', () async {
      final before = (await pet()).coin;
      final out = await repo.checkIn(day1);

      expect(out.ok, isTrue);
      expect(out.streak, 1);
      expect(out.coin, 20);
      expect((await pet()).coin, before + 20);
    });

    test('同一天不能重复签', () async {
      await repo.checkIn(day1);
      final again = await repo.checkIn(DateTime(2026, 9, 10, 23, 59));

      expect(again.ok, isFalse);
      expect(await repo.watchCheckins().first, hasLength(1));
    });

    test('连续签到连击递增并推进周期奖励', () async {
      await repo.checkIn(day(1));
      final second = await repo.checkIn(day(2));
      final third = await repo.checkIn(day(3));

      expect(second.streak, 2);
      expect(second.coin, 30);
      expect(third.streak, 3);
      expect(third.coin, 40);
    });

    test('第 3 天额外送道具', () async {
      await repo.checkIn(day(1));
      await repo.checkIn(day(2));
      final third = await repo.checkIn(day(3));

      expect(third.bonusText, contains('小鱼干'));
      expect((await invOf(await idOf('food_fish')))?.quantity, 1);
    });

    test('断签后连击从 1 重新计，奖励回到第 1 天', () async {
      await repo.checkIn(day(1));
      await repo.checkIn(day(2));
      final afterGap = await repo.checkIn(day(6));

      expect(afterGap.streak, 1);
      expect(afterGap.coin, 20);
    });

    test('签到历史按日期倒序', () async {
      await repo.checkIn(day(1));
      await repo.checkIn(day(2));

      final history = await repo.watchCheckins().first;
      expect(history.length, 2);
      expect(history.first.streak, 2);
      expect(history.last.streak, 1);
    });
  });
}

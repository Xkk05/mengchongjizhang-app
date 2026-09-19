import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/ledger_providers.dart';
import 'package:suixin_pet_ledger/state/shop_providers.dart';
import 'package:suixin_pet_ledger/ui/backpack/backpack_page.dart';

StoreItem _item({
  required int id,
  required String name,
  required ItemKind kind,
  required int price,
}) =>
    StoreItem(
      id: id,
      code: 'code_$id',
      name: name,
      kind: kind,
      iconKey: kind == ItemKind.food ? 'fish' : 'ribbon',
      priceCoin: price,
      description: '测试商品 $name',
      hungerGain: 8,
      expGain: 6,
      moodGain: 2,
      sortOrder: id,
    );

StoreEntry _entry(StoreItem item, {int quantity = 1, bool equipped = false}) =>
    StoreEntry(
      item: item,
      inventoryId: quantity > 0 ? item.id : null,
      quantity: quantity,
      equipped: equipped,
    );

const _pet = PetState(
  id: 1,
  name: '团团',
  level: 3,
  exp: 20,
  coin: 88,
  hunger: 60,
  mood: 70,
  totalRecorded: 12,
  lastFedAt: null,
);

Widget _host(List<StoreEntry> entries) {
  return ProviderScope(
    overrides: [
      storeEntriesProvider.overrideWith((ref) => Stream.value(entries)),
      petStateProvider.overrideWith((ref) => Stream.value(_pet)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const BackpackPage(),
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<StoreEntry> entries) async {
  await tester.binding.setSurfaceSize(const Size(460, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(entries));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final fish = _item(id: 1, name: '小鱼干', kind: ItemKind.food, price: 10);
  final ribbon = _item(id: 2, name: '红蝴蝶结', kind: ItemKind.decor, price: 60);
  final bell = _item(id: 3, name: '金铃铛', kind: ItemKind.decor, price: 90);

  testWidgets('背包为空时展示空态引导', (tester) async {
    await _pump(tester, [_entry(fish, quantity: 0)]);

    expect(tester.takeException(), isNull);
    expect(find.text('背包空空的'), findsOneWidget);
    expect(find.text('去商店买点东西，或者签到领道具'), findsOneWidget);
  });

  testWidgets('食物与装扮分开展示', (tester) async {
    await _pump(tester, [
      _entry(fish, quantity: 2),
      _entry(ribbon, equipped: true),
      _entry(bell),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('食物'), findsOneWidget);
    expect(find.text('装扮'), findsOneWidget);
    expect(find.text('小鱼干'), findsOneWidget);
    expect(find.text('红蝴蝶结'), findsOneWidget);
    expect(find.text('金铃铛'), findsOneWidget);
  });

  testWidgets('食物显示数量与「使用」按钮', (tester) async {
    await _pump(tester, [_entry(fish, quantity: 2)]);

    expect(tester.takeException(), isNull);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('使用'), findsOneWidget);
    expect(find.text('装扮'), findsNothing);
  });

  testWidgets('已装备的装扮标出「使用中」并可脱下', (tester) async {
    await _pump(tester, [_entry(ribbon, equipped: true), _entry(bell)]);

    expect(tester.takeException(), isNull);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('脱下'), findsOneWidget);
    expect(find.text('装备'), findsOneWidget);
  });
}

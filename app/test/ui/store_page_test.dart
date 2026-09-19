import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/db/tables.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/ledger_providers.dart';
import 'package:suixin_pet_ledger/state/shop_providers.dart';
import 'package:suixin_pet_ledger/ui/store/store_page.dart';

StoreItem _item({
  required int id,
  required String name,
  required ItemKind kind,
  required int price,
  int hungerGain = 0,
  int expGain = 0,
  int moodGain = 0,
}) =>
    StoreItem(
      id: id,
      code: 'code_$id',
      name: name,
      kind: kind,
      iconKey: kind == ItemKind.food ? 'fish' : 'ribbon',
      priceCoin: price,
      description: '测试商品 $name',
      hungerGain: hungerGain,
      expGain: expGain,
      moodGain: moodGain,
      sortOrder: id,
    );

StoreEntry _entry(StoreItem item, {int quantity = 0, bool equipped = false}) =>
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
      home: const StorePage(),
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<StoreEntry> entries) async {
  await tester.binding.setSurfaceSize(const Size(500, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(entries));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final food = _item(
    id: 1,
    name: '小鱼干',
    kind: ItemKind.food,
    price: 10,
    hungerGain: 8,
    expGain: 6,
    moodGain: 2,
  );
  final can = _item(
    id: 2,
    name: '营养罐头',
    kind: ItemKind.food,
    price: 25,
    hungerGain: 18,
    expGain: 16,
    moodGain: 5,
  );
  final ribbon = _item(id: 3, name: '红蝴蝶结', kind: ItemKind.decor, price: 60);

  testWidgets('默认展示食物分类与价格', (tester) async {
    await _pump(tester, [_entry(food), _entry(can), _entry(ribbon)]);

    expect(tester.takeException(), isNull);
    expect(find.text('小鱼干'), findsOneWidget);
    expect(find.text('营养罐头'), findsOneWidget);
    // 装扮不在食物分类下
    expect(find.text('红蝴蝶结'), findsNothing);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('购买'), findsNWidgets(2));
    // 金币胶囊显示余额
    expect(find.text('88'), findsOneWidget);
  });

  testWidgets('切到装扮分类展示装扮商品', (tester) async {
    await _pump(tester, [_entry(food), _entry(ribbon)]);

    await tester.tap(find.text('装扮'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('红蝴蝶结'), findsOneWidget);
    expect(find.text('小鱼干'), findsNothing);
  });

  testWidgets('已拥有的商品展示数量与「再买」', (tester) async {
    await _pump(tester, [_entry(food, quantity: 3)]);

    expect(tester.takeException(), isNull);
    expect(find.text('已有 ×3'), findsOneWidget);
    expect(find.text('再买'), findsOneWidget);
    expect(find.text('购买'), findsNothing);
  });

  testWidgets('食物商品展示使用效果', (tester) async {
    await _pump(tester, [_entry(food)]);

    expect(tester.takeException(), isNull);
    expect(find.text('饱食+8 · 经验+6 · 心情+2'), findsOneWidget);
  });

  testWidgets('分类下没有商品时给出空态', (tester) async {
    await _pump(tester, [_entry(food)]);

    await tester.tap(find.text('装扮'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('这一类还没有上架'), findsOneWidget);
  });
}

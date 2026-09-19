import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/tables.dart';
import '../data/repositories/ledger_repository.dart';
import 'providers.dart';

/// 商店目录（含我的持有情况）。
final storeEntriesProvider = StreamProvider<List<StoreEntry>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchStore();
});

/// 背包 = 已拥有的商品。
final backpackProvider = Provider<List<StoreEntry>>((ref) {
  final all = ref.watch(storeEntriesProvider).value ?? const <StoreEntry>[];
  return all.where((e) => e.owned).toList(growable: false);
});

/// 背包里的食物（可食用消耗）。
final backpackFoodProvider = Provider<List<StoreEntry>>((ref) =>
    ref.watch(backpackProvider).where((e) => e.isFood).toList(growable: false));

/// 背包里的装扮（可装备）。
final backpackDecorProvider = Provider<List<StoreEntry>>((ref) =>
    ref.watch(backpackProvider).where((e) => e.isDecor).toList(growable: false));

/// 某个佩戴位上正在使用的装扮（没有则为 null）。
final equippedSlotProvider = Provider.family<StoreEntry?, DecorSlot>((ref, slot) {
  for (final e in ref.watch(backpackDecorProvider)) {
    if (e.equipped && e.item.decorSlot == slot) return e;
  }
  return null;
});

/// 头饰（主页画在头顶）。
final equippedHeadProvider = Provider<StoreEntry?>(
    (ref) => ref.watch(equippedSlotProvider(DecorSlot.head)));

/// 颈部装饰（主页画在脖子上）。
final equippedNeckProvider = Provider<StoreEntry?>(
    (ref) => ref.watch(equippedSlotProvider(DecorSlot.neck)));

/// 场景皮肤（主页换背景）。
final equippedSceneProvider = Provider<StoreEntry?>(
    (ref) => ref.watch(equippedSlotProvider(DecorSlot.scene)));

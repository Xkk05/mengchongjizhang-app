import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../state/providers.dart';
import '../../state/shop_providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../common/coin_chip.dart';

/// 商店：金币换食物 / 装扮。
class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  ItemKind _kind = ItemKind.food;
  int? _busyItemId;

  Future<void> _buy(StoreEntry entry) async {
    if (_busyItemId != null) return;
    setState(() => _busyItemId = entry.item.id);
    try {
      final result =
          await ref.read(ledgerRepositoryProvider).buyItem(entry.item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.ok ? '买到了「${entry.item.name}」' : result.reason,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('购买失败：$e')));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(storeEntriesProvider);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('商店'),
        backgroundColor: c.pageBg,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: CoinChip()),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取商品失败：$e')),
        data: (all) {
          final items =
              all.where((e) => e.item.kind == _kind).toList(growable: false);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
                child: _KindToggle(
                  kind: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          '这一类还没有上架',
                          style:
                              TextStyle(fontSize: AppFontSizes.md, color: c.ink3),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _ItemCard(
                          entry: items[i],
                          busy: _busyItemId == items[i].item.id,
                          onBuy: () => _buy(items[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final ItemKind kind;
  final ValueChanged<ItemKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget seg(String label, ItemKind k) {
      final on = k == kind;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? c.coral : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.md,
                fontWeight: FontWeight.w700,
                color: on ? c.onCoral : c.ink2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [seg('食物', ItemKind.food), seg('装扮', ItemKind.decor)],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.entry,
    required this.busy,
    required this.onBuy,
  });

  final StoreEntry entry;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = entry.item;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIcon(
                icon: iconFor(item.iconKey),
                color: c.mint,
                size: 40,
                iconSize: 20,
              ),
              const Spacer(),
              if (entry.owned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.mint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    entry.isDecor && entry.equipped
                        ? '使用中'
                        : '已有 ×${entry.quantity}',
                    style: TextStyle(
                      fontSize: AppFontSizes.xxs,
                      fontWeight: FontWeight.w800,
                      color: c.mintText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppFontSizes.xxs, color: c.ink3),
          ),
          const Spacer(),
          if (entry.isFood)
            Text(
              _effectText(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSizes.xxs,
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.monetization_on_rounded,
                  size: 14, color: c.onWarm2),
              const SizedBox(width: 3),
              Text(
                '${item.priceCoin}',
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w800,
                  color: c.onWarm1,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: FilledButton.tonal(
                  onPressed: busy ? null : onBuy,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          entry.owned ? '再买' : '购买',
                          style: const TextStyle(fontSize: AppFontSizes.sm),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _effectText(StoreItem item) {
    final parts = <String>[
      if (item.hungerGain > 0) '饱食+${item.hungerGain}',
      if (item.expGain > 0) '经验+${item.expGain}',
      if (item.moodGain > 0) '心情+${item.moodGain}',
    ];
    return parts.join(' · ');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../state/providers.dart';
import '../../state/shop_providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../common/coin_chip.dart';

/// 背包：签到 / 购买得到的道具，食物可食用、装扮可装备。
class BackpackPage extends ConsumerStatefulWidget {
  const BackpackPage({super.key});

  @override
  ConsumerState<BackpackPage> createState() => _BackpackPageState();
}

class _BackpackPageState extends ConsumerState<BackpackPage> {
  int? _busyItemId;

  /// 食物 → 使用；装扮 → 装备 / 脱下（可逆）。
  Future<void> _act(StoreEntry entry) async {
    if (_busyItemId != null) return;
    setState(() => _busyItemId = entry.item.id);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final String msg;
      if (entry.equipped) {
        await repo.unequip(entry.item.id);
        msg = '已脱下「${entry.item.name}」';
      } else {
        final result = await repo.useItem(entry.item.id);
        msg = result.ok
            ? (entry.isFood
                ? '吃掉了「${entry.item.name}」'
                : '已装备「${entry.item.name}」')
            : result.reason;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final food = ref.watch(backpackFoodProvider);
    final decor = ref.watch(backpackDecorProvider);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('背包'),
        backgroundColor: c.pageBg,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: CoinChip()),
          ),
        ],
      ),
      body: (food.isEmpty && decor.isEmpty)
          ? const _EmptyBackpack()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
              children: [
                if (food.isNotEmpty) ...[
                  _SectionTitle('食物', trailing: '${food.length} 种'),
                  const SizedBox(height: AppSpacing.xs),
                  _ItemGroup(
                    entries: food,
                    busyItemId: _busyItemId,
                    actionLabel: '使用',
                    onAction: _act,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (decor.isNotEmpty) ...[
                  _SectionTitle('装扮', trailing: '${decor.length} 种'),
                  const SizedBox(height: AppSpacing.xs),
                  _ItemGroup(
                    entries: decor,
                    busyItemId: _busyItemId,
                    actionLabel: '装备',
                    onAction: _act,
                  ),
                ],
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
            ),
        ],
      ),
    );
  }
}

class _ItemGroup extends StatelessWidget {
  const _ItemGroup({
    required this.entries,
    required this.busyItemId,
    required this.actionLabel,
    required this.onAction,
  });

  final List<StoreEntry> entries;
  final int? busyItemId;
  final String actionLabel;
  final void Function(StoreEntry) onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _ItemTile(
              entry: entries[i],
              busy: busyItemId == entries[i].item.id,
              actionLabel: actionLabel,
              onAction: () => onAction(entries[i]),
            ),
            if (i != entries.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Divider(height: 1, color: c.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.entry,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
  });

  final StoreEntry entry;
  final bool busy;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = entry.item;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SoftIcon(icon: iconFor(item.iconKey), color: c.mint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSizes.md,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ),
                    if (entry.isFood) ...[
                      const SizedBox(width: 5),
                      Text(
                        '×${entry.quantity}',
                        style: TextStyle(
                          fontSize: AppFontSizes.sm,
                          fontWeight: FontWeight.w700,
                          color: c.ink3,
                        ),
                      ),
                    ],
                    if (entry.equipped) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.coral.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          '使用中',
                          style: TextStyle(
                            fontSize: AppFontSizes.xxs,
                            fontWeight: FontWeight.w800,
                            color: c.coralText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            height: 30,
            child: FilledButton.tonal(
              onPressed: busy ? null : onAction,
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
                      entry.equipped ? '脱下' : actionLabel,
                      style: const TextStyle(fontSize: AppFontSizes.sm),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBackpack extends StatelessWidget {
  const _EmptyBackpack();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.backpack_outlined,
                size: 46, color: c.ink3.withValues(alpha: 0.45)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '背包空空的',
              style: TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '去商店买点东西，或者签到领道具',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

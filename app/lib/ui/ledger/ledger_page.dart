import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../state/ledger_providers.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../record/record_sheet.dart';
import 'widgets/scene_header.dart';

class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentTransactionsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: '$e'),
      data: (records) {
        final groups = _groupByDay(records);
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SceneHeader()),
            // 余额卡不再上叠场景：上叠时卡片顶部（含文字）落在场景绘制
            // 区内，个别机型上会被场景盖住文字。改为完全排在场景下方。
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: const BalanceBar(),
              ),
            ),
            const SliverToBoxAdapter(child: _QuickEntries()),
            if (groups.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyLedger(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, 120),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, i) =>
                      _DaySection(group: groups[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  static List<_DayGroup> _groupByDay(List<TxRecord> records) {
    final map = <DateTime, List<TxRecord>>{};
    for (final r in records) {
      map.putIfAbsent(DateLabels.dayOf(r.occurredAt), () => []).add(r);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((d) {
      final items = map[d]!;
      var expense = 0;
      var income = 0;
      for (final t in items) {
        if (t.isExpense) {
          expense += t.amountCents;
        } else {
          income += t.amountCents;
        }
      }
      return _DayGroup(day: d, items: items, expense: expense, income: income);
    }).toList(growable: false);
  }
}

class _DayGroup {
  const _DayGroup({
    required this.day,
    required this.items,
    required this.expense,
    required this.income,
  });

  final DateTime day;
  final List<TxRecord> items;
  final int expense;
  final int income;
}

class _DaySection extends ConsumerWidget {
  const _DaySection({required this.group});

  final _DayGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
          child: Row(
            children: [
              Text(
                DateLabels.groupLabel(group.day),
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              if (group.income > 0)
                Text(
                  '收 ¥${Money.yuan(group.income)}',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    color: c.mintText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (group.income > 0 && group.expense > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: c.ink3)),
                ),
              if (group.expense > 0)
                Text(
                  '支 ¥${Money.yuan(group.expense)}',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    color: c.coralText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < group.items.length; i++) ...[
                _TxTile(record: group.items[i]),
                if (i != group.items.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 70),
                    child: Divider(height: 1, color: c.border),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TxTile extends ConsumerWidget {
  const _TxTile({required this.record});

  final TxRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final catColor = Color(record.categoryColor);

    return Dismissible(
      key: ValueKey('tx-${record.row.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: c.coralDeep,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除这笔账？'),
                content: Text(
                  '${record.categoryName} ${Money.symbol(record.amountCents)}'
                  '${record.note.isEmpty ? '' : ' · ${record.note}'}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await ref
            .read(ledgerRepositoryProvider)
            .deleteTransaction(record.row.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => RecordSheet.show(context, initial: record),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SoftIcon(
                  icon: iconFor(record.categoryIconKey),
                  color: catColor,
                  size: 42,
                  iconSize: 21,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.categoryName,
                        style: TextStyle(
                          fontSize: AppFontSizes.md,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          record.accountName,
                          if (record.note.isNotEmpty) record.note,
                          DateLabels.time(record.occurredAt),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSizes.sm,
                          color: c.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  Money.signed(record.amountCents, isExpense: record.isExpense),
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w800,
                    color: record.isExpense ? c.ink : c.mintText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickEntries extends StatelessWidget {
  const _QuickEntries();

  /// (图标 key, 文案, 路由)；路由为空表示功能还没做。
  static const _items = <(String, String, String?)>[
    ('chart', '统计', '/stats'),
    ('asset', '资产', '/assets'),
    ('budget', '预算', '/budget'),
    ('calendar', '日历', '/calendar'),
    ('checkin', '签到', '/checkin'),
    ('store', '商店', '/store'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            for (final (key, label, route) in _items)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: route == null ? null : () => context.push(route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Icon(
                          iconFor(key),
                          size: 21,
                          color: route == null
                              ? c.ink3.withValues(alpha: 0.55)
                              : c.mintDeep,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: AppFontSizes.xs,
                            fontWeight: FontWeight.w600,
                            color: route == null ? c.ink3 : c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 46, color: c.ink3.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '还没有账目',
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w700,
              color: c.ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点下方的 ＋ 记第一笔，宠物就长大一点',
            style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: c.coralText),
            const SizedBox(height: AppSpacing.sm),
            Text('读取账目失败',
                style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w700,
                    color: c.ink)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3)),
          ],
        ),
      ),
    );
  }
}

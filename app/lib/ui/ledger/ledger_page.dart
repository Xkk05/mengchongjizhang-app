import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/money.dart';
import '../../data/db/tables.dart';
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
    final async = ref.watch(filteredTransactionsProvider);
    final selection = ref.watch(txSelectionProvider);

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
            SliverToBoxAdapter(
              child: selection.isEmpty
                  ? const _SearchFilterBar()
                  : _SelectionToolbar(
                      allIds: records.map((r) => r.row.id).toList(),
                    ),
            ),
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
        } else if (t.isIncome) {
          income += t.amountCents;
        }
        // 转账不计入收支，日合计不体现。
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
    final selection = ref.watch(txSelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final isSelected = selection.contains(record.row.id);

    return Dismissible(
      key: ValueKey('tx-${record.row.id}'),
      direction: inSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
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
        color:
            isSelected ? c.coral.withValues(alpha: 0.06) : Colors.transparent,
        child: InkWell(
          onTap: () {
            if (inSelectionMode) {
              ref.read(txSelectionProvider.notifier).toggle(record.row.id);
            } else {
              RecordSheet.show(context, initial: record);
            }
          },
          onLongPress: () =>
              ref.read(txSelectionProvider.notifier).toggle(record.row.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (inSelectionMode) ...[
                  _SelectionDot(selected: isSelected),
                  const SizedBox(width: AppSpacing.sm),
                ],
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
                          if (record.isTransfer)
                            '${record.accountName} → ${record.toAccountName ?? '?'}'
                          else
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
                  record.isTransfer
                      ? Money.symbol(record.amountCents)
                      : Money.signed(record.amountCents,
                          isExpense: record.isExpense),
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w800,
                    color: record.isTransfer
                        ? c.ink2
                        : (record.isExpense ? c.ink : c.mintText),
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

class _SearchFilterBar extends ConsumerStatefulWidget {
  const _SearchFilterBar();

  @override
  ConsumerState<_SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<_SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(txFilterProvider).query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filter = ref.watch(txFilterProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: TextField(
                controller: _controller,
                onChanged: (v) =>
                    ref.read(txFilterProvider.notifier).setQuery(v),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink),
                decoration: InputDecoration(
                  hintText: '搜索分类 / 账户 / 备注',
                  hintStyle:
                      TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: c.ink3),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _FilterButton(
            active: filter.isActive,
            onTap: () => _FilterSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? c.mint.withValues(alpha: 0.14) : c.surface2,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: active ? Border.all(color: c.mint, width: 1.4) : null,
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 20,
          color: active ? c.mintDeep : c.ink2,
        ),
      ),
    );
  }
}

String _kindLabel(TxKind k) => switch (k) {
      TxKind.expense => '支出',
      TxKind.income => '收入',
      TxKind.transfer => '转账',
    };

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    final filter = ref.watch(txFilterProvider);
    final categories = (ref.watch(allCategoriesProvider).value ?? const [])
        .where((x) => x.kind != TxKind.transfer)
        .toList();
    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Text(
                    '筛选',
                    style: TextStyle(
                      fontSize: AppFontSizes.xl,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: () =>
                          ref.read(txFilterProvider.notifier).clear(),
                      child: Text('清除',
                          style: TextStyle(color: c.coralText)),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20, color: c.ink2),
                  ),
                ],
              ),
            ),
            _section('类型', c),
            _chipWrap(c, children: [
              for (final k in TxKind.values)
                ChoiceChip(
                  label: Text(_kindLabel(k)),
                  selected: filter.kinds.contains(k),
                  onSelected: (_) =>
                      ref.read(txFilterProvider.notifier).toggleKind(k),
                  selectedColor: c.mint.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: filter.kinds.contains(k) ? c.mint : c.border,
                  ),
                  showCheckmark: false,
                ),
            ]),
            _section('分类', c),
            _chipWrap(c, children: [
              for (final cat in categories)
                ChoiceChip(
                  label: Text(cat.name),
                  selected: filter.categoryIds.contains(cat.id),
                  onSelected: (_) => ref
                      .read(txFilterProvider.notifier)
                      .toggleCategory(cat.id),
                  selectedColor: c.mint.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: filter.categoryIds.contains(cat.id)
                        ? c.mint
                        : c.border,
                  ),
                  showCheckmark: false,
                ),
            ]),
            _section('账户', c),
            _chipWrap(c, children: [
              for (final a in accounts)
                ChoiceChip(
                  label: Text(a.name),
                  selected: filter.accountIds.contains(a.id),
                  onSelected: (_) => ref
                      .read(txFilterProvider.notifier)
                      .toggleAccount(a.id),
                  selectedColor: c.mint.withValues(alpha: 0.14),
                  side: BorderSide(
                    color:
                        filter.accountIds.contains(a.id) ? c.mint : c.border,
                  ),
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ),
            SizedBox(height: media.padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppFontSizes.sm,
          fontWeight: FontWeight.w700,
          color: c.ink2,
        ),
      ),
    );
  }

  Widget _chipWrap(AppColors c, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: children,
      ),
    );
  }
}

class _SelectionToolbar extends ConsumerWidget {
  const _SelectionToolbar({required this.allIds});

  final List<int> allIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selection = ref.watch(txSelectionProvider);
    final allSelected =
        allIds.isNotEmpty && allIds.every((id) => selection.contains(id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: c.coral.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Text(
              '已选 ${selection.length} 笔',
              style: TextStyle(
                fontSize: AppFontSizes.md,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                final notifier = ref.read(txSelectionProvider.notifier);
                if (allSelected) {
                  notifier.clear();
                } else {
                  notifier.addAll(allIds);
                }
              },
              child: Text(allSelected ? '取消全选' : '全选',
                  style: const TextStyle(fontSize: AppFontSizes.sm)),
            ),
            FilledButton(
              onPressed: () => _batchDelete(context, ref, selection),
              style: FilledButton.styleFrom(
                backgroundColor: c.coral,
                foregroundColor: c.onCoral,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('删除'),
            ),
            IconButton(
              onPressed: () => ref.read(txSelectionProvider.notifier).clear(),
              icon: Icon(Icons.close_rounded, size: 20, color: c.ink2),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchDelete(
      BuildContext context, WidgetRef ref, Set<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除选中的 ${ids.length} 笔账目？'),
        content: const Text('删除后不可恢复。'),
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
    );
    if (ok != true) return;

    await ref
        .read(ledgerRepositoryProvider)
        .deleteTransactions(ids.toList());
    ref.read(txSelectionProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${ids.length} 笔')),
      );
    }
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.coral : Colors.transparent,
        border: Border.all(
          color: selected ? c.coral : c.ink3.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 13, color: c.onCoral)
          : null,
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

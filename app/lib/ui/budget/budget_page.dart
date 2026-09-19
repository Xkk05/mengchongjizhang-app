import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/budget/budget_plan.dart';
import '../../state/budget_providers.dart';
import '../../state/ledger_providers.dart';
import '../../state/month_provider.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../common/month_bar.dart';

/// 预算页：月度总预算 + 分类专项预算，超支高亮提醒。
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final plan = ref.watch(budgetPlanProvider);
    final loading = ref.watch(budgetRowsProvider).isLoading;

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('预算'),
        backgroundColor: c.pageBg,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BudgetSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('设置预算'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
        children: [
          const MonthBar(),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _OverallCard(line: plan.overall),
            const SizedBox(height: AppSpacing.lg),
            _CategorySection(lines: plan.lines),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 总预算

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.line});

  final BudgetLine? line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = line;

    if (l == null) {
      return AppCard(
        child: Column(
          children: [
            Icon(Icons.savings_outlined,
                size: 34, color: c.ink3.withValues(alpha: 0.45)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '本月还没有总预算',
              style: TextStyle(
                fontSize: AppFontSizes.md,
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点右下角「设置预算」定一个上限',
              style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
            ),
          ],
        ),
      );
    }

    final over = l.isOver;
    final accent = over ? c.coral : c.mint;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '总预算',
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              if (over) ...[
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: _OverBadge(overBy: -l.remainingCents)),
              ],
              const Spacer(),
              Text(
                '${(l.ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥${Money.yuan(l.spentCents)}',
                  style: TextStyle(
                    fontSize: AppFontSizes.xxl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ ¥${Money.yuan(l.limitCents)}',
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: l.barValue,
              minHeight: 8,
              backgroundColor: c.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            over
                ? '已超出 ¥${Money.yuan(-l.remainingCents)}'
                : '还可用 ¥${Money.yuan(l.remainingCents)}',
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: FontWeight.w600,
              color: over ? c.coralText : c.mintText,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverBadge extends StatelessWidget {
  const _OverBadge({required this.overBy});

  final int overBy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.coral.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '超支 ¥${Money.yuan(overBy)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppFontSizes.xxs,
          fontWeight: FontWeight.w800,
          color: c.coralText,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 分类预算

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.lines});

  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Row(
            children: [
              Text(
                '分类预算',
                style: TextStyle(
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              if (lines.isNotEmpty)
                Text(
                  '${lines.length} 项',
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
            ],
          ),
        ),
        if (lines.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '还没有分类预算，给爱超支的分类单独设个上限吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  _BudgetTile(line: lines[i]),
                  if (i != lines.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 62),
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

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final color = Color(line.colorValue);
    final accent = line.isOver ? c.coral : color;

    return Dismissible(
      key: ValueKey('budget-${line.categoryId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: c.coralDeep,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => BudgetSheet.show(context, initial: line),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SoftIcon(icon: iconFor(line.iconKey), color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSizes.md,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '¥${Money.yuan(line.spentCents)}',
                            style: TextStyle(
                              fontSize: AppFontSizes.md,
                              fontWeight: FontWeight.w800,
                              color: line.isOver ? c.coralText : c.ink,
                            ),
                          ),
                          Text(
                            ' / ¥${Money.yuan(line.limitCents)}',
                            style: TextStyle(
                                fontSize: AppFontSizes.xs, color: c.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              child: LinearProgressIndicator(
                                value: line.barValue,
                                minHeight: 5,
                                backgroundColor: c.surface3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${(line.ratio * 100).toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: AppFontSizes.xs,
                                fontWeight: FontWeight.w700,
                                color: line.isOver ? c.coralText : c.ink3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (line.isOver) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 13, color: c.coralText),
                            const SizedBox(width: 4),
                            Text(
                              '超支 ¥${Money.yuan(-line.remainingCents)}',
                              style: TextStyle(
                                fontSize: AppFontSizes.xxs,
                                fontWeight: FontWeight.w700,
                                color: c.coralText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 删预算只删上限，不动账目。返回 false 让数据库流驱动列表刷新。
  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${line.name}」预算？'),
        content: const Text('只删除预算上限，不影响已记录的账目。'),
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
    if (ok != true) return false;

    final rows = ref.read(budgetRowsProvider).value ?? const <BudgetRow>[];
    for (final r in rows) {
      if (r.categoryId == line.categoryId) {
        await ref.read(ledgerRepositoryProvider).deleteBudget(r.id);
        break;
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------- 设置预算

/// 预算设置面板：选分类（含总预算）+ 填金额。
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, this.initial});

  final BudgetLine? initial;

  static Future<void> show(BuildContext context, {BudgetLine? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetSheet(initial: initial),
    );
  }

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  /// 分类选择：null 表示总预算。
  late int? _categoryId = widget.initial?.categoryId;
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : Money.yuan(widget.initial!.limitCents, grouped: false),
  );
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final limitCents = Money.parseYuan(_amount.text) ?? 0;
    if (limitCents <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入大于 0 的金额')));
      return;
    }

    setState(() => _saving = true);
    try {
      final month = ref.read(selectedMonthProvider);
      await ref.read(ledgerRepositoryProvider).setBudget(
            yearMonth: yearMonthOf(month),
            categoryId: _categoryId,
            limitCents: limitCents,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('预算已保存')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    final catsAsync = ref.watch(expenseCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
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
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  '设置预算',
                  style: TextStyle(
                    fontSize: AppFontSizes.xl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.md, bottom: AppSpacing.xs),
                child: Text(
                  '预算范围',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _TargetChip(
                      label: '总预算',
                      icon: Icons.savings_rounded,
                      color: c.mint,
                      selected: _categoryId == null,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                    ...catsAsync.maybeWhen(
                      data: (cats) => cats.map(
                        (cat) => _TargetChip(
                          label: cat.name,
                          icon: iconFor(cat.iconKey),
                          color: Color(cat.colorValue),
                          selected: _categoryId == cat.id,
                          onTap: () => setState(() => _categoryId = cat.id),
                        ),
                      ),
                      orElse: () => const <Widget>[],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: Text(
                  '每月上限',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _amount,
                  autofocus: widget.initial == null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: AppFontSizes.xxl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '¥ ',
                    hintText: '0.00',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('保 存'),
                  ),
                ),
              ),
              SizedBox(height: media.padding.bottom + AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : c.surface2,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? color : c.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? color : c.ink2),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.sm,
                fontWeight: FontWeight.w700,
                color: selected ? c.ink : c.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

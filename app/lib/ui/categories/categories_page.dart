import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../state/ledger_providers.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';

/// 分类管理页：支出 / 收入两套分类，可新增、改名、换图标颜色，删除非内置分类。
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(allCategoriesProvider);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('分类管理'),
        backgroundColor: c.pageBg,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategorySheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加分类'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取分类失败：$e')),
        data: (cats) {
          final expenses =
              cats.where((x) => x.kind == TxKind.expense).toList();
          final incomes = cats.where((x) => x.kind == TxKind.income).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
            children: [
              _Section(title: '支出分类', cats: expenses),
              const SizedBox(height: AppSpacing.lg),
              _Section(title: '收入分类', cats: incomes),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.cats});

  final String title;
  final List<Category> cats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            '$title · ${cats.length}',
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w800,
              color: c.ink,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    '暂无分类',
                    style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                  ),
                )
              else
                for (var i = 0; i < cats.length; i++) ...[
                  _CategoryTile(category: cats[i]),
                  if (i != cats.length - 1)
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

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final color = Color(category.colorValue);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => CategorySheet.show(context, initial: category),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SoftIcon(icon: iconFor(category.iconKey), color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (category.isBuiltIn)
                Text(
                  '内置',
                  style: TextStyle(fontSize: AppFontSizes.xs, color: c.ink3),
                )
              else
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: c.ink3),
                  onPressed: () => _delete(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${category.name}」？'),
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

    final err =
        await ref.read(ledgerRepositoryProvider).deleteCategory(category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? '分类已删除')),
    );
  }
}

// ---------------------------------------------------------------- 新增 / 编辑

/// 分类编辑面板：类型（新增时）/ 名称 / 图标 / 颜色。
class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({super.key, this.initial});

  final Category? initial;

  static Future<void> show(BuildContext context, {Category? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategorySheet(initial: initial),
    );
  }

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  static const _icons = <String>[
    'fork', 'bus', 'bag', 'game', 'home', 'paw', 'heart', 'more',
    'pay', 'job', 'invest', 'gift', 'scan', 'robot',
  ];

  static const _palette = <int>[
    0xFFE2584A,
    0xFF1677FF,
    0xFF9B59D0,
    0xFFF0A11A,
    0xFF2E9E77,
    0xFFE86A9A,
    0xFFE2557B,
    0xFF7A8B84,
  ];

  bool get _isEdit => widget.initial != null;

  late TxKind _kind = widget.initial?.kind ?? TxKind.expense;
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late String _iconKey = widget.initial?.iconKey ?? _icons.first;
  late int _colorValue = widget.initial?.colorValue ?? _palette.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('请填写分类名称');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      if (_isEdit) {
        await repo.updateCategory(
          id: widget.initial!.id,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
      } else {
        await repo.addCategory(
          kind: _kind,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(_isEdit ? '分类已更新' : '分类已添加');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('保存失败：$e');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);

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
                  _isEdit ? '编辑分类' : '添加分类',
                  style: TextStyle(
                    fontSize: AppFontSizes.xl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              if (!_isEdit) _kindRow(c),
              _label('名称', c),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _name,
                  maxLength: 20,
                  style: TextStyle(fontSize: AppFontSizes.md, color: c.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '如：宠物医疗',
                    counterText: '',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              _label('图标', c),
              _chipWrap(
                c,
                children: [
                  for (final k in _icons)
                    _PickChip(
                      selected: k == _iconKey,
                      color: Color(_colorValue),
                      onTap: () => setState(() => _iconKey = k),
                      child: Icon(
                        iconFor(k),
                        size: 18,
                        color: k == _iconKey ? Colors.white : c.ink2,
                      ),
                    ),
                ],
              ),
              _label('颜色', c),
              _chipWrap(
                c,
                children: [
                  for (final v in _palette)
                    _PickChip(
                      selected: v == _colorValue,
                      color: Color(v),
                      onTap: () => setState(() => _colorValue = v),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(v),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
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

  Widget _kindRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              selected: _kind == TxKind.expense,
              onSelected: (_) => setState(() => _kind = TxKind.expense),
              label: const Text('支出'),
              selectedColor: c.coral.withValues(alpha: 0.14),
              side: BorderSide(
                color: _kind == TxKind.expense ? c.coral : c.border,
              ),
              showCheckmark: false,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ChoiceChip(
              selected: _kind == TxKind.income,
              onSelected: (_) => setState(() => _kind = TxKind.income),
              label: const Text('收入'),
              selectedColor: c.mint.withValues(alpha: 0.14),
              side: BorderSide(
                color: _kind == TxKind.income ? c.mint : c.border,
              ),
              showCheckmark: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
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

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : c.surface2,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? color : c.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/money.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../state/ledger_providers.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';

/// 快速记账面板：类型切换 + 分类格 + 金额键盘 + 账户选择 + 常驻保存键。
class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key, this.initial, this.initialKind});

  final TxRecord? initial;
  final TxKind? initialKind;

  static Future<void> show(
    BuildContext context, {
    TxRecord? initial,
    TxKind? initialKind,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordSheet(initial: initial, initialKind: initialKind),
    );
  }

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  late TxKind _kind = widget.initial?.row.kind ??
      widget.initialKind ??
      TxKind.expense;
  late String _amount = widget.initial == null
      ? ''
      : Money.yuan(widget.initial!.amountCents, grouped: false);
  late DateTime _occurredAt = widget.initial?.occurredAt ?? DateTime.now();
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');

  int? _categoryId;
  int? _accountId;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initial?.row.categoryId;
    _accountId = widget.initial?.row.accountId;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _amountCents => Money.parseYuan(_amount) ?? 0;

  bool get _canSave =>
      !_saving && _amountCents > 0 && _categoryId != null && _accountId != null;

  void _onKey(String k) {
    setState(() {
      if (k == 'del') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
        return;
      }
      if (k == '.') {
        if (_amount.contains('.')) return;
        _amount = _amount.isEmpty ? '0.' : '$_amount.';
        return;
      }
      // 最多两位小数
      final dot = _amount.indexOf('.');
      if (dot >= 0 && _amount.length - dot > 2) return;
      if (_amount == '0') {
        _amount = k;
      } else {
        if (_amount.length >= 10) return;
        _amount = '$_amount$k';
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final repo = ref.read(ledgerRepositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    try {
      if (_isEdit) {
        await repo.updateTransaction(
          id: widget.initial!.row.id,
          accountId: _accountId!,
          categoryId: _categoryId!,
          kind: _kind,
          amountCents: _amountCents,
          occurredAt: _occurredAt,
          note: _note.text,
        );
      } else {
        if (ledgerId == null) {
          throw StateError('账本尚未初始化完成');
        }
        await repo.addTransaction(
          ledgerId: ledgerId,
          accountId: _accountId!,
          categoryId: _categoryId!,
          kind: _kind,
          amountCents: _amountCents,
          occurredAt: _occurredAt,
          note: _note.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '已更新' : '记好啦 · 宠物 +10 经验，金币 +2'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);

    // 键盘弹起时压缩面板高度，保证键盘不把面板顶出屏幕。
    final sheetHeight =
        (media.size.height * 0.82 - media.viewInsets.bottom)
            .clamp(360.0, media.size.height * 0.92);

    final categoriesAsync = ref.watch(
      _kind == TxKind.expense
          ? expenseCategoriesProvider
          : incomeCategoriesProvider,
    );
    final accountsAsync = ref.watch(accountsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            _header(c),
            const Divider(height: 1),
            Expanded(
              child: categoriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('分类加载失败：$e')),
                data: (cats) => _categoryGrid(c, cats),
              ),
            ),
            _amountRow(c),
            _noteRow(c),
            accountsAsync.when(
              loading: () => const SizedBox(height: 42),
              error: (e, _) => const SizedBox(height: 42),
              data: (accounts) => _accountRow(c, accounts),
            ),
            _keypad(c),
            SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _header(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          _KindToggle(
            kind: _kind,
            onChanged: (k) => setState(() {
              _kind = k;
              _categoryId = null;
            }),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 16),
            label: Text(
              DateLabels.groupLabel(_occurredAt) == '今天' ||
                      DateLabels.groupLabel(_occurredAt) == '昨天'
                  ? DateLabels.groupLabel(_occurredAt)
                  : DateLabels.fullDate(_occurredAt),
              style: const TextStyle(fontSize: AppFontSizes.sm),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: c.ink2,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
  }

  Widget _categoryGrid(AppColors c, List<Category> cats) {
    if (cats.isEmpty) {
      return Center(
        child: Text('暂无分类', style: TextStyle(color: c.ink3)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.05,
      ),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final selected = cat.id == _categoryId;
        final color = Color(cat.colorValue);
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: () => setState(() => _categoryId = cat.id),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: selected
                      ? Border.all(color: color.withValues(alpha: 0.4), width: 2)
                      : null,
                ),
                child: Icon(
                  iconFor(cat.iconKey),
                  size: 20,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSizes.xs,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? c.ink : c.ink2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _amountRow(AppColors c) {
    final income = _kind == TxKind.income;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '¥',
            style: TextStyle(
              fontSize: AppFontSizes.xl,
              fontWeight: FontWeight.w800,
              color: income ? c.mintText : c.coralText,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _amount.isEmpty ? '0.00' : _amount,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSizes.display,
                fontWeight: FontWeight.w800,
                color: _amount.isEmpty
                    ? c.ink3
                    : (income ? c.mintText : c.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: TextField(
        controller: _note,
        textInputAction: TextInputAction.done,
        maxLength: 40,
        style: TextStyle(fontSize: AppFontSizes.md, color: c.ink),
        decoration: const InputDecoration(
          hintText: '添加备注…',
          counterText: '',
          prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _accountRow(AppColors c, List<Account> accounts) {
    if (accounts.isEmpty) return const SizedBox(height: 42);
    // 首次进入默认选第一个账户
    _accountId ??= accounts.first.id;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final a = accounts[i];
          final selected = a.id == _accountId;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _accountId = a.id),
            avatar: Icon(
              iconFor(a.iconKey),
              size: 15,
              color: selected ? c.coralText : c.ink2,
            ),
            label: Text(
              a.name,
              style: TextStyle(
                fontSize: AppFontSizes.sm,
                fontWeight: FontWeight.w600,
                color: selected ? c.coralText : c.ink2,
              ),
            ),
            selectedColor: c.coral.withValues(alpha: 0.12),
            backgroundColor: c.surface2,
            side: BorderSide(
              color: selected ? c.coral : c.border,
              width: selected ? 1.4 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _keypad(AppColors c) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: c.surface2,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: onTap ?? () => _onKey(label),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 20, color: c.ink)
                      : Text(
                          label,
                          style: TextStyle(
                            fontSize: AppFontSizes.xxl,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(children: [
                  key('1'),
                  key('2'),
                  key('3'),
                ]),
                Row(children: [
                  key('4'),
                  key('5'),
                  key('6'),
                ]),
                Row(children: [
                  key('7'),
                  key('8'),
                  key('9'),
                ]),
                Row(children: [
                  key('.'),
                  key('0'),
                  key('.', icon: Icons.backspace_outlined,
                      onTap: () => _onKey('del')),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 2),
          _saveButton(c),
        ],
      ),
    );
  }

  /// 常驻保存键：占据键盘整列高度，任何状态下都清晰可见——
  /// 可用时是珊瑚红渐变实心键，不可用时是珊瑚红浅底虚键，绝不隐形。
  Widget _saveButton(AppColors c) {
    final enabled = _canSave;
    return SizedBox(
      width: 88,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.coral, c.coralDeep],
                    )
                  : null,
              color: enabled ? null : c.coral.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: c.coral.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: enabled ? _save : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_saving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    Icon(
                      Icons.check_rounded,
                      size: 24,
                      color: enabled ? c.onCoral : c.coralText,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '保 存',
                      style: TextStyle(
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: enabled ? c.onCoral : c.coralText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final TxKind kind;
  final ValueChanged<TxKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget seg(String label, TxKind k) {
      final on = k == kind;
      final accent = k == TxKind.expense ? c.coral : c.mint;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(k);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: on ? c.onCoral : c.ink2,
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
        mainAxisSize: MainAxisSize.min,
        children: [seg('支出', TxKind.expense), seg('收入', TxKind.income)],
      ),
    );
  }
}

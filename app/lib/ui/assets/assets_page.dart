import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/money.dart';
import '../../domain/assets/account_balance.dart';
import '../../state/asset_providers.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';

/// 资产页：净资产合计 + 账户列表（余额随流水实时派生）。
class AssetsPage extends ConsumerWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(accountsWithBalanceProvider);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('资产'),
        backgroundColor: c.pageBg,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加账户'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取账户失败：$e')),
        data: (accounts) => ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
          children: [
            _NetWorthCard(accounts: accounts),
            const SizedBox(height: AppSpacing.lg),
            if (accounts.isEmpty)
              const _EmptyAccounts()
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
                child: Text(
                  '账户明细',
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
                    for (var i = 0; i < accounts.length; i++) ...[
                      _AccountTile(account: accounts[i]),
                      if (i != accounts.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 62),
                          child: Divider(height: 1, color: c.border),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard({required this.accounts});

  final List<AccountBalance> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final netWorth = ref.watch(netWorthProvider);
    final inflow = accounts.fold<int>(0, (s, a) => s + a.flowCents);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.mint.withValues(alpha: 0.28), c.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 16, color: c.mintDeep),
              const SizedBox(width: 6),
              Text(
                '净资产',
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  fontWeight: FontWeight.w600,
                  color: c.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            child: Text(
              '¥${Money.yuan(netWorth)}',
              style: TextStyle(
                fontSize: AppFontSizes.display,
                fontWeight: FontWeight.w800,
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${accounts.length} 个账户 · 流水净额 '
            '${inflow < 0 ? '-' : '+'}¥${Money.yuan(inflow.abs())}',
            style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final AccountBalance account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final color = Color(account.colorValue);
    final negative = account.balanceCents < 0;

    return Dismissible(
      key: ValueKey('account-${account.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: c.coralDeep,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) async {
        await ref.read(ledgerRepositoryProvider).deleteAccount(account.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('账户已删除')));
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AccountSheet.show(context, initial: account),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SoftIcon(icon: iconFor(account.iconKey), color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
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
                        '初始 ¥${Money.yuan(account.initialCents)}'
                        ' · ${account.txCount} 笔',
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
                  '${negative ? '-' : ''}¥${Money.yuan(account.balanceCents.abs())}',
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w800,
                    color: negative ? c.coralText : c.ink,
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

  /// 删账户会级联删除其账目，必须让用户看清代价再确认。
  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${account.name}」？'),
        content: Text(
          account.txCount == 0
              ? '该账户下没有账目，删除后不可恢复。'
              : '该账户下的 ${account.txCount} 笔账目会一并删除，且不可恢复。',
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
    );
    return ok ?? false;
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.savings_outlined,
              size: 44, color: c.ink3.withValues(alpha: 0.45)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '还没有账户',
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w700,
              color: c.ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加一个账户，记账时就能选它了',
            style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 新增 / 编辑

/// 账户编辑面板：名称 / 图标 / 颜色 / 初始余额。
class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key, this.initial});

  final AccountBalance? initial;

  static Future<void> show(BuildContext context, {AccountBalance? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  static const _icons = <String>[
    'wallet',
    'alipay',
    'wechat',
    'bank',
    'pay',
    'invest',
    'more',
  ];

  static const _palette = <int>[
    0xFF2E9E77,
    0xFF1677FF,
    0xFF07C160,
    0xFFD2453A,
    0xFF9B59D0,
    0xFFF0A11A,
    0xFFE86A9A,
    0xFF7A8B84,
  ];

  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _balance = TextEditingController(
    text: widget.initial == null
        ? ''
        : Money.yuan(widget.initial!.initialCents, grouped: false),
  );

  late String _iconKey = widget.initial?.iconKey ?? _icons.first;
  late int _colorValue = widget.initial?.colorValue ?? _palette.first;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('请填写账户名称');
      return;
    }
    final initialCents = Money.parseYuan(_balance.text) ?? 0;

    setState(() => _saving = true);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      if (_isEdit) {
        await repo.updateAccount(
          id: widget.initial!.id,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
          initialBalanceCents: initialCents,
        );
      } else {
        await repo.addAccount(
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
          initialBalanceCents: initialCents,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '账户已更新' : '账户已添加')),
      );
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
                  _isEdit ? '编辑账户' : '添加账户',
                  style: TextStyle(
                    fontSize: AppFontSizes.xl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              _label('名称', c),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _name,
                  maxLength: 20,
                  style: TextStyle(fontSize: AppFontSizes.md, color: c.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '如：招商银行',
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
              _label('初始余额', c, hint: '建档时的余额，之后随流水自动变化'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _balance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: TextStyle(fontSize: AppFontSizes.md, color: c.ink),
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

  Widget _label(String text, AppColors c, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: FontWeight.w700,
              color: c.ink2,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppFontSizes.xxs, color: c.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipWrap(AppColors c, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: children),
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

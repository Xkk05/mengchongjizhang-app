import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/money.dart';
import '../../domain/rules/decor_rules.dart';
import '../../domain/rules/pet_rules.dart';
import '../../state/asset_providers.dart';
import '../../state/ledger_providers.dart';
import '../../state/providers.dart';
import '../../state/shop_providers.dart';
import '../../state/theme_provider.dart';
import '../common/app_card.dart';
import '../common/app_icons.dart';
import '../home/pet_view.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pet = ref.watch(petStateProvider).value;
    final accounts = ref.watch(accountsWithBalanceProvider).value ?? const [];
    final themeMode = ref.watch(themeModeProvider);

    final level = pet?.level ?? 1;
    final exp = pet?.exp ?? 0;
    final coin = pet?.coin ?? 0;
    final hungerPercent =
        PetRules.percentOf(pet?.hunger ?? 0, PetRules.maxHunger);
    final netWorth = ref.watch(netWorthProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
      children: [
        // 宠物养成卡
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.mint.withValues(alpha: 0.22),
                c.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              BreathingPet(
                size: 92,
                mood: pet?.mood ?? 70,
                hunger: pet?.hunger ?? 70,
                level: level,
                enabled: false,
                action: PetRules.actionFor(
                  mood: pet?.mood ?? 70,
                  hunger: pet?.hunger ?? 70,
                ),
                head: DecorRules.accessoryFor(
                    ref.watch(equippedHeadProvider)?.item.code),
                neck: DecorRules.accessoryFor(
                    ref.watch(equippedNeckProvider)?.item.code),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pet?.name ?? '团团',
                          style: TextStyle(
                            fontSize: AppFontSizes.xl,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.coral.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            'Lv.$level',
                            style: TextStyle(
                              fontSize: AppFontSizes.xs,
                              fontWeight: FontWeight.w800,
                              color: c.coralText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PetRules.stageName(level),
                      style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StatBar(
                      icon: Icons.auto_awesome_rounded,
                      label: '经验',
                      value: PetRules.levelProgress(level: level, exp: exp),
                      text: '$exp / ${PetRules.expNeeded(level)}',
                      color: c.coral,
                    ),
                    const SizedBox(height: 6),
                    _StatBar(
                      icon: Icons.restaurant_rounded,
                      label: '饱食',
                      value: hungerPercent / 100,
                      text: '$hungerPercent%',
                      color: c.mint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // 金币 + 喂食
        AppCard(
          child: Row(
            children: [
              SoftIcon(
                icon: Icons.monetization_on_rounded,
                color: c.onWarm2,
                size: 42,
                iconSize: 21,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$coin 金币',
                      style: TextStyle(
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      '每记一笔账得 2 金币，喂食可涨经验',
                      style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        color: c.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _feed(context, ref),
                child: const Text('喂食 · 20'),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // 养成入口：签到 / 商店 / 背包
        AppCard(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              _QuickTile(
                iconKey: 'checkin',
                label: '签到',
                hint: '领金币',
                color: c.mint,
                onTap: () => context.push('/checkin'),
              ),
              _QuickTile(
                iconKey: 'store',
                label: '商店',
                hint: '花金币',
                color: c.coral,
                onTap: () => context.push('/store'),
              ),
              _QuickTile(
                iconKey: 'backpack',
                label: '背包',
                hint: '用道具',
                color: c.onWarm2,
                onTap: () => context.push('/backpack'),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          '我的资产',
          trailing: '¥${Money.yuan(netWorth)}',
          onTap: () => context.push('/assets'),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SoftIcon(
                    icon: iconFor(a.iconKey),
                    color: Color(a.colorValue),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      a.name,
                      style: TextStyle(
                        fontSize: AppFontSizes.md,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
                  Text(
                    '¥${Money.yuan(a.balanceCents)}',
                    style: TextStyle(
                      fontSize: AppFontSizes.md,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.lg),
        _SectionTitle('设置'),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
                secondary: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: c.mintDeep,
                ),
                title: Text(
                  '深色模式',
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),
              ListTile(
                dense: true,
                leading:
                    Icon(Icons.category_rounded, size: 20, color: c.mintDeep),
                title: Text(
                  '分类管理',
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                subtitle: Text(
                  '新增 / 编辑支出与收入分类',
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.ink3),
                onTap: () => context.push('/categories'),
              ),
              Divider(height: 1, color: c.border),
              ListTile(
                dense: true,
                leading: Icon(Icons.import_export_rounded,
                    size: 20, color: c.mintDeep),
                title: Text(
                  '数据管理',
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                subtitle: Text(
                  '导出 / 导入账单 CSV',
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.ink3),
                onTap: () => context.push('/data'),
              ),
              Divider(height: 1, color: c.border),
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: '版本',
                value: 'v0.9.4 · Flutter',
              ),
              Divider(height: 1, color: c.border),
              _InfoTile(
                icon: Icons.shield_outlined,
                label: '隐私锁',
                value: '规划中',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _feed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(ledgerRepositoryProvider).feedPet();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? '吃饱啦，经验 +6' : '金币不够，先记几笔账吧')),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing, this.onTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = Row(
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
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w700,
              color: c.mintText,
            ),
          ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.ink3),
        ],
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
    );
  }
}

/// 养成三入口：签到 / 商店 / 背包。
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.iconKey,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final String iconKey;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              SoftIcon(icon: iconFor(iconKey), color: color, size: 40),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                style: TextStyle(fontSize: AppFontSizes.xxs, color: c.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: c.mintDeep),
      title: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSizes.md,
          fontWeight: FontWeight.w600,
          color: c.ink,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double value;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 13, color: c.ink3),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: AppFontSizes.xs, color: c.ink3),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: c.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: AppFontSizes.xs,
            color: c.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

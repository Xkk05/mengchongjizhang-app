import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/money.dart';
import '../../../domain/rules/decor_rules.dart';
import '../../../domain/rules/pet_rules.dart';
import '../../../state/ledger_providers.dart';
import '../../../state/shop_providers.dart';
import '../../common/app_icons.dart';
import '../../home/pet_view.dart';

/// 主页场景：天空背景 + 居中宠物 + 左右悬浮入口 + 金币/经验。
class SceneHeader extends ConsumerWidget {
  const SceneHeader({super.key});

  // 场景高度只需容纳宠物与顶部信息；悬浮入口锚定底边向上排，
  // 按钮随系统字体放大只会往上长，永远不会溢出场景底边。余额卡
  // 排在场景下方（不再上叠），二者天然无重叠。
  static const double height = 344;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pet = ref.watch(petStateProvider).value;

    final level = pet?.level ?? 1;
    final exp = pet?.exp ?? 0;
    final coin = pet?.coin ?? 0;
    final progress = PetRules.levelProgress(level: level, exp: exp);

    // 已装备的装扮 → 外观（头饰 / 颈部 / 场景皮肤）。
    final head = DecorRules.accessoryFor(
        ref.watch(equippedHeadProvider)?.item.code);
    final neck = DecorRules.accessoryFor(
        ref.watch(equippedNeckProvider)?.item.code);
    final skin =
        DecorRules.skinFor(ref.watch(equippedSceneProvider)?.item.code);

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadii.xl),
              ),
              child: SceneBackground(
                skin: skin,
                colors: SceneColors(
                  top: c.sceneTop,
                  mid: c.sceneMid,
                  bottom: c.sceneBottom,
                  hill: c.mint.withValues(alpha: 0.35),
                  hillDark: c.mint.withValues(alpha: 0.55),
                  grass: c.mint.withValues(alpha: 0.32),
                ),
              ),
            ),
          ),

          // 顶部：账本名 + 金币
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            child: Row(
              children: [
                _GlassChip(
                  icon: Icons.menu_book_rounded,
                  label: '日常账本',
                ),
                const Spacer(),
                _GlassChip(
                  icon: Icons.monetization_on_rounded,
                  label: '$coin 金币',
                  highlight: true,
                ),
              ],
            ),
          ),

          // 居中宠物
          Positioned(
            left: 0,
            right: 0,
            top: 62,
            child: Column(
              children: [
                BreathingPet(
                  size: 132,
                  mood: pet?.mood ?? 70,
                  hunger: pet?.hunger ?? 70,
                  level: level,
                  action: PetRules.actionFor(
                    mood: pet?.mood ?? 70,
                    hunger: pet?.hunger ?? 70,
                    hour: DateTime.now().hour,
                  ),
                  head: head,
                  neck: neck,
                ),
                const SizedBox(height: AppSpacing.xs),
                _LevelBadge(level: level, progress: progress),
              ],
            ),
          ),

          // 左侧悬浮入口：锚定场景底部向上排——按钮随系统字体放大只会往上长，
          // 永远不会再溢出场景底边被余额卡压住（top 定位时字体一大就出事）。
          Positioned(
            left: AppSpacing.sm,
            bottom: 64,
            child: Column(
              children: [
                _DockButton(
                  iconKey: 'chart',
                  label: '统计',
                  onTap: () => context.push('/stats'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DockButton(
                  iconKey: 'budget',
                  label: '预算',
                  onTap: () => context.push('/budget'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DockButton(
                  iconKey: 'calendar',
                  label: '日历',
                  onTap: () => context.push('/calendar'),
                ),
              ],
            ),
          ),

          // 右侧悬浮入口
          Positioned(
            right: AppSpacing.sm,
            bottom: 64,
            child: Column(
              children: [
                _DockButton(
                  iconKey: 'store',
                  label: '商店',
                  onTap: () => context.push('/store'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DockButton(
                  iconKey: 'backpack',
                  label: '背包',
                  onTap: () => context.push('/backpack'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DockButton(
                  iconKey: 'checkin',
                  label: '签到',
                  onTap: () => context.push('/checkin'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = highlight ? c.onWarm1 : c.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? c.goldSoft.withValues(alpha: 0.92)
            : c.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.surface.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            'Lv.$level · ${PetRules.stageName(level)}',
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 92,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: c.surface.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(c.coral),
            ),
          ),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.iconKey,
    required this.label,
    this.onTap,
  });

  final String iconKey;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: onTap == null ? '$label · 规划中' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.86),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(iconFor(iconKey), size: 21, color: c.mintDeep),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.xxs,
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 余额速览（压在场景底部）。
class BalanceBar extends ConsumerWidget {
  const BalanceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = ref.watch(monthSummaryProvider).value;
    final income = summary?.incomeCents ?? 0;
    final expense = summary?.expenseCents ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          _BalanceCell(label: '本月收入', cents: income, color: c.mintText),
          _Divider(color: c.border),
          _BalanceCell(label: '本月支出', cents: expense, color: c.coralText),
          _Divider(color: c.border),
          _BalanceCell(
            label: '结余',
            cents: income - expense,
            color: c.ink,
            signed: false,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: color);
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.label,
    required this.cents,
    required this.color,
    this.signed = true,
  });

  final String label;
  final int cents;
  final Color color;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = signed
        ? '${cents < 0 ? '-' : ''}¥${Money.yuan(cents.abs())}'
        : '¥${Money.yuan(cents)}';
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.xxs,
              color: c.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

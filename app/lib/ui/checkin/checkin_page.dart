import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../data/db/database.dart';
import '../../domain/rules/checkin_rules.dart';
import '../../state/checkin_providers.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';

/// 签到页：7 日周期面板 + 连续签到天数 + 签到按钮 + 最近记录。
class CheckinPage extends ConsumerStatefulWidget {
  const CheckinPage({super.key});

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  bool _busy = false;

  Future<void> _checkIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome =
          await ref.read(ledgerRepositoryProvider).checkIn(DateTime.now());
      if (!mounted) return;
      final msg = outcome.ok
          ? '签到成功 · 连续 ${outcome.streak} 天，金币 +${outcome.coin}'
              '${outcome.bonusText.isEmpty ? '' : '，${outcome.bonusText}'}'
          : '今天已经签过啦，明天再来';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('签到失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(checkinStateProvider);
    final history = ref.watch(checkinHistoryProvider).value ?? const [];

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('签到'),
        backgroundColor: c.pageBg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
        children: [
          _StreakCard(streak: state.streak),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '7 天奖励周期',
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CycleGrid(state: state),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: (state.canCheckIn && !_busy) ? _checkIn : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      state.canCheckIn
                          ? '签到领 ${state.nextReward.coin} 金币'
                          : '今日已签到',
                    ),
            ),
          ),
          if (state.canCheckIn && state.nextReward.hasBonus) ...[
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                '今天还额外送 1 件道具',
                style: TextStyle(fontSize: AppFontSizes.sm, color: c.coralText),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
            child: Text(
              '最近记录',
              style: TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          if (history.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '还没有签到记录，今天开始吧',
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
                  for (var i = 0; i < history.length; i++) ...[
                    _HistoryTile(record: history[i]),
                    if (i != history.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: Divider(height: 1, color: c.border),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.coral.withValues(alpha: 0.22), c.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          SoftIcon(
            icon: Icons.event_available_rounded,
            color: c.coral,
            size: 46,
            iconSize: 23,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '连续签到 $streak 天' : '今天开始签到',
                  style: TextStyle(
                    fontSize: AppFontSizes.xl,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '每天签到领金币，第 3 / 5 / 7 天还有道具',
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleGrid extends StatelessWidget {
  const _CycleGrid({required this.state});

  final CheckinState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 0.88,
      ),
      itemCount: CheckinRules.cycle.length,
      itemBuilder: (context, i) {
        final reward = CheckinRules.cycle[i];
        final claimed = reward.cycleDay <= state.claimedDays;
        final isNext =
            state.canCheckIn && reward.cycleDay == state.nextReward.cycleDay;

        final bg = claimed
            ? c.coral.withValues(alpha: 0.14)
            : (isNext ? c.goldSoft : c.surface2);
        final border = claimed
            ? c.coral
            : (isNext ? c.onWarm2.withValues(alpha: 0.5) : c.border);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '第${reward.cycleDay}天',
                style: TextStyle(
                  fontSize: AppFontSizes.xxs,
                  fontWeight: FontWeight.w700,
                  color: c.ink2,
                ),
              ),
              const SizedBox(height: 4),
              if (claimed)
                Icon(Icons.check_circle_rounded, size: 20, color: c.coral)
              else
                Icon(
                  reward.hasBonus
                      ? Icons.card_giftcard_rounded
                      : Icons.monetization_on_rounded,
                  size: 20,
                  color: reward.hasBonus ? c.onWarm2 : c.ink3,
                ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  '+${reward.coin}',
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    fontWeight: FontWeight.w800,
                    color: claimed ? c.coralText : c.ink2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final Checkin record;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SoftIcon(
            icon: Icons.event_available_rounded,
            color: c.mint,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateLabels.fullDate(record.day),
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '连续 ${record.streak} 天',
                    if (record.bonusText.isNotEmpty) record.bonusText,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '+${record.coinGained}',
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.w800,
              color: c.mintText,
            ),
          ),
        ],
      ),
    );
  }
}

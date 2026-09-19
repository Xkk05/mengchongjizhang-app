import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_labels.dart';
import '../../state/month_provider.dart';
import 'app_card.dart';

/// 月份选择条 —— 统计页与预算页共用，读写全局 `selectedMonthProvider`。
///
/// 不允许翻到未来：到当前月时「下一月」置灰。
class MonthBar extends ConsumerWidget {
  const MonthBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final month = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: () => ref.read(selectedMonthProvider.notifier).shift(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: c.ink2,
            tooltip: '上一月',
          ),
          Expanded(
            child: Text(
              DateLabels.yearMonth(month),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: isCurrent
                ? null
                : () => ref.read(selectedMonthProvider.notifier).shift(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: isCurrent ? c.border : c.ink2,
            tooltip: isCurrent ? '已是最新月份' : '下一月',
          ),
        ],
      ),
    );
  }
}

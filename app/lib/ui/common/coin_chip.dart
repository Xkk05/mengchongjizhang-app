import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../state/ledger_providers.dart';

/// 金币余额胶囊 —— 商店 / 背包 / 签到页通用。
class CoinChip extends ConsumerWidget {
  const CoinChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final coin = ref.watch(petStateProvider).value?.coin ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.goldSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, size: 15, color: c.onWarm1),
          const SizedBox(width: 4),
          Text(
            '$coin',
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w800,
              color: c.onWarm1,
            ),
          ),
        ],
      ),
    );
  }
}

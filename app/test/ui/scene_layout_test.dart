import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/state/ledger_providers.dart';
import 'package:suixin_pet_ledger/state/shop_providers.dart';
import 'package:suixin_pet_ledger/ui/ledger/widgets/scene_header.dart';

/// 回归测试：主页悬浮入口（锚定场景底部）与余额卡（排在场景下方）
/// 在任何字体缩放下都不得重叠。真机曾因 top 定位 + 大字体被压住。
void main() {
  const pet = PetState(
    id: 1,
    name: '团团',
    level: 1,
    exp: 0,
    coin: 60,
    hunger: 70,
    mood: 70,
    totalRecorded: 0,
    lastFedAt: null,
  );

  Widget host() {
    return ProviderScope(
      overrides: [
        petStateProvider.overrideWith((ref) => Stream.value(pet)),
        monthSummaryProvider
            .overrideWith((ref) => Stream.value(MonthSummary.empty)),
        equippedHeadProvider.overrideWith((ref) => null),
        equippedNeckProvider.overrideWith((ref) => null),
        equippedSceneProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const SceneHeader(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: BalanceBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final scale in const [1.0, 1.3, 1.5]) {
    testWidgets('字体缩放 x$scale：悬浮入口不与余额卡重叠', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(host());
      // BreathingPet 有循环动画，不能用 pumpAndSettle，推几帧让数据流落地。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final dockRect = tester.getRect(find.text('签到'));
      final cardRect = tester.getRect(find.text('本月收入'));
      expect(
        dockRect.bottom,
        lessThanOrEqualTo(cardRect.top),
        reason: '字体缩放 x$scale 时第三排悬浮入口被余额卡压住',
      );
    });
  }
}

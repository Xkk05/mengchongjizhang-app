import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/domain/rules/pet_rules.dart';
import 'package:suixin_pet_ledger/ui/home/pet_view.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('状态化动作绘制', () {
    testWidgets('四种动作在多个相位都能渲染且不抛异常', (tester) async {
      const phases = [0.0, 0.1, 0.2, 0.35, 0.5, 0.9];
      for (final action in PetAction.values) {
        for (final phase in phases) {
          await tester.pumpWidget(_host(PetView(
            size: 120,
            action: action,
            actionPhase: phase,
            // 让表情也贴合动作，避免出现组合漏画
            mood: action == PetAction.content ? 90 : 40,
            hunger: action == PetAction.hungry ? 10 : 70,
          )));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'action=$action phase=$phase 渲染失败');
        }
      }
    });

    testWidgets('深色模式下三种演出也能渲染', (tester) async {
      for (final action in [PetAction.hungry, PetAction.sleepy, PetAction.content]) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: PetView(
                size: 120,
                action: action,
                actionPhase: 0.2,
                mood: 40,
                hunger: action == PetAction.hungry ? 10 : 70,
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$action 深色渲染失败');
      }
    });
  });

  group('动作演出控制器', () {
    testWidgets('带动作的呼吸宠物跑完演出周期不抛异常', (tester) async {
      await tester.pumpWidget(_host(const BreathingPet(
        size: 120,
        level: 3,
        action: PetAction.hungry,
      )));
      await tester.pump();

      // 动作周期 9000ms，跑一段覆盖演出包络（前 40%）
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: '第 $i 帧异常');
      }
    });

    testWidgets('动作在待机与演出之间切换不抛异常', (tester) async {
      await tester.pumpWidget(_host(const BreathingPet(
        size: 120,
        action: PetAction.idle,
      )));
      await tester.pump();

      await tester.pumpWidget(_host(const BreathingPet(
        size: 120,
        action: PetAction.content,
      )));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(const BreathingPet(
        size: 120,
        action: PetAction.idle,
      )));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('静态模式（enabled=false）带动作也能渲染', (tester) async {
      for (final action in PetAction.values) {
        await tester.pumpWidget(_host(BreathingPet(
          size: 100,
          enabled: false,
          action: action,
          mood: 40,
          hunger: action == PetAction.hungry ? 10 : 70,
        )));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$action 静态渲染失败');
      }
    });
  });
}

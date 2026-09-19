import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/ui/home/pet_view.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('等级体型', () {
    testWidgets('每个阶段的体型都能渲染', (tester) async {
      for (final level in [1, 5, 15, 30, 60, 99]) {
        await tester.pumpWidget(_host(PetView(size: 140, level: level)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Lv.$level 渲染失败');
      }
    });

    testWidgets('体型缩放不改变画布尺寸（锚点在脚底）', (tester) async {
      await tester.pumpWidget(_host(const PetView(size: 140, level: 1)));
      await tester.pump();
      final baby = tester.getSize(find.byType(PetView));

      await tester.pumpWidget(_host(const PetView(size: 140, level: 80)));
      await tester.pump();
      final master = tester.getSize(find.byType(PetView));

      expect(baby, const Size(140, 140));
      expect(master, const Size(140, 140));
    });
  });

  group('表情', () {
    testWidgets('心情 / 饱食的各种组合都能渲染', (tester) async {
      for (final mood in [5, 30, 50, 80, 100]) {
        for (final hunger in [5, 25, 30, 70, 100]) {
          await tester.pumpWidget(
              _host(PetView(size: 120, mood: mood, hunger: hunger)));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'mood=$mood hunger=$hunger 渲染失败');
        }
      }
    });

    testWidgets('深色模式下蔫表情也能渲染', (tester) async {
      await tester.pumpWidget(_host(
        const PetView(size: 120, mood: 10, hunger: 10),
        brightness: Brightness.dark,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('待机动作', () {
    testWidgets('眨眼 / 摆尾的极值相位都能画', (tester) async {
      for (final blink in [0.0, 0.3, 0.5, 1.0]) {
        for (final sway in [-1.0, -0.4, 0.0, 0.4, 1.0]) {
          await tester.pumpWidget(
              _host(PetView(size: 120, blink: blink, sway: sway)));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'blink=$blink sway=$sway 渲染失败');
        }
      }
    });

    testWidgets('呼吸宠物跑完整个周期（含眨眼窗口）不抛异常', (tester) async {
      await tester.pumpWidget(_host(const BreathingPet(size: 120, level: 3)));
      await tester.pump();

      // 周期 3600ms，多跑一轮覆盖呼吸 / 摆尾 / 眨眼全部相位
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: '第 $i 帧异常');
      }
    });

    testWidgets('静态模式（enabled=false）也能带体型与表情渲染', (tester) async {
      await tester.pumpWidget(_host(const BreathingPet(
        size: 100,
        level: 10,
        mood: 20,
        hunger: 15,
        enabled: false,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PetView), findsOneWidget);
    });
  });
}

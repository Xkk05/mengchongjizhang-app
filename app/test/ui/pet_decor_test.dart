import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/domain/rules/decor_rules.dart';
import 'package:suixin_pet_ledger/ui/home/pet_view.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

const _sceneColors = SceneColors(
  top: Color(0xFFBFE3F5),
  mid: Color(0xFFD9EEF7),
  bottom: Color(0xFFEAF6EC),
  hill: Color(0xFF9BD3B4),
  hillDark: Color(0xFF7CC39B),
  grass: Color(0xFFA8DCBC),
);

void main() {
  group('宠包装扮绘制', () {
    testWidgets('三种饰品都能单独渲染且不抛异常', (tester) async {
      for (final accessory in PetAccessory.values) {
        await tester.pumpWidget(_host(PetView(size: 140, head: accessory)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '头饰 $accessory 渲染失败');

        await tester.pumpWidget(_host(PetView(size: 140, neck: accessory)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '颈部 $accessory 渲染失败');
      }
    });

    testWidgets('头饰 + 颈部可同时佩戴', (tester) async {
      await tester.pumpWidget(_host(const PetView(
        size: 140,
        head: PetAccessory.crown,
        neck: PetAccessory.bell,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PetView), findsOneWidget);
    });

    testWidgets('浅色 / 深色下带装扮的宠物都能渲染', (tester) async {
      for (final b in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(_host(
          const PetView(
            size: 120,
            head: PetAccessory.ribbon,
            neck: PetAccessory.bell,
          ),
          brightness: b,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });
  });

  group('场景皮肤绘制', () {
    testWidgets('三种皮肤都能渲染且不抛异常', (tester) async {
      for (final skin in SceneSkin.values) {
        await tester.pumpWidget(_host(SizedBox(
          width: 300,
          height: 260,
          child: SceneBackground(colors: _sceneColors, skin: skin),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '皮肤 $skin 渲染失败');
      }
    });

    testWidgets('皮肤默认值是草甸', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 300,
        height: 260,
        child: SceneBackground(colors: _sceneColors),
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SceneBackground), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/ui/common/app_card.dart';
import 'package:suixin_pet_ledger/ui/home/pet_view.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('宠物绘制在浅色/深色下都能渲染且不抛异常', (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(_host(const PetView(size: 120), brightness: b));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    }
  });

  testWidgets('呼吸动画版本可正常重复播放', (tester) async {
    await tester.pumpWidget(_host(const BreathingPet(size: 100)));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppCard 支持点击回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(AppCard(
      onTap: () => tapped = true,
      child: const Text('账单管理'),
    )));
    await tester.tap(find.text('账单管理'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('SoftIcon 使用传入颜色绘制', (tester) async {
    await tester.pumpWidget(_host(const SoftIcon(
      icon: Icons.pets_rounded,
      color: Color(0xFFE2584A),
    )));
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

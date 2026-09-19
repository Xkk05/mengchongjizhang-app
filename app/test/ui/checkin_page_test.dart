import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/state/checkin_providers.dart';
import 'package:suixin_pet_ledger/ui/checkin/checkin_page.dart';

Checkin _ck({
  required DateTime day,
  required int streak,
  int coin = 20,
  String bonus = '',
}) =>
    Checkin(
      id: day.day,
      day: day,
      streak: streak,
      coinGained: coin,
      bonusText: bonus,
      createdAt: day,
    );

Widget _host({Checkin? latest, List<Checkin> history = const []}) {
  return ProviderScope(
    overrides: [
      latestCheckinProvider.overrideWith((ref) => Stream.value(latest)),
      checkinHistoryProvider.overrideWith((ref) => Stream.value(history)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CheckinPage(),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Checkin? latest,
  List<Checkin> history = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(latest: latest, history: history));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  testWidgets('从没签过：提示今天开始并给出首日奖励', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('今天开始签到'), findsOneWidget);
    expect(find.text('签到领 20 金币'), findsOneWidget);
    expect(find.text('还没有签到记录，今天开始吧'), findsOneWidget);
    expect(find.text('7 天奖励周期'), findsOneWidget);
  });

  testWidgets('今天已签：按钮禁用并展示当前连击', (tester) async {
    await _pump(
      tester,
      latest: _ck(day: today, streak: 3, coin: 40),
      history: [_ck(day: today, streak: 3, coin: 40)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('连续签到 3 天'), findsOneWidget);
    expect(find.text('今日已签到'), findsOneWidget);
    expect(find.text('签到领 20 金币'), findsNothing);
    // 历史记录里展示连击天数
    expect(find.textContaining('连续 3 天'), findsWidgets);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('昨天签过：连击延续，奖励推进到第 4 天', (tester) async {
    await _pump(
      tester,
      latest: _ck(day: yesterday, streak: 3, coin: 40),
      history: [_ck(day: yesterday, streak: 3, coin: 40)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('连续签到 3 天'), findsOneWidget);
    expect(find.text('签到领 50 金币'), findsOneWidget);
    // 第 4 天没有额外道具
    expect(find.text('今天还额外送 1 件道具'), findsNothing);
  });

  testWidgets('断签后连击清零，按钮回到首日奖励', (tester) async {
    await _pump(
      tester,
      latest: _ck(day: today.subtract(const Duration(days: 4)), streak: 6),
      history: [_ck(day: today.subtract(const Duration(days: 4)), streak: 6)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('今天开始签到'), findsOneWidget);
    expect(find.text('签到领 20 金币'), findsOneWidget);
  });

  testWidgets('即将领到道具时给出额外提示', (tester) async {
    await _pump(
      tester,
      latest: _ck(day: yesterday, streak: 2, coin: 30),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('签到领 40 金币'), findsOneWidget);
    expect(find.text('今天还额外送 1 件道具'), findsOneWidget);
  });
}

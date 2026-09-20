import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/core/theme/app_theme.dart';
import 'package:suixin_pet_ledger/data/db/database.dart';
import 'package:suixin_pet_ledger/state/providers.dart';
import 'package:suixin_pet_ledger/ui/record/record_sheet.dart';

/// 回归测试：记账弹层在小屏 + 大字体下，分类与保存键必须依然可见可用。
///
/// 真机曾出现「分类区被 Expanded 压成 0 高度、保存键看不见」，
/// 现结构为：中部滚动区（分类固定高度）+ 底部常驻保存键，不允许回退。
void main() {
  Future<VoidCallback?> saveHandler(WidgetTester tester) async {
    final ink = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byKey(const ValueKey('record-save')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    return ink.onTap;
  }

  /// 装配弹层，返回承载弹层查询的内存数据库，供测试结束时清理。
  Future<AppDatabase> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(360, 720),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: RecordSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  /// 结束时的清理：drift 在查询流取消订阅时会内部起一个 zero 时长定时器
  /// （stream_queries.dart 的 markAsClosed），在 flutter_test 的 fake-async
  /// 区里必须推进时钟才会触发，否则报 "A Timer is still pending"。
  /// 这里先卸载整棵树触发取消订阅，再推进一帧让定时器跑完，最后关库。
  Future<void> tearDownSheet(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  }

  testWidgets('小屏 + 大字体：分类可见、保存键常驻且在屏幕内', (tester) async {
    final db = await pumpSheet(
      tester,
      size: const Size(360, 720),
      textScale: 1.3,
    );

    // 分类区结构数据（餐饮等）在弹层里可见。
    expect(find.text('餐饮'), findsOneWidget);
    final catRect = tester.getRect(find.text('餐饮'));
    expect(catRect.top, greaterThanOrEqualTo(0));
    expect(catRect.bottom, lessThan(720));

    // 保存键是整列高的实体按钮，完整落在屏幕内。
    final saveRect = tester.getRect(find.byKey(const ValueKey('record-save')));
    expect(saveRect.height, greaterThan(120));
    expect(saveRect.bottom, lessThanOrEqualTo(720));
    expect(saveRect.top, greaterThanOrEqualTo(0));

    await tearDownSheet(tester, db);
  });

  testWidgets('常规屏幕：同样满足', (tester) async {
    final db = await pumpSheet(
      tester,
      size: const Size(393, 851),
      textScale: 1.0,
    );
    expect(find.text('餐饮'), findsOneWidget);
    final saveRect = tester.getRect(find.byKey(const ValueKey('record-save')));
    expect(saveRect.height, greaterThan(120));
    expect(saveRect.bottom, lessThanOrEqualTo(851));

    await tearDownSheet(tester, db);
  });

  testWidgets('选分类 + 输金额后保存键可用', (tester) async {
    final db = await pumpSheet(
      tester,
      size: const Size(360, 720),
      textScale: 1.0,
    );
    expect(await saveHandler(tester), isNull, reason: '未填金额时不可保存');

    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(await saveHandler(tester), isNotNull, reason: '选好分类与金额后可保存');

    await tearDownSheet(tester, db);
  });
}

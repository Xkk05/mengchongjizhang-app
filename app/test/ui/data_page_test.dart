import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/data/repositories/ledger_repository.dart';
import 'package:suixin_pet_ledger/domain/csv/ledger_csv.dart';
import 'package:suixin_pet_ledger/ui/data/data_page.dart';

ImportPreview preview({
  int importable = 0,
  int duplicates = 0,
  List<CsvRowError> errors = const [],
  List<String> newExpense = const [],
  List<String> newIncome = const [],
  List<String> newAccounts = const [],
}) =>
    ImportPreview(
      importable: importable,
      duplicates: duplicates,
      errors: errors,
      newExpenseCategories: newExpense,
      newIncomeCategories: newIncome,
      newAccounts: newAccounts,
    );

void main() {
  /// 页面是竖排长列表，默认 800x600 视口会让靠下的卡片根本不进 widget 树。
  /// 注意必须**在测试体内**调用 —— `setSurfaceSize` 走 TestAsyncUtils 守卫，
  /// 放在 `setUp` 里会抛 Guarded function conflict。
  Future<void> setCanvas(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('数据管理页', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await setCanvas(tester);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DataPage())),
      );
      await tester.pump();
    }

    testWidgets('顶部标题与导出 / 导入两个分区都在', (tester) async {
      await pumpPage(tester);
      expect(find.text('数据管理'), findsOneWidget);
      expect(find.text('导出账单'), findsOneWidget);
      expect(find.text('导入账单'), findsOneWidget);
    });

    testWidgets('两个操作按钮都渲染且可点', (tester) async {
      await pumpPage(tester);
      expect(find.text('导出 CSV 文件'), findsOneWidget);
      expect(find.text('选择 CSV 文件'), findsOneWidget);

      final export = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('导出 CSV 文件'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(export.onPressed, isNotNull);
    });

    testWidgets('规则说明把关键约定写清楚', (tester) async {
      await pumpPage(tester);
      expect(find.textContaining('重复的记录会自动跳过'), findsOneWidget);
      expect(find.textContaining('自动新建'), findsOneWidget);
      expect(find.textContaining('不计入宠物成长'), findsOneWidget);
    });
  });

  group('导入预览弹层', () {
    Future<void> pumpSheet(WidgetTester tester, ImportPreview p) async {
      await setCanvas(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportPreviewSheet(preview: p, fileName: '账单.csv'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('展示可导入 / 跳过重复 / 异常行三项统计', (tester) async {
      await pumpSheet(tester, preview(importable: 12, duplicates: 3));
      expect(find.text('导入预览'), findsOneWidget);
      expect(find.text('账单.csv'), findsOneWidget);
      expect(find.text('12 笔'), findsOneWidget);
      expect(find.text('3 笔'), findsOneWidget);
      expect(find.text('0 行'), findsOneWidget);
    });

    testWidgets('确认按钮带上将导入的条数', (tester) async {
      await pumpSheet(tester, preview(importable: 12));
      expect(find.text('确认导入 12 笔'), findsOneWidget);
    });

    testWidgets('没有可导入记录时确认按钮禁用', (tester) async {
      await pumpSheet(tester, preview(duplicates: 5));
      final confirm = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('确认导入 0 笔'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirm.onPressed, isNull);
      expect(find.text('这些记录都已经存在，无需重复导入。'), findsOneWidget);
    });

    testWidgets('列出将新建的分类与账户', (tester) async {
      await pumpSheet(
        tester,
        preview(
          importable: 4,
          newExpense: ['奶茶', '健身'],
          newIncome: ['稿费'],
          newAccounts: ['云闪付'],
        ),
      );
      expect(find.text('将新建分类'), findsOneWidget);
      expect(find.text('将新建账户'), findsOneWidget);
      for (final n in ['奶茶', '健身', '稿费', '云闪付']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('异常行带行号展示', (tester) async {
      await pumpSheet(
        tester,
        preview(
          importable: 1,
          errors: [
            const CsvRowError(line: 7, reason: '金额无法识别：abc'),
            const CsvRowError(line: 9, reason: '日期无法识别：(空)'),
          ],
        ),
      );
      expect(find.text('异常行（已跳过）'), findsOneWidget);
      expect(find.textContaining('第 7 行：金额无法识别'), findsOneWidget);
      expect(find.textContaining('第 9 行：日期无法识别'), findsOneWidget);
      expect(find.text('2 行'), findsOneWidget);
    });
  });
}

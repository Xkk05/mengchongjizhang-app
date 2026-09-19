import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/budget/budget_plan.dart';

BudgetTarget _target({
  int? categoryId,
  String name = '餐饮',
  int limit = 100000,
}) =>
    (categoryId: categoryId, name: name, iconKey: 'fork', colorValue: 0xFFE2584A, limitCents: limit);

void main() {
  group('BudgetPlan.build 基本归并', () {
    test('总预算用当月支出总额，分类预算用分类支出', () {
      final plan = BudgetPlan.build(
        targets: [_target(categoryId: null, name: '总预算', limit: 800000), _target(categoryId: 1, limit: 150000)],
        spentByCategory: {1: 60000, 2: 20000},
        totalSpentCents: 80000,
      );

      expect(plan.overall, isNotNull);
      expect(plan.overall!.spentCents, 80000);
      expect(plan.lines.length, 1);
      expect(plan.lines.first.spentCents, 60000);
    });

    test('没有支出的分类预算按 0 计', () {
      final plan = BudgetPlan.build(
        targets: [_target(categoryId: 9, limit: 5000)],
        spentByCategory: {1: 100},
        totalSpentCents: 100,
      );
      expect(plan.lines.single.spentCents, 0);
      expect(plan.lines.single.barValue, 0);
    });

    test('额度非正的预算被忽略', () {
      final plan = BudgetPlan.build(
        targets: [
          _target(categoryId: 1, limit: 0),
          _target(categoryId: 2, limit: -100),
          _target(categoryId: 3, limit: 1000),
        ],
        spentByCategory: const {},
        totalSpentCents: 0,
      );
      expect(plan.lines.length, 1);
      expect(plan.lines.single.categoryId, 3);
    });

    test('空目标得到空计划', () {
      final plan = BudgetPlan.build(
        targets: const [],
        spentByCategory: const {},
        totalSpentCents: 0,
      );
      expect(plan.hasAny, isFalse);
      expect(plan.overall, isNull);
      expect(plan.lines, isEmpty);
    });

    test('同月出现多条总预算时取额度较大的一条', () {
      final plan = BudgetPlan.build(
        targets: [
          _target(categoryId: null, name: '总预算', limit: 100),
          _target(categoryId: null, name: '总预算', limit: 900),
        ],
        spentByCategory: const {},
        totalSpentCents: 0,
      );
      expect(plan.overall!.limitCents, 900);
    });
  });

  group('BudgetPlan.build 排序与预警', () {
    test('分类预算按使用率降序', () {
      final plan = BudgetPlan.build(
        targets: [
          _target(categoryId: 1, name: '餐饮', limit: 100000), // 30%
          _target(categoryId: 2, name: '交通', limit: 10000), // 100%
          _target(categoryId: 3, name: '购物', limit: 50000), // 60%
        ],
        spentByCategory: {1: 30000, 2: 10000, 3: 30000},
        totalSpentCents: 70000,
      );
      expect(plan.lines.map((l) => l.categoryId).toList(), [2, 3, 1]);
    });

    test('超支时 isOver 为真且剩余为负', () {
      final plan = BudgetPlan.build(
        targets: [_target(categoryId: 1, limit: 10000)],
        spentByCategory: {1: 15000},
        totalSpentCents: 15000,
      );
      final l = plan.lines.single;
      expect(l.isOver, isTrue);
      expect(l.remainingCents, -5000);
      expect(l.barValue, 1.0); // 进度条封顶
      expect(l.ratio, closeTo(1.5, 1e-9));
    });

    test('未超支时 isOver 为假，barValue 等于 ratio', () {
      final plan = BudgetPlan.build(
        targets: [_target(categoryId: 1, limit: 10000)],
        spentByCategory: {1: 2500},
        totalSpentCents: 2500,
      );
      final l = plan.lines.single;
      expect(l.isOver, isFalse);
      expect(l.barValue, closeTo(0.25, 1e-9));
      expect(l.remainingCents, 7500);
    });

    test('overCount 统计超支的分类数', () {
      final plan = BudgetPlan.build(
        targets: [
          _target(categoryId: 1, limit: 100),
          _target(categoryId: 2, limit: 100),
          _target(categoryId: 3, limit: 100),
        ],
        spentByCategory: {1: 200, 2: 300, 3: 50},
        totalSpentCents: 550,
      );
      expect(plan.overCount, 2);
    });

    test('totalLimitCents 只累计分类预算，不含总预算', () {
      final plan = BudgetPlan.build(
        targets: [
          _target(categoryId: null, name: '总预算', limit: 900000),
          _target(categoryId: 1, limit: 100),
          _target(categoryId: 2, limit: 250),
        ],
        spentByCategory: const {},
        totalSpentCents: 0,
      );
      expect(plan.totalLimitCents, 350);
    });
  });
}

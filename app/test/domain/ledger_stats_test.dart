import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/stats/ledger_stats.dart';

StatEntry e({
  required DateTime at,
  required int cents,
  bool expense = true,
  int cat = 1,
  String name = '餐饮',
  String icon = 'fork',
  int color = 0xFFE2584A,
}) =>
    (
      at: at,
      amountCents: cents,
      isExpense: expense,
      categoryId: cat,
      categoryName: name,
      iconKey: icon,
      colorValue: color,
    );

void main() {
  group('LedgerStats.byCategory', () {
    final base = DateTime(2026, 9, 10, 12);

    test('只统计指定方向的记录', () {
      final slices = LedgerStats.byCategory([
        e(at: base, cents: 1000),
        e(at: base, cents: 2000),
        e(at: base, cents: 5000, expense: false, cat: 9, name: '工资'),
      ], expense: true);

      expect(slices, hasLength(1));
      expect(slices.first.totalCents, 3000);
      expect(slices.first.count, 2);
      expect(slices.first.ratio, 1.0);
    });

    test('按分类归并并按金额降序', () {
      final slices = LedgerStats.byCategory([
        e(at: base, cents: 1000, cat: 1, name: '餐饮'),
        e(at: base, cents: 100, cat: 1, name: '餐饮'),
        e(at: base, cents: 900, cat: 2, name: '交通', icon: 'bus'),
        e(at: base, cents: 5000, cat: 3, name: '居住', icon: 'home'),
      ], expense: true);

      expect(slices.map((s) => s.name).toList(), ['居住', '餐饮', '交通']);
      expect(slices[1].totalCents, 1100);
      expect(slices[1].count, 2);

      final sum = slices.fold<double>(0, (s, x) => s + x.ratio);
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('金额非正的记录被忽略', () {
      final slices = LedgerStats.byCategory([
        e(at: base, cents: 0),
        e(at: base, cents: -100),
        e(at: base, cents: 500),
      ], expense: true);

      expect(slices, hasLength(1));
      expect(slices.first.totalCents, 500);
      expect(slices.first.count, 1);
    });

    test('无数据时返回空列表', () {
      expect(LedgerStats.byCategory(const [], expense: true), isEmpty);
    });
  });

  group('LedgerStats.dailyTrend', () {
    final today = DateTime(2026, 9, 19, 15, 30);

    test('返回的天数固定，且无数据的日期补 0', () {
      final points = LedgerStats.dailyTrend(
        [e(at: DateTime(2026, 9, 19, 9), cents: 1200)],
        days: 7,
        today: today,
      );

      expect(points, hasLength(7));
      expect(points.first.day, DateTime(2026, 9, 13));
      expect(points.last.day, DateTime(2026, 9, 19));
      expect(points.last.expenseCents, 1200);
      expect(points.last.incomeCents, 0);
      expect(points.first.expenseCents, 0);
    });

    test('同一天的多笔按自然日归并，忽略时分秒', () {
      final points = LedgerStats.dailyTrend([
        e(at: DateTime(2026, 9, 18, 8), cents: 300),
        e(at: DateTime(2026, 9, 18, 23, 59), cents: 700),
        e(at: DateTime(2026, 9, 18, 12), cents: 2000, expense: false),
      ], days: 7, today: today);

      final d18 = points.firstWhere((p) => p.day.day == 18);
      expect(d18.expenseCents, 1000);
      expect(d18.incomeCents, 2000);
      expect(d18.balanceCents, 1000);
    });

    test('区间外的记录被忽略', () {
      final points = LedgerStats.dailyTrend([
        e(at: DateTime(2026, 9, 1), cents: 99999), // 太早
        e(at: DateTime(2026, 10, 1), cents: 88888), // 太晚
        e(at: DateTime(2026, 9, 19), cents: 100),
      ], days: 7, today: today);

      final total = points.fold<int>(0, (s, p) => s + p.expenseCents);
      expect(total, 100);
    });

    test('跨月区间能正确回退到上个月', () {
      final points = LedgerStats.dailyTrend(
        [
          e(at: DateTime(2026, 2, 27), cents: 1500),
          e(at: DateTime(2026, 3, 1), cents: 500),
        ],
        days: 7,
        today: DateTime(2026, 3, 3),
      );

      expect(points.first.day, DateTime(2026, 2, 25));
      expect(points.last.day, DateTime(2026, 3, 3));
      expect(points,
          hasLength(7));
      expect(points.firstWhere((p) => p.day == DateTime(2026, 2, 27)).expenseCents,
          1500);
      expect(points.firstWhere((p) => p.day == DateTime(2026, 3, 1)).expenseCents,
          500);
    });
  });

  group('LedgerStats.totals / maxValue', () {
    test('分别累计收与支', () {
      final t = LedgerStats.totals([
        e(at: DateTime(2026, 9, 1), cents: 1000),
        e(at: DateTime(2026, 9, 1), cents: 250),
        e(at: DateTime(2026, 9, 1), cents: 8000, expense: false),
      ]);

      expect(t.expenseCents, 1250);
      expect(t.incomeCents, 8000);
      expect(t.balanceCents, 6750);
    });

    test('maxValue 空集合返回 0', () {
      expect(LedgerStats.maxValue(const []), 0);
      expect(LedgerStats.maxValue([3, 9, 5]), 9);
    });
  });
}

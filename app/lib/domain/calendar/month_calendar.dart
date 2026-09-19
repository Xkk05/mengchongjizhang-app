/// 账单日历 —— 月历网格与每日收支聚合。
///
/// 纯函数、零依赖（不 import 数据层类型），便于单测：日期算术是最容易被
/// 边界咬到的地方（闰月、跨年、1 号是周几），摊到测试里比靠肉眼盯界面靠谱。
library;

/// 聚合输入：日历只需要「哪天 / 收支 / 多少钱」这三个字段。
typedef CalendarEntry = ({DateTime at, bool isExpense, int amountCents});

/// 日历里的一格。
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.inMonth,
    required this.expenseCents,
    required this.incomeCents,
    required this.count,
  });

  final DateTime date;

  /// 是否属于当前展示的月份 —— 首尾补齐的邻月日期为 false。
  final bool inMonth;

  final int expenseCents;
  final int incomeCents;

  /// 当日笔数。
  final int count;

  bool get hasData => count > 0;
  int get balanceCents => incomeCents - expenseCents;

  /// 格子里展示哪个数：有支出优先展示支出（记账场景更关心花销）。
  int get primaryCents => expenseCents > 0 ? expenseCents : incomeCents;
  bool get primaryIsExpense => expenseCents > 0;
}

class MonthCalendar {
  const MonthCalendar._();

  /// 周标题，周一开头（与 `DateTime.weekday` 的 1..7 对齐）。
  static const List<String> weekdayHeaders = ['一', '二', '三', '四', '五', '六', '日'];

  /// 该月天数（`DateTime(y, m+1, 0)` 正好落在上月最后一天）。
  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// 该月 1 号之前要补几格（周一开头 → 周一补 0，周日补 6）。
  static int leadingBlanks(int year, int month) =>
      DateTime(year, month, 1).weekday - DateTime.monday;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 构建整月网格：补齐首尾到 7 的整数倍（通常 5 或 6 行）。
  ///
  /// 只聚合 `year/month` 当月的流水 —— 邻月格子仅作占位，不显示数字。
  static List<CalendarDay> build({
    required int year,
    required int month,
    required Iterable<CalendarEntry> entries,
  }) {
    final expense = <int, int>{};
    final income = <int, int>{};
    final counts = <int, int>{};

    for (final e in entries) {
      if (e.at.year != year || e.at.month != month) continue;
      final d = e.at.day;
      if (e.isExpense) {
        expense[d] = (expense[d] ?? 0) + e.amountCents;
      } else {
        income[d] = (income[d] ?? 0) + e.amountCents;
      }
      counts[d] = (counts[d] ?? 0) + 1;
    }

    final lead = leadingBlanks(year, month);
    final total = daysInMonth(year, month);
    final cells = ((lead + total + 6) ~/ 7) * 7;

    return List<CalendarDay>.generate(cells, (i) {
      // 1 - lead 就是网格左上角那天（可能是上月末尾）。
      final date = DateTime(year, month, 1 - lead + i);
      final inMonth = date.year == year && date.month == month;
      return CalendarDay(
        date: date,
        inMonth: inMonth,
        expenseCents: inMonth ? (expense[date.day] ?? 0) : 0,
        incomeCents: inMonth ? (income[date.day] ?? 0) : 0,
        count: inMonth ? (counts[date.day] ?? 0) : 0,
      );
    }, growable: false);
  }

  /// 当月有支出的日子里花得最多的一天；没有则为 null。
  static CalendarDay? busiestExpenseDay(List<CalendarDay> grid) {
    CalendarDay? best;
    for (final d in grid) {
      if (!d.inMonth || d.expenseCents == 0) continue;
      if (best == null || d.expenseCents > best.expenseCents) best = d;
    }
    return best;
  }

  /// 日历格里的紧凑金额：1000 元以上取 `k`，100 元以上取整，其余保留一位小数。
  ///
  /// 格子宽度只有屏宽的 1/7，写全 `¥1,234.50` 会直接溢出，所以分级降精度。
  static String compactAmount(int cents) {
    final v = cents.abs() / 100;
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}

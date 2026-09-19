/// 日期展示工具。
///
/// 刻意**不依赖 intl 的 locale 数据**：中文的「年/月/日/星期」是固定字面量，
/// 手写拼接反而更稳 —— 不必在启动时初始化 locale，也不会因为
/// locale 数据未就绪而在任意 widget 里抛异常。
library;

class DateLabels {
  const DateLabels._();

  static const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  /// 取「日」粒度，用于把账目按天分组。
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  /// `星期六`（DateTime.weekday：1=周一 … 7=周日）
  static String weekday(DateTime d) => '星期${_weekdayNames[d.weekday - 1]}';

  /// `M月d日`
  static String monthDay(DateTime d) => '${d.month}月${d.day}日';

  /// `yyyy年M月`
  static String yearMonth(DateTime d) => '${d.year}年${d.month}月';

  /// `yyyy年M月d日`
  static String fullDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  /// `HH:mm`
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// 明细列表的分组标题：今天 / 昨天 / `M月d日 星期X`。
  static String groupLabel(DateTime date, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final diff = today.difference(dayOf(date)).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${monthDay(date)} ${weekday(date)}';
  }
}

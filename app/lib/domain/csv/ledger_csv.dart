/// 账单 CSV 的序列化与解析 —— 纯函数，不依赖数据层类型，便于单测。
///
/// 设计要点：
/// - **不抛异常**：坏行收集到 [CsvParseResult.errors] 里，好行照常返回，
///   一次导入里有一两行脏数据不会让整个文件作废。
/// - **表头按别名匹配**：既认本 App 导出的中文表头，也认常见的第三方账单表头。
/// - **方向判定有优先级**：显式的「类型/收支」列 > 金额正负号 > 默认支出。
library;

/// 一行账单（导出时作为输入，导入时作为产物）。
typedef CsvLedgerRow = ({
  DateTime at,
  bool isExpense,
  String categoryName,
  String accountName,
  int amountCents,
  String note,
});

/// 解析失败的一行。
class CsvRowError {
  const CsvRowError({required this.line, required this.reason});

  /// 行号，1 基（含表头行），方便用户回文件里定位。
  final int line;
  final String reason;

  @override
  String toString() => '第 $line 行：$reason';
}

/// 解析结果：认出来的行 + 没认出来的行。
class CsvParseResult {
  const CsvParseResult({required this.rows, required this.errors});

  final List<CsvLedgerRow> rows;
  final List<CsvRowError> errors;

  bool get hasContent => rows.isNotEmpty || errors.isNotEmpty;

  static const CsvParseResult empty = CsvParseResult(rows: [], errors: []);
}

class LedgerCsv {
  const LedgerCsv._();

  /// UTF-8 BOM —— 没有它，Excel 打开中文会乱码。
  static const String bom = '\uFEFF';

  /// 导出表头（顺序即列顺序）。
  static const List<String> headers = ['日期', '类型', '分类', '账户', '金额', '备注'];

  /// 表头别名表：字段 -> 可接受的列名（一律小写、忽略空格后比较）。
  static const Map<String, List<String>> _aliases = {
    'date': ['日期', '时间', '交易时间', '交易日期', '记账日期', '日期时间', 'date', 'time'],
    'kind': ['类型', '收支', '收支类型', '方向', 'type'],
    'category': ['分类', '类别', '分类名称', 'category'],
    'account': ['账户', '账户名', '资金账户', '支付方式', 'account'],
    'amount': ['金额', '金额(元)', '金额（元）', '交易金额', '收支金额', 'amount'],
    'note': ['备注', '说明', '描述', '商品说明', 'note'],
  };

  // ------------------------------------------------------------------ 导出

  /// 序列化为 CSV 文本（带 BOM、CRLF 换行，Excel 直接双击可用）。
  static String encode(Iterable<CsvLedgerRow> rows) {
    final b = StringBuffer()..write(bom);
    b
      ..write(headers.join(','))
      ..write('\r\n');
    for (final r in rows) {
      b
        ..write([
          _formatDate(r.at),
          r.isExpense ? '支出' : '收入',
          _escape(r.categoryName),
          _escape(r.accountName),
          // 金额导出为「元」的两位小数、不带千分位与符号，保证机器往返无损。
          (r.amountCents.abs() / 100).toStringAsFixed(2),
          _escape(r.note),
        ].join(','))
        ..write('\r\n');
    }
    return b.toString();
  }

  /// 导出文件名：`随心宠记账-账单-20260919-1630.csv`
  static String fileName(DateTime now) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '随心宠记账-账单-${now.year}${p2(now.month)}${p2(now.day)}'
        '-${p2(now.hour)}${p2(now.minute)}.csv';
  }

  // ------------------------------------------------------------------ 导入

  /// 解析 CSV 文本。识别不了的行进 [CsvParseResult.errors]，不影响其余行。
  static CsvParseResult parse(String content) {
    var text = content;
    if (text.startsWith(bom)) text = text.substring(1);

    final table = _tokenize(text);
    if (table.isEmpty) return CsvParseResult.empty;

    // 表头：第一个非空行（有些导出文件前面会空一行）。
    var headerIndex = -1;
    for (var i = 0; i < table.length; i++) {
      if (table[i].any((f) => f.trim().isNotEmpty)) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex < 0) return CsvParseResult.empty;

    final col = _mapColumns(table[headerIndex]);
    if (!col.containsKey('date') || !col.containsKey('amount')) {
      return CsvParseResult(rows: const [], errors: [
        CsvRowError(
          line: headerIndex + 1,
          reason: '缺少「日期」或「金额」列，无法识别该文件（需要表头行）',
        ),
      ]);
    }

    final rows = <CsvLedgerRow>[];
    final errors = <CsvRowError>[];

    for (var i = headerIndex + 1; i < table.length; i++) {
      final raw = table[i];
      final lineNo = i + 1;
      if (raw.every((f) => f.trim().isEmpty)) continue; // 空行静默跳过

      final dateText = _pick(raw, col['date']);
      final at = _parseDate(dateText);
      if (at == null) {
        errors.add(CsvRowError(
          line: lineNo,
          reason: '日期无法识别：${dateText.trim().isEmpty ? '(空)' : dateText.trim()}',
        ));
        continue;
      }

      final amountText = _pick(raw, col['amount']);
      final amount = _parseAmount(amountText);
      if (amount == null || amount.cents == 0) {
        errors.add(CsvRowError(
          line: lineNo,
          reason: '金额无法识别：${amountText.trim().isEmpty ? '(空)' : amountText.trim()}',
        ));
        continue;
      }

      // 方向优先级：显式类型列 > 金额正负号 > 默认支出。
      final kindExpense = _parseKind(_pick(raw, col['kind']));
      final isExpense = kindExpense ?? amount.negative ?? true;

      rows.add((
        at: at,
        isExpense: isExpense,
        categoryName: _pick(raw, col['category']).trim(),
        accountName: _pick(raw, col['account']).trim(),
        amountCents: amount.cents.abs(),
        note: _pick(raw, col['note']).trim(),
      ));
    }

    return CsvParseResult(rows: rows, errors: errors);
  }

  // ------------------------------------------------------------------ 去重

  /// 去重指纹：按「分钟」归一化时间，避免导出（到分钟）与库内（带秒）对不上。
  ///
  /// 配合「计数去重」（见仓库层）使用：同指纹的行按出现次数一一抵消，
  /// 因此重复导入同一文件会全部跳过，而真实的同分钟多笔不会被误伤。
  static String fingerprint(CsvLedgerRow row) => fingerprintOf(
        at: row.at,
        isExpense: row.isExpense,
        amountCents: row.amountCents,
        categoryName: row.categoryName,
        accountName: row.accountName,
        note: row.note,
      );

  static String fingerprintOf({
    required DateTime at,
    required bool isExpense,
    required int amountCents,
    required String categoryName,
    required String accountName,
    required String note,
  }) {
    final m = DateTime(at.year, at.month, at.day, at.hour, at.minute);
    return '${m.toIso8601String()}|${isExpense ? 'E' : 'I'}|$amountCents'
        '|$categoryName|$accountName|$note';
  }

  // ------------------------------------------------------------ 内部：编解码

  static String _escape(String s) {
    if (s.isEmpty) return '';
    final needsQuote = s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r');
    if (!needsQuote) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  static String _formatDate(DateTime d) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${p2(d.month)}-${p2(d.day)} '
        '${p2(d.hour)}:${p2(d.minute)}';
  }

  /// 手写 CSV 分词器：支持引号包裹、字段内逗号/换行、`""` 转义。
  static List<List<String>> _tokenize(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final c = content[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
        continue;
      }
      if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (c == '\r') {
        // 交给 \n 处理，忽略裸 \r
      } else if (c == '\n') {
        row.add(field.toString());
        field = StringBuffer();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static Map<String, int> _mapColumns(List<String> header) {
    final col = <String, int>{};
    final normalized = header.map((h) => h.trim().toLowerCase().replaceAll(' ', '')).toList();
    _aliases.forEach((key, names) {
      for (var i = 0; i < normalized.length; i++) {
        if (names.any((n) => n.toLowerCase() == normalized[i])) {
          col[key] = i;
          return;
        }
      }
    });
    return col;
  }

  static String _pick(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index];
  }

  // ------------------------------------------------------------ 内部：字段解析

  static final RegExp _dateRe =
      RegExp(r'(\d{4})\s*[-/年.]\s*(\d{1,2})\s*[-/月.]\s*(\d{1,2})\s*日?');
  static final RegExp _timeRe =
      RegExp(r'(\d{1,2})\s*:\s*(\d{1,2})(?:\s*:\s*(\d{1,2}))?');

  /// 支持 `2026-09-19 14:30`、`2026/9/19 14:30:00`、`2026年9月19日` 等写法。
  static DateTime? _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;

    final dm = _dateRe.firstMatch(t);
    if (dm == null) return null;

    final y = int.tryParse(dm.group(1)!);
    final mo = int.tryParse(dm.group(2)!);
    final d = int.tryParse(dm.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;

    var h = 0, mi = 0, s = 0;
    final tm = _timeRe.firstMatch(t);
    if (tm != null) {
      h = int.tryParse(tm.group(1)!) ?? 0;
      mi = int.tryParse(tm.group(2)!) ?? 0;
      s = int.tryParse(tm.group(3) ?? '') ?? 0;
      if (h > 23 || mi > 59 || s > 59) return null;
    }

    final dt = DateTime(y, mo, d, h, mi, s);
    // DateTime 会把 2 月 30 日滚到 3 月，这里显式拒绝这类溢出。
    if (dt.month != mo || dt.day != d) return null;
    return dt;
  }

  /// 解析金额（元）为分，并返回是否带负号（无符号时 negative 为 null）。
  static ({int cents, bool? negative})? _parseAmount(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;

    t = t.replaceAll(RegExp(r'[¥￥$,\s，]'), '');
    bool? negative;
    if (t.startsWith('-') || t.startsWith('\u2212')) {
      negative = true;
      t = t.substring(1);
    } else if (t.startsWith('+')) {
      negative = false;
      t = t.substring(1);
    }
    if (t.isEmpty) return null;

    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return (cents: (v * 100).round(), negative: negative);
  }

  static const Set<String> _expenseWords = {
    '支出', '支', '消费', '出', 'expense', 'exp', '-', 'negative',
  };
  static const Set<String> _incomeWords = {
    '收入', '收', '入账', '入', 'income', 'inc', '+', 'positive',
  };

  /// 解析「类型」列；认不出来返回 null。
  static bool? _parseKind(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    if (_expenseWords.contains(t)) return true;
    if (_incomeWords.contains(t)) return false;
    if (t.contains('支出') || t.contains('消费') || t.contains('expense')) return true;
    if (t.contains('收入') || t.contains('income')) return false;
    return null;
  }
}

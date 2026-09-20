import 'package:flutter_test/flutter_test.dart';
import 'package:suixin_pet_ledger/domain/csv/ledger_csv.dart';

void main() {
  group('LedgerCsv.encode', () {
    test('带 BOM 与表头，日期归一到分钟', () {
      final csv = LedgerCsv.encode([
        (
          at: DateTime(2026, 9, 19, 14, 30, 45),
          isExpense: true,
          isTransfer: false,
          categoryName: '餐饮',
          accountName: '支付宝',
          toAccountName: '',
          amountCents: 3250,
          note: '午饭',
        ),
      ]);

      expect(csv.startsWith(LedgerCsv.bom), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(lines.first, '日期,类型,分类,账户,转入账户,金额,备注');
      expect(lines[1], '2026-09-19 14:30,支出,餐饮,支付宝,,32.50,午饭');
    });

    test('含逗号 / 引号 / 换行的字段会被正确转义', () {
      final csv = LedgerCsv.encode([
        (
          at: DateTime(2026, 9, 19, 9, 0),
          isExpense: false,
          isTransfer: false,
          categoryName: '工资',
          accountName: '招商银行',
          toAccountName: '',
          amountCents: 1850000,
          note: '备注里有,逗号 和 "引号"',
        ),
      ]);

      // 转义后仍能被自己解析回来，证明引号处理是自洽的。
      final parsed = LedgerCsv.parse(csv);
      expect(parsed.errors, isEmpty);
      expect(parsed.rows.single.note, '备注里有,逗号 和 "引号"');
      expect(parsed.rows.single.amountCents, 1850000);
      expect(parsed.rows.single.isExpense, isFalse);
    });

    test('金额不带千分位与货币符号，保证机器往返无损', () {
      final csv = LedgerCsv.encode([
        (
          at: DateTime(2026, 1, 2, 3, 4),
          isExpense: true,
          isTransfer: false,
          categoryName: '购物',
          accountName: '现金',
          toAccountName: '',
          amountCents: 1234567,
          note: '',
        ),
      ]);
      expect(csv.contains('12345.67'), isTrue);
      expect(csv.contains('12,345.67'), isFalse);
      expect(csv.contains('¥'), isFalse);
    });

    test('文件名含时间戳', () {
      expect(LedgerCsv.fileName(DateTime(2026, 9, 19, 16, 5)),
          '随心宠记账-账单-20260919-1605.csv');
    });
  });

  group('LedgerCsv 转账', () {
    test('编码转账行带「转账」类型与转入账户', () {
      final csv = LedgerCsv.encode([
        (
          at: DateTime(2026, 9, 20, 10, 0),
          isExpense: false,
          isTransfer: true,
          categoryName: '转账',
          accountName: '招商银行',
          toAccountName: '支付宝',
          amountCents: 50000,
          note: '资金调拨',
        ),
      ]);
      final lines = csv.substring(1).split('\r\n');
      expect(
          lines[1], '2026-09-20 10:00,转账,转账,招商银行,支付宝,500.00,资金调拨');
    });

    test('解析「转账」类型并带回转入账户', () {
      final parsed = LedgerCsv.parse('日期,类型,分类,账户,转入账户,金额,备注\r\n'
          '2026-09-20 10:00,转账,转账,招商银行,支付宝,500.00,资金调拨\r\n');
      expect(parsed.errors, isEmpty);
      final r = parsed.rows.single;
      expect(r.isTransfer, isTrue);
      expect(r.isExpense, isFalse);
      expect(r.accountName, '招商银行');
      expect(r.toAccountName, '支付宝');
      expect(r.amountCents, 50000);
    });

    test('转账指纹与同金额收入/支出不同', () {
      final transfer = LedgerCsv.fingerprintOf(
        at: DateTime(2026, 9, 20, 10, 0),
        isExpense: false,
        isTransfer: true,
        amountCents: 50000,
        categoryName: '转账',
        accountName: '招商银行',
        toAccountName: '支付宝',
        note: '',
      );
      final income = LedgerCsv.fingerprintOf(
        at: DateTime(2026, 9, 20, 10, 0),
        isExpense: false,
        amountCents: 50000,
        categoryName: '转账',
        accountName: '招商银行',
        note: '',
      );
      expect(transfer, isNot(income));
    });
  });

  group('LedgerCsv.parse - 表头与别名', () {
    test('识别本 App 导出的表头', () {
      final parsed = LedgerCsv.parse('日期,类型,分类,账户,金额,备注\r\n'
          '2026-09-19 12:20,支出,餐饮,支付宝,32.50,午饭\r\n');
      expect(parsed.errors, isEmpty);
      final r = parsed.rows.single;
      expect(r.at, DateTime(2026, 9, 19, 12, 20));
      expect(r.isExpense, isTrue);
      expect(r.categoryName, '餐饮');
      expect(r.accountName, '支付宝');
      expect(r.amountCents, 3250);
      expect(r.note, '午饭');
    });

    test('识别英文 / 别名表头', () {
      final parsed = LedgerCsv.parse('date,type,category,account,amount,note\n'
          '2026-09-19 08:45,expense,交通,微信,4.00,地铁\n');
      expect(parsed.errors, isEmpty);
      expect(parsed.rows.single.categoryName, '交通');
      expect(parsed.rows.single.amountCents, 400);
      expect(parsed.rows.single.isExpense, isTrue);
    });

    test('表头前有空行也能识别', () {
      final parsed = LedgerCsv.parse('\n\n日期,金额\n2026-09-19,10.00\n');
      expect(parsed.errors, isEmpty);
      expect(parsed.rows.single.amountCents, 1000);
    });

    test('缺少日期 / 金额列时给出可读错误而不是静默空结果', () {
      final parsed = LedgerCsv.parse('分类,备注\n餐饮,午饭\n');
      expect(parsed.rows, isEmpty);
      expect(parsed.errors, hasLength(1));
      expect(parsed.errors.single.reason, contains('缺少'));
    });
  });

  group('LedgerCsv.parse - 金额', () {
    test('清洗货币符号与千分位', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '2026-09-19,"¥1,234.50"\n'
          '2026-09-19,￥88\n');
      expect(parsed.rows[0].amountCents, 123450);
      expect(parsed.rows[1].amountCents, 8800);
    });

    test('四舍五入到分', () {
      final parsed = LedgerCsv.parse('日期,金额\n2026-09-19,0.005\n');
      expect(parsed.rows.single.amountCents, 1);
    });

    test('零金额与非法金额都算异常行', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '2026-09-19,0\n'
          '2026-09-19,abc\n'
          '2026-09-19,9.90\n');
      expect(parsed.rows, hasLength(1));
      expect(parsed.rows.single.amountCents, 990);
      expect(parsed.errors, hasLength(2));
      expect(parsed.errors[0].line, 2);
      expect(parsed.errors[1].line, 3);
    });
  });

  group('LedgerCsv.parse - 方向判定', () {
    test('显式类型列优先', () {
      final parsed = LedgerCsv.parse('日期,类型,金额\n'
          '2026-09-19,收入,100.00\n'
          '2026-09-19,支出,20.00\n');
      expect(parsed.rows[0].isExpense, isFalse);
      expect(parsed.rows[1].isExpense, isTrue);
    });

    test('无类型列时按金额正负号推断', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '2026-09-19,-12.30\n'
          '2026-09-19,+50.00\n');
      expect(parsed.rows[0].isExpense, isTrue);
      expect(parsed.rows[0].amountCents, 1230, reason: '符号只表方向，金额取绝对值');
      expect(parsed.rows[1].isExpense, isFalse);
    });

    test('无类型也无符号时默认支出', () {
      final parsed = LedgerCsv.parse('日期,金额\n2026-09-19,10.00\n');
      expect(parsed.rows.single.isExpense, isTrue);
    });
  });

  group('LedgerCsv.parse - 日期', () {
    test('支持多种常见写法', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '2026-09-19 14:30,1.00\n'
          '2026/9/19 14:30:05,2.00\n'
          '2026年9月19日,3.00\n'
          '2026.09.19,4.00\n');
      expect(parsed.errors, isEmpty);
      expect(parsed.rows[0].at, DateTime(2026, 9, 19, 14, 30));
      expect(parsed.rows[1].at, DateTime(2026, 9, 19, 14, 30, 5));
      expect(parsed.rows[2].at, DateTime(2026, 9, 19));
      expect(parsed.rows[3].at, DateTime(2026, 9, 19));
    });

    test('非法日期进错误列表，不影响其它行', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '不是日期,1.00\n'
          '2026-02-30,2.00\n'
          '2026-09-19,3.00\n');
      expect(parsed.rows, hasLength(1));
      expect(parsed.errors, hasLength(2));
      expect(parsed.errors.every((e) => e.reason.contains('日期')), isTrue);
    });
  });

  group('LedgerCsv.parse - 结构', () {
    test('空行与纯空白行静默跳过', () {
      final parsed = LedgerCsv.parse('日期,金额\n'
          '\n'
          '2026-09-19,1.00\n'
          '   ,   \n'
          '2026-09-19,2.00\n');
      expect(parsed.rows, hasLength(2));
      expect(parsed.errors, isEmpty);
    });

    test('空内容返回空结果而非异常', () {
      expect(LedgerCsv.parse('').hasContent, isFalse);
      expect(LedgerCsv.parse('\n\n').hasContent, isFalse);
    });

    test('分类 / 账户列为空时留空，交由仓库兜底', () {
      final parsed = LedgerCsv.parse('日期,金额\n2026-09-19,1.00\n');
      expect(parsed.rows.single.categoryName, '');
      expect(parsed.rows.single.accountName, '');
    });
  });

  group('LedgerCsv.fingerprint', () {
    test('忽略秒（导出只到分钟，避免与库内容对不上）', () {
      final a = LedgerCsv.fingerprintOf(
        at: DateTime(2026, 9, 19, 14, 30, 10),
        isExpense: true,
        amountCents: 100,
        categoryName: '餐饮',
        accountName: '现金',
        note: 'x',
      );
      final b = LedgerCsv.fingerprintOf(
        at: DateTime(2026, 9, 19, 14, 30, 59),
        isExpense: true,
        amountCents: 100,
        categoryName: '餐饮',
        accountName: '现金',
        note: 'x',
      );
      expect(a, b);
    });

    test('任一字段不同则指纹不同', () {
      final base = LedgerCsv.fingerprintOf(
        at: DateTime(2026, 9, 19, 14, 30),
        isExpense: true,
        amountCents: 100,
        categoryName: '餐饮',
        accountName: '现金',
        note: 'x',
      );
      expect(
        LedgerCsv.fingerprintOf(
          at: DateTime(2026, 9, 19, 14, 30),
          isExpense: false,
          amountCents: 100,
          categoryName: '餐饮',
          accountName: '现金',
          note: 'x',
        ),
        isNot(base),
      );
      expect(
        LedgerCsv.fingerprintOf(
          at: DateTime(2026, 9, 19, 14, 30),
          isExpense: true,
          amountCents: 101,
          categoryName: '餐饮',
          accountName: '现金',
          note: 'x',
        ),
        isNot(base),
      );
    });
  });
}

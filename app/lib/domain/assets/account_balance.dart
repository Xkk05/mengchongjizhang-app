/// 账户余额模型 —— 纯数据，不依赖数据层类型，便于单测。
library;

/// 一个资金账户的实时余额。
///
/// 余额一律由「初始余额 + 流水净额」派生，记账 / 改账 / 删账都天然一致，
/// 不会出现账户余额与流水对不上的情况。
class AccountBalance {
  const AccountBalance({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.initialCents,
    required this.flowCents,
    required this.txCount,
    required this.includedInNetWorth,
  });

  final int id;
  final String name;
  final String iconKey;
  final int colorValue;

  /// 建档时填的初始余额（分）。
  final int initialCents;

  /// 该账户流水净额（分）= 收入 − 支出。
  final int flowCents;

  /// 该账户下的账目笔数。
  final int txCount;

  final bool includedInNetWorth;

  /// 实时余额（分）。
  int get balanceCents => initialCents + flowCents;

  AccountBalance copyWith({int? flowCents, int? txCount}) => AccountBalance(
        id: id,
        name: name,
        iconKey: iconKey,
        colorValue: colorValue,
        initialCents: initialCents,
        flowCents: flowCents ?? this.flowCents,
        txCount: txCount ?? this.txCount,
        includedInNetWorth: includedInNetWorth,
      );

  /// 净资产 = 计入统计的账户余额之和。
  static int netWorth(Iterable<AccountBalance> accounts) => accounts
      .where((a) => a.includedInNetWorth)
      .fold<int>(0, (sum, a) => sum + a.balanceCents);
}

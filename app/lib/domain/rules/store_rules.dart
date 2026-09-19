/// 商店 / 背包的规则校验 —— 纯函数，便于单测。
library;

/// 一次「能不能做」的判定结果。
class PurchaseResult {
  const PurchaseResult.ok()
      : ok = true,
        reason = '';

  const PurchaseResult.reject(this.reason) : ok = false;

  final bool ok;

  /// 被拒绝的原因（可直接展示给用户）；通过时为空串。
  final String reason;
}

class StoreRules {
  const StoreRules._();

  /// 金币够不够买。
  static PurchaseResult canBuy({required int coin, required int priceCoin}) {
    if (priceCoin <= 0) return const PurchaseResult.reject('商品价格异常');
    if (coin < priceCoin) {
      return PurchaseResult.reject('金币还差 ${priceCoin - coin} 个，先记几笔账吧');
    }
    return const PurchaseResult.ok();
  }

  /// 背包里有没有可用的道具。
  static PurchaseResult canUse({required int quantity}) => quantity > 0
      ? const PurchaseResult.ok()
      : const PurchaseResult.reject('背包里没有这件道具');
}

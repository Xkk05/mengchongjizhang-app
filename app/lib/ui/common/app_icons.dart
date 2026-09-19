import 'package:flutter/material.dart';

/// 分类 / 账户的 `iconKey` 到图标字形的映射。
///
/// 图标 key 存在数据库里，UI 层负责解析 —— 换图标主题不用迁移数据。
const Map<String, IconData> kIconRegistry = <String, IconData>{
  // 支出分类
  'fork': Icons.restaurant_rounded,
  'bus': Icons.directions_bus_rounded,
  'bag': Icons.shopping_bag_rounded,
  'game': Icons.sports_esports_rounded,
  'home': Icons.home_rounded,
  'paw': Icons.pets_rounded,
  'heart': Icons.favorite_rounded,
  'more': Icons.more_horiz_rounded,
  // 收入分类
  'pay': Icons.payments_rounded,
  'job': Icons.work_rounded,
  'invest': Icons.trending_up_rounded,
  // 账户
  'wallet': Icons.account_balance_wallet_rounded,
  'alipay': Icons.currency_yuan_rounded,
  'wechat': Icons.chat_bubble_rounded,
  'bank': Icons.account_balance_rounded,
  // 功能入口
  'chart': Icons.pie_chart_rounded,
  'calendar': Icons.calendar_month_rounded,
  'budget': Icons.savings_rounded,
  'asset': Icons.donut_large_rounded,
  'gift': Icons.card_giftcard_rounded,
  'store': Icons.storefront_rounded,
  'backpack': Icons.backpack_rounded,
  'ai': Icons.auto_awesome_rounded,
  'scan': Icons.qr_code_scanner_rounded,
  'robot': Icons.smart_toy_rounded,
  'mic': Icons.mic_rounded,
  'checkin': Icons.event_available_rounded,
  // 商店商品
  'fish': Icons.set_meal_rounded,
  'can': Icons.kitchen_rounded,
  'cookie': Icons.cookie_rounded,
  'ribbon': Icons.celebration_rounded,
  'bell': Icons.notifications_active_rounded,
  'crown': Icons.workspace_premium_rounded,
  'sakura': Icons.local_florist_rounded,
  'night': Icons.nightlight_round,
};

IconData iconFor(String key) => kIconRegistry[key] ?? Icons.circle_outlined;

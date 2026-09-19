import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'state/theme_provider.dart';
import 'ui/assets/assets_page.dart';
import 'ui/backpack/backpack_page.dart';
import 'ui/budget/budget_page.dart';
import 'ui/calendar/calendar_page.dart';
import 'ui/checkin/checkin_page.dart';
import 'ui/data/data_page.dart';
import 'ui/ledger/ledger_page.dart';
import 'ui/profile/profile_page.dart';
import 'ui/shell/app_shell.dart';
import 'ui/stats/stats_page.dart';
import 'ui/store/store_page.dart';

/// 全局路由：两个分支（明细 / 我的），由 StatefulShellRoute 维护各自的栈。
final GoRouter appRouter = GoRouter(
  initialLocation: '/ledger',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ledger',
              builder: (context, state) => const LedgerPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    // 统计 / 资产 / 预算压在导航外壳之上，全屏展示。
    GoRoute(
      path: '/stats',
      builder: (context, state) => const StatsPage(),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) => const AssetsPage(),
    ),
    GoRoute(
      path: '/budget',
      builder: (context, state) => const BudgetPage(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarPage(),
    ),
    // 养成闭环：签到 → 商店 → 背包。
    GoRoute(
      path: '/checkin',
      builder: (context, state) => const CheckinPage(),
    ),
    GoRoute(
      path: '/store',
      builder: (context, state) => const StorePage(),
    ),
    GoRoute(
      path: '/backpack',
      builder: (context, state) => const BackpackPage(),
    ),
    // 数据管理：账单 CSV 导出 / 导入。
    GoRoute(
      path: '/data',
      builder: (context, state) => const DataPage(),
    ),
  ],
);

class SuixinPetApp extends ConsumerWidget {
  const SuixinPetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '随心宠记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: appRouter,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

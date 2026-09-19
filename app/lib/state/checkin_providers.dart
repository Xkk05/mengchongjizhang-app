import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../domain/rules/checkin_rules.dart';
import 'providers.dart';

/// 最近一次签到（从没签过则为 null）。
final latestCheckinProvider = StreamProvider<Checkin?>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchLatestCheckin();
});

/// 最近的签到记录（倒序）。
final checkinHistoryProvider = StreamProvider<List<Checkin>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchCheckins();
});

/// 签到面板状态（纯计算，随最近签到记录自动刷新）。
final checkinStateProvider = Provider<CheckinState>((ref) {
  final latest = ref.watch(latestCheckinProvider).value;
  return CheckinState.resolve(
    lastStreak: latest?.streak ?? 0,
    lastDay: latest?.day,
    today: DateTime.now(),
  );
});

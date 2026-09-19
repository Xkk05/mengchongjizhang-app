import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 中文日期 / 星期由 DateLabels 手写拼接，无需初始化 intl locale 数据。
  runApp(const ProviderScope(child: SuixinPetApp()));
}

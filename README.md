# 随心宠记账

一款「萌宠养成 + 记账」的双端 App（对标「团团记账」），Flutter 单代码库实现（Android + iOS）。

## 特性

- **快速记账**：收支 / 转账、分类、账户、备注，自绘数字键盘 + 常驻保存键
- **萌宠养成**：宠物随记账获得经验与金币，体型随等级成长，可装备头饰 / 项圈 / 场景皮肤
- **状态化动作**：宠物饿了揉肚子、深夜打哈欠、吃饱哼歌（判定收在纯函数，演出用独立低频控制器）
- **数据统计**：分类环形图、近 7 日趋势、账单日历、预算管控
- **账单导入导出**：CSV 导出（带 BOM，Excel 不乱码）+ 导入预览与自动去重
- **深色模式**：设计令牌体系，浅 / 深两套主题同源切换

## 技术栈

Flutter / Dart · Riverpod · Drift（本地库）· go_router · fl_chart

## 目录结构

- `app/` — Flutter 工程，分层：`ui → state → data/domain → core`
- `prototype/` — 高保真 HTML 原型（工作版 `index.html`、演示版 `demo.html`）

## 运行

```bash
cd app
flutter pub get
flutter run
```

## 测试

```bash
cd app
flutter test
```

# 随心宠记账 · Flutter App（v0.9 状态化动作里程碑）

## 一句话
从 HTML 原型落成**可编译、可跑通的真 Flutter 工程**：设计令牌 → Drift 本地库 → Riverpod 状态层 → 导航外壳 → 场景主页 + 记账核心 + 统计可视化 + 资产 / 预算管理 + 签到 / 商店 / 背包养成闭环 + 装扮真实穿在宠物身上 + 宠物随等级长大 / 待机有动作 + 账单 CSV 导出与导入 + 按月铺开每天的账单日历 + **宠物会看状态与时段演不同小动作（饿了摸肚子、深夜打哈欠、吃饱哼歌）** + **核心页 UI 精致化（字号放大、圆角更圆、背景文字中性化、卡片柔和阴影）**，全链路打通并通过静态分析、单元/组件/数据层测试、真机目标构建。

---

## 技术栈（实际落盘版本）

| 项 | 版本 |
|---|---|
| Flutter | 3.44.1 stable |
| Dart | 3.12.1 |
| 状态管理 | flutter_riverpod **3.4.3** |
| 本地库 | drift **2.35.0** + drift_flutter 0.3.1（代码生成 drift_dev） |
| 路由 | go_router 17.5.0 |
| 图表 | fl_chart 1.2.0（统计页：分类环形图 + 近 7 日柱状图） |
| 文件互通 | file_picker 13.1.0（选 CSV 导入）、share_plus 13.3.0（导出后系统分享） |
| 国际化 | flutter_localizations（`MaterialApp` 中文本地化）；日期标签改为**纯 Dart 拼接**，运行期不再依赖 intl locale 初始化 |
工程位置：`app/`，包名 `suixin_pet_ledger`，应用 id `com.suixinpet.suixin_pet_ledger`。
平台：Android + iOS（另建了 web 目标，仅用于本地编译校验，不作交付平台）。

---

## 目录结构（分层）

```
app/lib/
├── main.dart                      # 入口：ProviderScope（日期格式化已不依赖 locale 初始化）
├── app.dart                       # MaterialApp.router + 浅/深主题 + go_router（/ledger /profile + /stats /assets /budget /calendar /checkin /store /backpack /data）
├── core/
│   ├── theme/
│   │   ├── app_tokens.dart        # 设计令牌：色板 / 圆角5档 / 字号8档 / 间距
│   │   └── app_theme.dart         # 由令牌构建 ThemeData（浅色 + 深色）
│   └── utils/
│       ├── money.dart             # 金额以「分」整数存储，展示层转元
│       └── date_labels.dart       # 今天/昨天/M月d日 星期X 分组标签（纯 Dart）
├── domain/
│   ├── rules/pet_rules.dart       # 养成规则引擎（纯函数：经验/升级/阶段/使用食物结算 + 体型成长/表情判定/状态化动作判定）
│   ├── rules/checkin_rules.dart   # 签到规则（纯函数：7 日周期奖励表 / 连击 / 可否签到 / 面板状态）
│   ├── rules/store_rules.dart     # 商店规则（纯函数：金币是否够买 / 背包是否有可用道具）
│   ├── rules/decor_rules.dart     # 装扮外观映射（纯函数：商品 code → 饰品 / 场景皮肤枚举）
│   ├── csv/ledger_csv.dart        # 账单 CSV 序列化与解析（纯函数：导出编码 / 导入解析 / 指纹去重键）
│   ├── calendar/month_calendar.dart # 账单日历（纯函数：月历网格 / 每日收支聚合 / 最高支出日 / 紧凑金额）
│   ├── stats/ledger_stats.dart    # 统计聚合（纯函数：分类占比 / 逐日收支 / 合计）
│   ├── assets/account_balance.dart# 账户余额模型（余额 = 初始 + 流水净额；净资产合计）
│   └── budget/budget_plan.dart    # 预算计划（纯函数：使用率 / 剩余 / 超支判定 / 排序）
├── data/
│   ├── db/
│   │   ├── tables.dart            # Drift 表定义（9 张，含 store_items.decorSlot 佩戴位）
│   │   ├── database.dart          # @DriftDatabase + 迁移(v1→v4) + 种子数据（含商品目录）
│   │   └── database.g.dart        # 代码生成产物（勿手改）
│   └── repositories/ledger_repository.dart   # 连表查询 + 区间流 + 账户/预算读写 + 商店/背包/签到事务 + 账单导出与导入
├── state/
│   ├── providers.dart             # 数据库 / 仓库 provider
│   ├── ledger_providers.dart      # 账目流、月度汇总、账户、宠物
│   ├── stats_providers.dart       # 统计方向 + 分类切片/合计/趋势 provider
│   ├── calendar_providers.dart    # 日历网格 + 选中日（换月自动重置）
│   ├── month_provider.dart        # 全局「当前月份」（统计页与预算页共享）
│   ├── asset_providers.dart       # 账户实时余额 / 净资产
│   ├── budget_providers.dart      # 预算记录 + 预算执行计划
│   ├── shop_providers.dart        # 商店目录 + 背包派生（食物 / 装扮 / 使用中装扮）
│   ├── checkin_providers.dart     # 最近签到 + 签到历史 + 签到面板状态
│   └── theme_provider.dart        # 浅/深主题切换
└── ui/
    ├── shell/app_shell.dart       # 底部导航（明细/＋/我的）+ 中央悬浮红钮
    ├── home/pet_view.dart         # 宠物与场景：纯 CustomPainter 绘制 + 呼吸/眨眼/摆尾动画 + 体型随等级成长 + 表情随饱食心情变化 + 状态化动作演出（摸肚子/打哈欠/哼歌）+ 装扮叠加 + 场景皮肤
    ├── ledger/
    │   ├── ledger_page.dart       # 明细：按日分组、滑动删除、快捷入口（统计/资产/预算/签到/商店）
    │   └── widgets/scene_header.dart   # 场景头（宠物+悬浮入口+余额速览，左右各三个入口）
    ├── record/record_sheet.dart   # 快速记账面板（分类格+自绘键盘+账户）
    ├── stats/stats_page.dart      # 统计：月份条 + 收支切换 + 分类环形图 + 排行 + 近7日柱状图
    ├── calendar/calendar_page.dart# 账单日历：月度汇总 + 每日收支网格 + 点选某天看当天明细
    ├── assets/assets_page.dart    # 资产：净资产 + 账户列表 + 增删改（含初始余额）
    ├── budget/budget_page.dart    # 预算：总预算进度 + 分类预算 + 超支标记 + 增删改
    ├── checkin/checkin_page.dart  # 签到：连续天数卡 + 7 日周期格 + 签到按钮 + 历史记录
    ├── store/store_page.dart      # 商店：食物/装扮分类切换 + 商品格（价格 / 效果 / 购买）
    ├── backpack/backpack_page.dart# 背包：食物（使用）/ 装扮（装备，同类唯一）
    ├── data/data_page.dart        # 数据管理：账单 CSV 导出（分享 / 复制）+ 导入（选文件 → 预览 → 确认）
    ├── profile/profile_page.dart  # 我的：养成卡、金币与喂食、养成三入口、资产、数据管理、深色模式开关
    └── common/                    # AppCard / SoftIcon / 图标注册表 / MonthBar / CoinChip
```

**依赖方向**：`ui → state → data/domain`，`core` 被各层单向依赖。UI 不直接碰 Drift。

---

## 数据模型（9 张表，schemaVersion = 4）

- `ledgers` 账本（默认「日常账本」）
- `accounts` 资金账户（现金 / 支付宝 / 微信 / 招行，带**初始余额**与颜色）
- `categories` 分类（支出 8 个 + 收入 4 个，图标用 `iconKey` 存字符串，UI 层解析）
- `transactions` 账目流水（金额恒为正的「分」，收支方向由 `kind` 决定）
- `pet_states` 宠物养成态（等级 / 经验 / 金币 / 饱食 / 心情，单例行）
- `budgets` 预算（月份键 `yearMonth` + 可空 `categoryId`，为空即该月总预算）
- `store_items` 商店商品目录（8 件：3 食物 + 5 装扮，`code` 为稳定契约，签到奖励引用它；装扮带 `decorSlot` 佩戴位）
- `inventories` 背包（**每件商品最多一行**，重复购买只加数量，`equipped` 标记装扮在用）
- `checkins` 签到记录（一天一条，存连击天数与本次金币 / 道具奖励）

关键设计取舍：
- **金额用 int「分」**，杜绝浮点误差；解析与格式化集中在 `Money`。
- **账户余额是派生值**：`accounts` 只存建档时的初始余额，当前余额 = 初始余额 + 该账户流水净额。
  这样记账 / 改账 / 删账天然一致，不会出现「余额和流水对不上」。
- **分类图标存 key 不存码位**，换图标主题不需要数据迁移。
- **记账与宠物奖励同一事务**：写流水 + 结算经验金币，原子性保证「记了账却没长经验」不会发生。
- 编辑一笔账**不重复发奖励**。
- **预算按「月份 + 分类」唯一**，`setBudget` 是幂等 upsert（有则改金额、无则新增），
  不会因为反复设置同一分类而堆出多条记录。
- **购买 / 使用 / 签到全部在事务里结算**：扣币 + 入包、吃食物 + 属性结算、发奖励 + 发道具，
  任一环失败整体回滚，不会出现「扣了钱没拿到货」。
- **商品用 `code` 而不是 id 做逻辑锚点**：签到奖励表引用 `food_fish` / `decor_ribbon` 这类稳定字符串，
  改商品名、调价格都不影响奖励发放；商品目录是**结构性数据**，与演示种子数据开关无关，永远会播。
- **装扮按「佩戴位」互斥，而不是全局唯一**：`decorSlot` 分 `head` / `neck` / `scene` 三档，
  同一位置只留一件在用，不同位置可同时生效 —— 所以能戴着王冠 + 铃铛 + 星空背景一起记账。
  绘制层只认 `PetAccessory` / `SceneSkin` 两个枚举，`code → 枚举` 的映射收在 `DecorRules` 里：
  以后加商品只要补一行映射，绘制代码不用动；遇到不认识的 code 静默不画，不会因为服务端上了新商品就崩页面。
- **金币在购买时扣，用食物时不再收钱**：避免「吃一口扣两次」的歧义，`onUseFood` 只结算属性。
- **v1 → v2 迁移**：`accounts.balance_cents` 重命名为 `initial_balance_cents`（旧值保留为初始余额），
  并新建 `budgets` 表。**v2 → v3 迁移**：新建 `store_items` / `inventories` / `checkins` 三表并播商品目录。
  老装机数据不会丢。
- **新手礼包 60 金币**：首次建档即送（`welcomeCoin`），否则新用户要记几十笔才买得起第一件商品。

---

## 已实现功能

- **记账**：新增 / 编辑 / 删除（滑动删除带二次确认），支出/收入切换，分类、账户、日期、备注齐全。
- **明细**：按天分组，每天显示收/支小计，行内展示分类图标、账户、时间、金额（带正负号）。
- **场景主页**：天空-远山-草甸三层渐变 + 云 + 日光晕，宠物居中且带呼吸浮动，左右各三个悬浮入口（左：统计 / 预算 / 日历；右：商店 / 背包 / 签到），顶部金币与等级经验条，底部余额速览（本月收入/支出/结余）。
- **统计**：可翻月份（不允许翻到未来）+「支出/收入」方向切换；分类占比环形图（中心显示合计，前 6 类 + 「其他」合并）、分类排行（笔数 / 金额 / 占比进度条）、近 7 日收支双色柱状图；无数据时三张卡各自显示空态。
- **资产**：净资产合计卡（含账户数与流水净额）+ 账户列表；新增 / 编辑账户（名称 / 图标 / 颜色 / 初始余额），滑动删除。余额随流水实时变化，负余额带负号展示。
- **预算**：可翻月份；总预算卡显示已用 / 上限 / 剩余与使用率，超支时进度条转红并提示超支金额；分类专项预算按使用率降序排列，逐条显示「已用 / 上限 + 进度条 + 百分比 + 超支标记」；可增删改，且同一分类同月只会有一条预算。
- **签到**：连续签到天数卡 + 7 日周期奖励格（已领打勾、下一格高亮、带道具的格子显示礼盒图标）+ 签到按钮 + 最近 14 天记录；同日不可重复签，断签连击归零、奖励回到第 1 天，第 3 / 5 / 7 天额外送道具。
- **商店**：食物 / 装扮两分类切换，商品格展示图标、名称、说明、使用效果与价格，金币不足时给出「还差 N 个」的提示而不是静默失败；已拥有的商品标出「已有 ×N」并把按钮改成「再买」。
- **背包**：食物与装扮分区展示；食物显示数量并可「使用」（消耗 1 个，结算饱食 / 经验 / 心情），装扮可「装备 / 脱下」（不消耗，**同一佩戴位只留一件在使用**，不同佩戴位可同时生效）。
- **装扮上身后真的看得见**：头饰（红蝴蝶结 / 小王冠）画在宠物头顶、金铃铛挂成项圈、场景皮肤直接换主页背景 —— 樱花庭院是粉雾 + 飘落花瓣，星空夜是深蓝夜空 + 弯月 + 星星。装扮全部由 `CustomPainter` 代码绘制，仍然零图片资源；「我的」页的宠物预览同步穿着。
- **账单日历**：按月铺出整月网格（周一起头、首尾自动补上邻月日期并灰掉），每格显示当天日号与紧凑金额 —— 有支出显示支出、只有收入才显示收入，颜色区分方向；今天描边、选中高亮。顶部是本月概览（支出 / 收入 / 结余）与「花得最多的一天」，点任意一天在下方看当天明细（分类图标 + 备注 + 账户 + 时间 + 带符号金额）。月份与统计页 / 预算页共享，翻月互相同步；翻到历史月份不预选日期，避免「翻到 3 月却高亮着今天」的错位。
- **数据管理（账单导入导出）**：导出一键把全部流水写成带 BOM 的 CSV（Excel 双击不乱码），可走系统分享或复制到剪贴板；导入可选 CSV 文件，**先出预览再落库** —— 预览里摊开「可导入多少笔 / 跳过多少重复 / 有哪些异常行（带行号）/ 会自动新建哪些分类与账户」，确认后才写。表头认中文与常见英文别名（交易时间 / 收支 / 支付方式 …），金额自动清洗货币符号与千分位、按正负号或「类型」列判方向；日期支持 `2026-09-19 14:30`、`2026/9/19`、`2026年9月19日` 等写法；认不出的行跳过并标行号，不影响其余行。
- **养成**：每记一笔 +10 经验 +2 金币，经验满自动升级（支持一次跨多级），可喂食消耗金币换经验与饱食度；分幼崽/成长/少年/成熟/大师五阶段。
- **宠物会「长大」也会「有小动作」**：体型随等级平滑变化（幼崽头大身小、大师趋于匀称），且以脚为锚点向上生长，不会在长大时整体下沉；待机时有**呼吸浮动 + 定时眨眼 + 尾巴左右摆**三种动作，全部由同一个动画控制器派生相位，天然同步。**表情还会跟着状态走** —— 饱食与心情都够时嘴角上扬、眼睛眯成弧；饿或心情差时眼睛缩小、嘴角下垂、胡须无精打采。等级数据来自 `pet_states`，闹情绪的判定是纯函数（`PetRules.isHappy` / `isDown`），绘制层只负责画。
- **宠物还有「状态化动作」**：在通用待机之上叠加一组触发式演出 —— **饿了**（饱食 < 25）会用小爪揉肚子、肚皮旁冒「咕噜」弧线；**深夜**（22 点后到清晨 6 点前）会闭眼张嘴打哈欠、头顶飘 Zzz；**吃饱且心情好**（心情 ≥ 70 且饱食 ≥ 60）会眯眼哼歌、头顶飘音符。动作判定是纯函数 `PetRules.actionFor(mood, hunger, hour)`（饿 > 困 > 满足 > 待机），演出相位用低频独立控制器驱动（前 40% 时间做一次 0→1→0 起伏），呼吸/眨眼/摆尾的节奏不受影响；「我的」页静态预览也会按状态定格（不传 hour，只看饱食心情）。
- **我的**：养成进度卡（经验条/饱食条）、金币与喂食、**养成三入口（签到 / 商店 / 背包）**、资产账户列表与净资产合计、**深色模式开关**。

---

## 验证结果

| 检查 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!**（0 error / 0 warning / 0 info） |
| `flutter test` | **226 项全部通过**（金额 7、账户余额 6、预算计划 10、统计聚合 10、养成规则 14、签到规则 16、商店规则 5、装扮映射 5、宠物成长规则 9、**账单日历 15**、**状态化动作规则 10**、组件 4、统计页 4、资产页 4、预算页 4、签到页 5、商店页 5、背包页 4、宠物装扮渲染 5、宠物成长渲染与动画 7、**账单日历页 9**、**状态化动作绘制 5**、账单 CSV 解析 21、账单导入导出数据层 15、数据管理页 8、数据层养成闭环 19） |
| Drift 代码生成 | 通过，产出 `database.g.dart`（含 StoreItems.decorSlot 与全部 Companion） |
| `flutter build apk --debug` | **✅ 构建成功，产出 `app-debug.apk`（178.8 MB）** |

产物路径：`app/build/app/outputs/flutter-apk/app-debug.apk`（可直接 `adb install` 到 Android 真机）。

测试覆盖的九个面：
1. `Money` 的解析边界（空串、非法字符、千分位、四舍五入到分、负数）；
2. `AccountBalance` 的派生逻辑（初始 + 净额、负余额、净资产排除不计入账户）；
3. `BudgetPlan` 的聚合（总预算用当月总额、分类用分类额、非正额度忽略、按使用率降序、超支判定与进度条封顶）；
4. `CheckinRules` / `CheckinState` 的周期与连击（7 日循环、第 3/5/7 天道具、同日不可重签、隔天延续、断签归零）；
5. `PetRules` / `StoreRules` / `DecorRules` 的规则层（跨级升级、等级封顶、饱食心情封顶、金币校验与错误文案、code → 外观枚举映射与未知 code 兜底；**体型随等级单调且不越界、各等级头身比符合预期、`isHappy` 与 `isDown` 在全部状态组合下互斥、百分比换算对非正上限安全**）；
6. 统计 / 资产 / 预算 / 签到 / 商店 / 背包 / 宠物装扮七页（含场景皮肤）的渲染与交互在浅/深色下均不抛异常；**宠物在各等级、各饱食/心情组合、眨眼与摆尾两个相位极值下都能正常绘制，画布尺寸恒定不抖动，跑完整呼吸周期与 `enabled:false` 静态分支都不崩**；
7. **数据层端到端**：用 `NativeDatabase.memory()` 起真库跑完整养成闭环 —— 购买扣币与余额不足拦截、重复购买只加数量、食物消耗与属性结算、**同佩戴位互斥 / 不同佩戴位共存 / 脱下不影响他人**、签到发奖与连击、第 3 天发道具、断签重置、历史倒序。
8. **账单导入导出**：CSV 编码（BOM / 逗号引号换行转义 / 金额无千分位无损往返）与解析（中英文表头别名、金额清洗与正负号、类型列优先、多种日期写法、非法日期与 2 月 30 日的拒绝、零/非法金额、空行跳过、缺列报错）；数据层真库端到端（导出全量、导出→再导入全判重复、缺分类缺账户自动建档、空字段兜底到其他/现金、**计数去重**（库内 1 条 + 文件 2 条 → 跳 1 导 1）、异常行不阻断好行、导入不发养成奖励）；数据管理页与导入预览弹层的渲染与禁用态。
9. **账单日历**：日期算术（各月天数与闰年、周一开头的前置空格逐月校验、同日判断）、网格结构（恒为 7 的整数倍、整月每天各出现一次、首尾补位标记且不带数据）、每日聚合（支出累加 / 收入分列 / 笔数、只有收入时优先显示收入、有支出时优先显示支出、其它月与去年同月一律不参与）、支出最高的一天、紧凑金额三档降精度；页面侧（周标题与月份条、逐日格子存在、汇总求和、格子紧凑金额、默认选中今天、点选切换明细、最高支出提示、空态、翻到历史月份不预选）。
10. **状态化动作**：`actionFor` 的判定优先级（饿 > 困 > 满足 > 待机）、阈值边界（饱食 25 / 心情 70 + 饱食 60 / 深夜 22 点与清晨 5 点 / 6 点与 21 点不算困）、`hour=-1` 不看时段的兜底；绘制侧（四种动作 × 多个相位渲染不抛异常、深色下三种演出不抛异常、带动作的呼吸宠物跑完演出周期、待机与演出之间切换、`enabled:false` 静态分支带动作渲染）。

---

## 如何运行

```bash
cd app
flutter pub get
dart run build_runner build        # 改动表结构后需重跑，生成 database.g.dart
flutter run                        # 连接 Android 设备/模拟器，或 iOS 模拟器
flutter test                       # 跑测试
flutter build apk --debug          # 出调试包
```

---

## 本机环境注意事项（踩过的坑）

### ⚠️ 最坑的一个：代理变量会让 Android 构建失败

本机环境注入了 `HTTP_PROXY`，而该代理对 github.com 返回 **502 Bad Gateway**。Dart 的 HttpClient 会自动使用它，于是 `sqlite3` 包在编译 Android 原生库时**无法从 GitHub Releases 下载 `libsqlite3.<abi>.android.so`**，报：

```
Proxy failed to establish tunnel (502 Bad Gateway), uri = //github.com:443
Building assets for package:sqlite3 failed.
Target dart_build failed: Error: Building native assets failed.
> Task :app:compileFlutterBuildDebug FAILED
```

**这个失败会表现为"卡住"** —— 第一次构建时它在这个下载上挂了 19 分钟没有任何输出，极易误判成 Gradle 卡死。

**修复（已验证）**：跑构建前清掉代理变量。直连是通的（已验证 github.com / sqlite.org 均返回 200）。

```powershell
Remove-Item Env:HTTP_PROXY,Env:HTTPS_PROXY,Env:ALL_PROXY,Env:http_proxy,Env:https_proxy,Env:all_proxy -ErrorAction SilentlyContinue
$env:NO_PROXY = "*"
```

清掉后 `flutter build apk --debug` 一次通过（约 5 分钟）。

### ⚠️ 第二个坑：`flutter test` 的本地回环被代理拦成 WebSocket 报错

测试进程通过 **本地回环 WebSocket** 与 `flutter_tester` 通信。工具沙箱会给子进程注入 `HTTP_PROXY=http://127.0.0.1:<port>`，于是 Dart 的 `HttpClient` 把回环握手也发给代理，代理不认 WebSocket 升级，报：

```
Unable to connect to flutter_tester process: WebSocketException:
Invalid WebSocket upgrade request
```

**关键点**：放宽沙箱**并不能**解决（代理是沙箱注入的）；`NO_PROXY="*"` 也无效 —— Dart 的 `findProxyFromEnvironment` **不把 `*` 当通配符**，必须写具体主机。

**修复（已用最小脚本复现验证）**：让回环直连，显式列出主机 ——

```powershell
$env:no_proxy = "127.0.0.1,localhost,::1"
$env:NO_PROXY = "127.0.0.1,localhost,::1"
```

设完之后 `flutter test` 立即恢复正常（本次 98 项全过）。
> 注意：这两条是**只针对回环**的绕过，别顺手把 `HTTP_PROXY` 也清空去跑 `pub get` —— 下载依赖仍需代理出网。

### 其余环境约束

1. **`flutter.bat` / `dart.bat` 在工具 shell 里跑不了** —— 批处理需要 cmd.exe，被工具沙箱拦截，表现为静默退出码 1、零输出，很容易误以为"Flutter 没装好"。**替代方案（已验证）**：直接让 dart 跑 flutter_tools 快照 ——
   ```powershell
   $env:FLUTTER_ROOT = "C:\Users\admin\develop\flutter"
   $dx   = "C:\Users\admin\develop\flutter\bin\cache\dart-sdk\bin\dart.exe"
   $snap = "C:\Users\admin\develop\flutter\bin\cache\flutter_tools.snapshot"
   & $dx $snap <flutter 子命令>          # analyze / test / build apk / pub add / create
   ```
   注：`.bat` 本身没问题，Gradle 的 JVM 调用 `flutter.bat` 是正常的 —— 受限的只是工具 shell 这个上下文。
2. **工具 shell 的 stdout 不回显** —— 本机 PowerShell 工具拿不到子进程标准输出。**规避**：把输出 `| Out-File <日志> -Encoding utf8` 落盘，再用 Read 工具看。**不要用 `*>`**，它会写成 UTF-16，Read 认不出。
3. **同一文件不要并发写** —— 并行发起两个针对同一文件的 Edit 会出现「后写覆盖前写」，其中一次静默丢失。改同一文件的多处内容要**串行**。
4. **`flutter build apk` 建议放宽沙箱** —— Gradle daemon 需要访问 `~/.gradle` 与 Android SDK，并拉起本地 Gradle 守护进程。
5. Flutter 从 `storage.flutter-io.cn` 镜像拉资源，`git fetch --tags` 报错不影响功能。
6. `flutter_localizations` 会把 `intl` 钉死在 0.20.2，pubspec 里 `intl` 约束不能高于它，否则依赖求解失败。
7. 需要 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 指向 `%LOCALAPPDATA%\Android\Sdk`（Gradle 会自动补装缺失的 SDK Platform）。
8. **别在运行期依赖 intl 的 locale 数据** —— `DateFormat('zh_CN')` 未初始化 locale 时会在 widget 里抛 `LocaleDataException`。日期标签已改成纯 Dart 拼接（`DateLabels`），启动时不再需要 `initializeDateFormatting`。
9. **widget 测试的字体宽度会被放大** —— 测试环境没有真字体，每个字形按 `fontSize` 见方计算，中文/数字混排的实际宽度比真机大约 1.4 倍。一排「名称 + 徽标 + 金额」的 Row 在真机没问题，在测试里就可能 `RenderFlex overflowed`。**修法**：标题类文本一律 `Expanded + ellipsis`，长数字组合用 `FittedBox(scaleDown)`，别靠「看着够宽」蒙过去。
10. **纯逻辑页面也要覆盖依赖** —— 商店 / 背包页虽然有 AppBar 金币胶囊，胶囊依赖宠物 provider。widget 测试里把 `petStateProvider` 一并 override 成固定值，避免真数据库在测试进程里被拉起。
11. **`setSurfaceSize` 必须在测试体内调用，不能放 `setUp`** —— 它走 `TestAsyncUtils` 守卫，在 `setUp` 里会抛「Guarded function conflict」，8 个用例一起挂。正确写法：测试方法开头 `await tester.binding.setSurfaceSize(...)` + `addTearDown(() => tester.binding.setSurfaceSize(null))`。
12. **`file_picker` 13.x 换了 API** —— 不再是 `FilePicker.platform.pickFiles()`，改为静态方法 `FilePicker.pickFiles()` / `FilePicker.pickFile()`；`PlatformFile` 去掉了 `bytes` 字段，内容统一用 `await file.readAsBytes()`（file / content / blob 各来源都覆盖），文件路径要用 `file.path`（远端来源时为 null）。
13. **新增原生插件后 Gradle 可能报 `transforms\<hash>.lock (拒绝访问)`** —— 新插件要求 Gradle 在 `~/.gradle/caches/<版本>/transforms` 里**新建** transform 与锁文件，而这步由 Gradle 拉起的独立 daemon 进程执行，在受限身份下没有写权限。表现是配置阶段直接失败、且只在"刚加了插件"后出现（旧插件的 transform 早已算好，所以之前一直正常）。**解法是两件事一起做**：构建在沙箱外执行 + `GRADLE_OPTS=-Dorg.gradle.daemon=false` 让 Gradle 不起独立 daemon。只做其中一件仍然失败。代价是构建变慢（本次 291s，平时约 65s）。

---

## 与原型的对应关系

原型的功能里，本里程碑已落 **11 个界面**（主页场景 / 账单明细 / 我的 / 统计 / 资产 / 预算 / 账单日历 / 签到奖励 / 团团商店 / 背包 / 数据管理），并把原型的**设计令牌原样搬成 Dart**（珊瑚红主色、5 档圆角、8 档字号、浅/深两套语义色），视觉语言与 HTML 原型一致。其中「数据管理」是工程阶段新增的一屏（原型只画了导入导出的入口概念，没有独立界面）。

尚未迁移的屏：AI 对话记账。

---

## 下一步建议（按优先级）

1. ~~**统计页**~~ ✅ 已完成（分类环形图 + 排行 + 近 7 日柱状图）。
2. ~~**资产 / 预算页**~~ ✅ 已完成（余额派生 + 账户增删改；总预算 + 分类预算 + 超支提醒）。
3. ~~**养成闭环补全**~~ ✅ 已完成（签到 7 日周期 + 商店金币出口 + 背包使用/装备）。
4. ~~**装扮落到宠物身上**~~ ✅ 已完成（佩戴位分头饰 / 颈部 / 场景，宠物与背景都真实换装）。
5. ~~**数据层加固**~~ ✅ 已完成（账单 CSV 导出 / 导入：预览、去重、异常行标注、缺分类账户自动建档）。
6. ~~**宠物形象成长**~~ ✅ 已完成（体型随等级变化 + 呼吸/眨眼/摆尾待机动作 + 饿/低落表情，等级有了存在感）。
7. **移除演示种子数据**：`database.dart` 里 `_seedSample` 置 `false` 即可（商品目录不受影响，会照常播），正式发版必须关掉。
8. ~~**账单日历页**~~ ✅ 已完成（按月网格 + 每日收支 + 点选看当天明细，月份与统计页共享）。
9. **第三方账单适配**：目前认的是通用表头别名；支付宝 / 微信账单有各自的怪格式（独立收支列、备注列混商品名），可以加一层「来源适配器」。
10. **AI 对话记账**：原型最后一屏，需要接云端语义解析（ASR + LLM 结构化），属独立里程碑。
11. ~~**宠物状态化动作**~~ ✅ 已完成（饿了揉肚子 + 咕噜、深夜闭眼打哈欠 + Zzz、吃饱眯眼哼歌 + 音符；判定收在 `PetRules.actionFor` 纯函数，演出用低频独立控制器，静态预览按状态定格）。

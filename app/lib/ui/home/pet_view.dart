import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/rules/decor_rules.dart';
import '../../domain/rules/pet_rules.dart';

/// 宠物形象绘制器（纯代码绘制，不依赖图片资源）。
///
/// 造型：圆润三角耳的猫科小兽，ω 形嘴，双高光眼，开放式钩尾。
///
/// 三个变量注入让它是「活」的：
/// - [level] 决定体型（越大只越匀称，锚点在脚底，长大不会浮空）；
/// - [hunger] 与 [mood] 一起决定表情（饿坏了会蔫）；
/// - [blink] / [sway] 是待机动作相位，由 [BreathingPet] 逐帧喂进来。
class PetView extends StatelessWidget {
  const PetView({
    super.key,
    required this.size,
    this.bodyColor = const Color(0xFFFFF6E9),
    this.accentColor = const Color(0xFFF3C9A0),
    this.inkColor = const Color(0xFF3A2E26),
    this.blushColor = const Color(0xFFFFB3A0),
    this.mood = 70,
    this.hunger = 70,
    this.level = 1,
    this.blink = 0,
    this.sway = 0,
    this.action = PetAction.idle,
    this.actionPhase = 0,
    this.head,
    this.neck,
  });

  final double size;
  final Color bodyColor;
  final Color accentColor;
  final Color inkColor;
  final Color blushColor;

  /// 心情值 0-100，影响嘴形与眼睛弯度。
  final int mood;

  /// 饱食度 0-100，太低时表情会蔫。
  final int hunger;

  /// 等级，决定体型。
  final int level;

  /// 眨眼相位 0（睁眼）~ 1（闭眼）。
  final double blink;

  /// 摆尾相位 -1 ~ 1。
  final double sway;

  /// 状态化动作（饿 / 困 / 满足 / 待机）。
  final PetAction action;

  /// 动作演出相位 0 ~ 1，由 [BreathingPet] 逐帧喂进来。
  final double actionPhase;

  /// 头顶饰品（蝴蝶结 / 王冠）。
  final PetAccessory? head;

  /// 颈部饰品（铃铛）。
  final PetAccessory? neck;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PetPainter(
          body: bodyColor,
          accent: accentColor,
          ink: inkColor,
          blush: blushColor,
          mood: mood,
          hunger: hunger,
          level: level,
          blink: blink,
          sway: sway,
          action: action,
          actionPhase: actionPhase,
          head: head,
          neck: neck,
        ),
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  _PetPainter({
    required this.body,
    required this.accent,
    required this.ink,
    required this.blush,
    required this.mood,
    required this.hunger,
    required this.level,
    required this.blink,
    required this.sway,
    required this.action,
    required this.actionPhase,
    required this.head,
    required this.neck,
  });

  final Color body;
  final Color accent;
  final Color ink;
  final Color blush;
  final int mood;
  final int hunger;
  final int level;
  final double blink;
  final double sway;
  final PetAction action;
  final double actionPhase;
  final PetAccessory? head;
  final PetAccessory? neck;

  /// 金色饰品共用色（王冠 / 铃铛）。
  static const Color _gold = Color(0xFFF0A11A);
  static const Color _goldDark = Color(0xFFC97E08);
  static const Color _ribbon = Color(0xFFE2584A);
  static const Color _ribbonDark = Color(0xFFB4352A);

  @override
  void paint(Canvas canvas, Size size) {
    // 统一按 100×100 设计，再等比缩放到目标尺寸。
    final s = size.width / 100.0;
    final shape = PetRules.bodyFor(level);
    final happy = PetRules.isHappy(mood: mood, hunger: hunger);
    final down = PetRules.isDown(mood: mood, hunger: hunger);

    // 动作演出包络：相位前 40% 做一次 0→1→0 的「触发式」起伏，
    // 其余时间回到普通待机。env == 0 时保留基础形态（静态预览也能看出状态）。
    final env = _env(actionPhase);

    canvas.save();
    // 以脚底为锚点缩放：宠物「长大」是往上长，不会浮起来。
    canvas.translate(size.width * 0.5, size.height * 0.92);
    canvas.scale(s * shape.overall);
    canvas.translate(-50.0, -92.0);

    // ---- 地面投影
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 90), width: 54, height: 10),
      Paint()..color = ink.withValues(alpha: 0.10),
    );

    // ---- 尾巴（开放式钩形，随 [sway] 摆动）
    final swing = sway * 7;
    final tail = Path()
      ..moveTo(74, 70)
      ..cubicTo(92 + swing * 0.6, 66 - swing * 0.3, 94 + swing * 0.4,
          46 + swing * 0.2, 82 + swing, 42 - swing * 0.5);
    canvas.drawPath(
      tail,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // ---- 身体
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 70),
        width: 52 * shape.body,
        height: 40 * shape.body,
      ),
      Paint()..color = body,
    );
    // 腹部高光
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 74),
        width: 26 * shape.body,
        height: 22 * shape.body,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // ---- 前爪
    for (final dx in [-11.0, 11.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(50 + dx, 86), width: 15, height: 10),
        Paint()..color = body,
      );
    }
    // 爪趾缝
    for (final dx in [-11.0, 11.0]) {
      canvas.drawLine(
        Offset(50 + dx, 82),
        Offset(50 + dx, 86),
        Paint()
          ..color = accent
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ---- 耳朵
    for (final flip in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(50 + flip * 15, 34)
        ..quadraticBezierTo(
            50 + flip * 24, 12, 50 + flip * 27, 32)
        ..quadraticBezierTo(50 + flip * 22, 40, 50 + flip * 15, 34)
        ..close();
      canvas.drawPath(ear, Paint()..color = body);
      final inner = Path()
        ..moveTo(50 + flip * 17, 33)
        ..quadraticBezierTo(50 + flip * 23, 19, 50 + flip * 24, 32)
        ..close();
      canvas.drawPath(inner, Paint()..color = blush.withValues(alpha: 0.85));
    }

    // ---- 头
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 43),
        width: 48 * shape.head,
        height: 42 * shape.head,
      ),
      Paint()..color = body,
    );

    // ---- 呆毛
    final hair = Path()
      ..moveTo(50, 22)
      ..quadraticBezierTo(54, 12, 46, 10);
    canvas.drawPath(
      hair,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // ---- 眼睛
    // blink 优先：闭上的时候就是一条线，不再区分情绪。
    // 犯困时强制闭眼（打哈欠）。
    final close =
        action == PetAction.sleepy ? 1.0 : blink.clamp(0.0, 1.0);
    for (final flip in [-1.0, 1.0]) {
      final cx = 50 + flip * 10.0;

      if (close >= 0.5) {
        canvas.drawLine(
          Offset(cx - 4.2, 45),
          Offset(cx + 4.2, 45),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      if (happy) {
        // 开心：弯月眼；半闭时把弧压平
        final arc = Path()
          ..moveTo(cx - 5, 45)
          ..quadraticBezierTo(cx, 39 + close * 4, cx + 5, 45);
        canvas.drawPath(
          arc,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      // 蔫：眼睛半睁，看着没精神
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, 45),
          width: 7,
          height: 8 * (1 - close * 0.8) * (down ? 0.62 : 1.0),
        ),
        Paint()..color = ink,
      );
      if (!down) {
        canvas.drawCircle(
          Offset(cx + 1.6, 43.2),
          1.5,
          Paint()..color = Colors.white,
        );
      }
    }

    // ---- 腮红
    for (final flip in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 + flip * 17, 51), width: 10, height: 6),
        Paint()..color = blush.withValues(alpha: 0.55),
      );
    }

    // ---- 嘴
    if (action == PetAction.sleepy) {
      // 打哈欠：竖向椭圆张嘴，大小随包络起伏
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(50, 54), width: 6, height: 3 + 7 * env),
        Paint()..color = ink,
      );
    } else {
      // 正常是 ω 形，蔫的时候下弯
      final mouth = Path();
      if (down) {
        mouth
          ..moveTo(46, 55)
          ..quadraticBezierTo(50, 51, 54, 55);
      } else {
        mouth
          ..moveTo(46, 52)
          ..quadraticBezierTo(48, 56, 50, 52)
          ..quadraticBezierTo(52, 56, 54, 52);
      }
      canvas.drawPath(
        mouth,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ---- 胡须（蔫的时候往下垂）
    for (final flip in [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        final y = 49.0 + i * 4;
        canvas.drawLine(
          Offset(50 + flip * 22, y),
          Offset(50 + flip * 32, y - 2 + i * 3 + (down ? 3.0 : 0.0)),
          Paint()
            ..color = ink.withValues(alpha: 0.28)
            ..strokeWidth = 1,
        );
      }
    }

    // ---- 装扮（最后画，压在宠物之上）
    final n = neck;
    if (n != null) _drawNeck(canvas, n);
    final h = head;
    if (h != null) _drawHead(canvas, h);

    // ---- 状态化演出（触发式，压在最上层）
    switch (action) {
      case PetAction.idle:
        break;
      case PetAction.hungry:
        _drawHungry(canvas, env);
      case PetAction.sleepy:
        _drawSleepy(canvas, env);
      case PetAction.content:
        _drawContent(canvas, env);
    }

    canvas.restore();
  }

  /// 动作演出包络：相位前 40% 做一次 0→1→0 三角起伏。
  static double _env(double p) {
    if (p >= 0.4) return 0;
    final k = p / 0.4;
    return k < 0.5 ? k * 2 : (1 - k) * 2;
  }

  /// 饿：一只小爪搭在肚子上揉 + 肚子旁两条「咕噜」弧线。
  void _drawHungry(Canvas canvas, double env) {
    final pawAlpha = 0.55 + 0.35 * env;
    // 揉肚子的小爪（随包络上下）
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(62, 77 - env * 3), width: 10, height: 7),
      Paint()..color = body,
    );
    canvas.drawLine(
      Offset(58, 76 - env * 3),
      Offset(60, 74 - env * 3),
      Paint()
        ..color = accent
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );

    // 咕噜弧线
    final p = Paint()
      ..color = ink.withValues(alpha: pawAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = 77.0 + i * 5 - env * 2;
      final wave = Path()
        ..moveTo(30, y)
        ..quadraticBezierTo(32.5, y - 2.5, 35, y)
        ..quadraticBezierTo(37.5, y + 2.5, 40, y);
      canvas.drawPath(wave, p);
    }
  }

  /// 困：闭眼 + 张嘴已在上方处理，这里补头顶飘出的两个 Z。
  void _drawSleepy(Canvas canvas, double env) {
    for (var i = 0; i < 2; i++) {
      final a = ((env - i * 0.35) / 0.6).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final o = Offset(66 + i * 5, 22 - i * 8 - env * 3);
      final p = Paint()
        ..color = ink.withValues(alpha: 0.8 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final z = Path()
        ..moveTo(o.dx - 3, o.dy - 3)
        ..lineTo(o.dx + 3, o.dy - 3)
        ..lineTo(o.dx - 3, o.dy + 3)
        ..lineTo(o.dx + 3, o.dy + 3);
      canvas.drawPath(z, p);
    }
  }

  /// 满足：头顶飘一个八分音符（眼里的弯月已由 happy 分支处理）。
  void _drawContent(Canvas canvas, double env) {
    final a = (env / 0.5).clamp(0.0, 1.0);
    if (a <= 0) return;
    final o = Offset(35, 20 - env * 6);
    final inkP = ink.withValues(alpha: 0.85 * a);
    // 音符头
    canvas.drawOval(
      Rect.fromCenter(center: o, width: 4.4, height: 3.2),
      Paint()..color = inkP,
    );
    // 竖杆
    canvas.drawLine(
      o.translate(2, -6),
      o.translate(2, 1.5),
      Paint()
        ..color = inkP
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // 小旗
    final flag = Path()
      ..moveTo(o.dx + 2, o.dy - 6)
      ..quadraticBezierTo(o.dx + 6, o.dy - 4.5, o.dx + 5, o.dy - 1.5);
    canvas.drawPath(
      flag,
      Paint()
        ..color = inkP
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawNeck(Canvas canvas, PetAccessory a) {
    // 目前只有铃铛挂在脖子上；其它饰品误配到颈部时不画。
    if (a != PetAccessory.bell) return;

    canvas.drawArc(
      Rect.fromCenter(center: const Offset(50, 50), width: 34, height: 24),
      0.35,
      math.pi - 0.7,
      false,
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(50, 55.5),
      const Offset(50, 58.5),
      Paint()
        ..color = _goldDark
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(const Offset(50, 62), 4.8, Paint()..color = _gold);
    canvas.drawCircle(
      const Offset(50, 62),
      4.8,
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      const Offset(48.3, 60.3),
      1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawHead(Canvas canvas, PetAccessory a) {
    switch (a) {
      case PetAccessory.ribbon:
        _drawRibbon(canvas);
      case PetAccessory.crown:
        _drawCrown(canvas);
      case PetAccessory.bell:
        // 铃铛属于颈部，误配到头部时不画。
        break;
    }
  }

  /// 蝴蝶结：戴在右耳根上方，略微倾斜。
  void _drawRibbon(Canvas canvas) {
    canvas.save();
    canvas.translate(67, 27);
    canvas.rotate(-0.38);

    final wing = Paint()..color = _ribbon;
    final edge = Paint()
      ..color = _ribbonDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(-11, -6.5)
      ..lineTo(-11, 6.5)
      ..close();
    final right = Path()
      ..moveTo(0, 0)
      ..lineTo(11, -6.5)
      ..lineTo(11, 6.5)
      ..close();

    for (final p in [left, right]) {
      canvas.drawPath(p, wing);
      canvas.drawPath(p, edge);
    }
    canvas.drawCircle(const Offset(0, 0), 3.4, Paint()..color = _ribbonDark);
    canvas.drawCircle(
      const Offset(-1, -1),
      1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  /// 王冠：坐在头顶正中，三个尖 + 三颗宝石。
  void _drawCrown(Canvas canvas) {
    final crown = Path()
      ..moveTo(37, 22)
      ..lineTo(40, 10.5)
      ..lineTo(45.5, 17)
      ..lineTo(50, 7.5)
      ..lineTo(54.5, 17)
      ..lineTo(60, 10.5)
      ..lineTo(63, 22)
      ..close();

    canvas.drawPath(crown, Paint()..color = _gold);
    canvas.drawPath(
      crown,
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final gem = Paint()..color = _ribbon;
    canvas.drawCircle(const Offset(50, 18.5), 1.9, gem);
    canvas.drawCircle(const Offset(41.3, 19.6), 1.3, gem);
    canvas.drawCircle(const Offset(58.7, 19.6), 1.3, gem);
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) =>
      old.body != body ||
      old.accent != accent ||
      old.ink != ink ||
      old.blush != blush ||
      old.mood != mood ||
      old.hunger != hunger ||
      old.level != level ||
      old.blink != blink ||
      old.sway != sway ||
      old.action != action ||
      old.actionPhase != actionPhase ||
      old.head != head ||
      old.neck != neck;
}

/// 让宠物「活着」：呼吸起伏 + 尾巴摆动 + 定时眨眼。
///
/// 三个动作由**同一个控制器**派生相位，所以永远同步；
/// 用多个 AnimationController 各跑各的，迟早会对不齐。
class BreathingPet extends StatefulWidget {
  const BreathingPet({
    super.key,
    required this.size,
    this.mood = 70,
    this.hunger = 70,
    this.level = 1,
    this.enabled = true,
    this.action = PetAction.idle,
    this.head,
    this.neck,
  });

  final double size;
  final int mood;

  /// 饱食度，影响表情。
  final int hunger;

  /// 等级，影响体型。
  final int level;

  final bool enabled;

  /// 状态化动作（由调用方用 [PetRules.actionFor] 算好）。
  final PetAction action;

  /// 头顶饰品 / 颈部饰品（来自已装备的装扮）。
  final PetAccessory? head;
  final PetAccessory? neck;

  @override
  State<BreathingPet> createState() => _BreathingPetState();
}

class _BreathingPetState extends State<BreathingPet>
    with TickerProviderStateMixin {
  static const Duration _cycle = Duration(milliseconds: 3600);
  static const Duration _actionCycle = Duration(milliseconds: 9000);

  /// 只在需要动的时候才建控制器。
  ///
  /// 不能用 `late final x = AnimationController(...)`：`enabled == false` 时
  /// build 提前返回、从不访问它，于是它会在 **dispose 里**才被首次求值，
  /// 那时 widget 已经在卸载，创建 Ticker 会抛
  /// 「Looking up a deactivated widget's ancestor is unsafe」。
  ///
  /// 两个控制器职责不同：[_c] 高频呼吸/眨眼/摆尾（连续），[_a] 低频状态化
  /// 演出（触发式）。连续动作要同源、不能拆成多个 controller 各跑各的，
  /// 但「演出」是独立的事件式叠加，单独一个低频控制器才不会被呼吸节奏带乱。
  AnimationController? _c;
  AnimationController? _a;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(covariant BreathingPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _start();
      } else {
        _stop();
      }
      return;
    }
    if (oldWidget.action != widget.action) _syncAction();
  }

  void _start() {
    final c = _c ??= AnimationController(vsync: this, duration: _cycle);
    if (!c.isAnimating) c.repeat();
    _syncAction();
  }

  /// 非待机才需要低频演出控制器；回到待机就把它停掉省电。
  void _syncAction() {
    if (widget.action == PetAction.idle) {
      _a?.stop();
    } else {
      final a = _a ??= AnimationController(vsync: this, duration: _actionCycle);
      if (!a.isAnimating) a.repeat();
    }
  }

  void _stop() {
    _c?.stop();
    _a?.stop();
  }

  @override
  void dispose() {
    _c?.dispose();
    _a?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PetView pet({double blink = 0, double sway = 0, double phase = 0}) =>
        PetView(
          size: widget.size,
          mood: widget.mood,
          hunger: widget.hunger,
          level: widget.level,
          blink: blink,
          sway: sway,
          action: widget.action,
          actionPhase: phase,
          head: widget.head,
          neck: widget.neck,
        );

    final c = _c;
    if (!widget.enabled || c == null) return pet();

    final a = _a;
    final animation = a == null ? c : Listenable.merge([c, a]);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = c.value;
        final phase = a?.value ?? 0;

        // 呼吸：一个周期一次完整起伏
        final breath =
            Curves.easeInOut.transform((1 - math.cos(2 * math.pi * t)) / 2);

        // 眨眼：周期末尾 8% 眨一次（闭→开的三角脉冲）
        double blink = 0;
        if (t >= 0.92) {
          final k = (t - 0.92) / 0.08;
          blink = k < 0.5 ? k * 2 : (1 - k) * 2;
        }

        // 摆尾：一个周期来回两次
        final sway = math.sin(4 * math.pi * t);

        return Transform.translate(
          offset: Offset(0, -3.5 * breath),
          child: Transform.rotate(
            angle: (breath - 0.5) * 0.035,
            child: pet(blink: blink, sway: sway, phase: phase),
          ),
        );
      },
    );
  }
}

/// 场景背景：天空渐变 + 远山 + 云 + 草甸，可叠加装扮换来的场景皮肤。
class SceneBackground extends StatelessWidget {
  const SceneBackground({
    super.key,
    required this.colors,
    this.skin = SceneSkin.meadow,
  });

  final SceneColors colors;
  final SceneSkin skin;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScenePainter(colors, skin),
      size: Size.infinite,
    );
  }
}

class SceneColors {
  const SceneColors({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.hill,
    required this.hillDark,
    required this.grass,
  });

  final Color top;
  final Color mid;
  final Color bottom;
  final Color hill;
  final Color hillDark;
  final Color grass;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.c, this.skin);

  final SceneColors c;
  final SceneSkin skin;

  /// 夜色罩 / 樱花雾 / 月色。
  static const Color _nightVeil = Color(0xFF15224A);
  static const Color _sakuraVeil = Color(0xFFFFD8E6);
  static const Color _moon = Color(0xFFFFF4D6);
  static const Color _petal = Color(0xFFFF9BC0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final night = skin == SceneSkin.night;

    // 天空
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.mid, c.bottom],
          stops: const [0.0, 0.44, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 日光晕（夜景改用月亮，这里不画）
    if (!night) {
      canvas.drawCircle(
        Offset(w * 0.78, h * 0.18),
        h * 0.16,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(w * 0.78, h * 0.18),
            radius: h * 0.16,
          )),
      );
    }

    // 云
    final cloudAlpha = night ? 0.20 : 0.72;
    _cloud(canvas, Offset(w * 0.22, h * 0.16), w * 0.10, cloudAlpha);
    _cloud(canvas, Offset(w * 0.62, h * 0.09), w * 0.07, cloudAlpha);
    _cloud(canvas, Offset(w * 0.86, h * 0.26), w * 0.06, cloudAlpha);

    // 远山
    final far = Path()..moveTo(0, h * 0.62);
    for (var i = 0; i <= 6; i++) {
      final x = w * i / 6;
      final y = h * (0.62 - 0.09 * math.sin(i * 1.1));
      far.lineTo(x, y);
    }
    far
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = c.hill.withValues(alpha: 0.75));

    // 中景丘陵
    final near = Path()..moveTo(0, h * 0.72);
    for (var i = 0; i <= 5; i++) {
      final x = w * i / 5;
      final y = h * (0.72 - 0.06 * math.cos(i * 1.4));
      near.quadraticBezierTo(x, y, w * (i + 1) / 5, h * 0.73);
    }
    near
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = c.hillDark);

    // 草甸
    final grass = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.5, h * 0.75, w, h * 0.81)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(grass, Paint()..color = c.grass);

    // 前景光带（夜景下换成淡淡的月光）
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.93), width: w * 0.9, height: h * 0.12),
      Paint()..color = Colors.white.withValues(alpha: night ? 0.08 : 0.16),
    );

    // 场景皮肤：整层氛围，压在所有地形之上
    switch (skin) {
      case SceneSkin.meadow:
        break;
      case SceneSkin.night:
        _nightOverlay(canvas, w, h);
      case SceneSkin.sakura:
        _sakuraOverlay(canvas, w, h);
    }
  }

  /// 夜空：整体压暗 + 月亮 + 星星。
  void _nightOverlay(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _nightVeil.withValues(alpha: 0.62),
    );

    final moonC = Offset(w * 0.78, h * 0.18);
    canvas.drawCircle(
      moonC,
      h * 0.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _moon.withValues(alpha: 0.40),
            _moon.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: moonC, radius: h * 0.15)),
    );
    canvas.drawCircle(
      moonC,
      h * 0.062,
      Paint()..color = _moon.withValues(alpha: 0.95),
    );
    // 缺角：用夜色圆盖出一弯月牙
    canvas.drawCircle(
      moonC.translate(h * 0.024, -h * 0.014),
      h * 0.052,
      Paint()..color = _nightVeil.withValues(alpha: 0.55),
    );

    final star = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(w * _rnd(i, 1), h * (0.04 + 0.5 * _rnd(i, 2))),
        0.6 + 1.0 * _rnd(i, 3),
        star,
      );
    }
  }

  /// 樱花庭院：粉雾罩住天空 + 飘落花瓣。
  void _sakuraOverlay(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h * 0.86);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _sakuraVeil.withValues(alpha: 0.52),
            _sakuraVeil.withValues(alpha: 0.10),
          ],
        ).createShader(rect),
    );

    final petal = Paint()..color = _petal.withValues(alpha: 0.85);
    for (var i = 0; i < 18; i++) {
      final r = 2.2 + 1.5 * _rnd(i, 13);
      canvas.save();
      canvas.translate(w * _rnd(i, 11), h * (0.06 + 0.86 * _rnd(i, 12)));
      canvas.rotate(_rnd(i, 14) * math.pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.2),
        petal,
      );
      canvas.restore();
    }
  }

  /// 确定性伪随机：同一 index 永远得到同一个值，场景重绘不会闪。
  static double _rnd(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  void _cloud(Canvas canvas, Offset center, double r, double alpha) {
    final p = Paint()..color = Colors.white.withValues(alpha: alpha);
    canvas.drawCircle(center, r, p);
    canvas.drawCircle(center.translate(r * 0.9, r * 0.15), r * 0.72, p);
    canvas.drawCircle(center.translate(-r * 0.85, r * 0.2), r * 0.6, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center.translate(0, r * 0.5), width: r * 3.2, height: r),
        Radius.circular(r * 0.5),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.c != c || old.skin != skin;
}

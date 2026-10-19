import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scenes.dart';

/// 静态背景 + 调色 + 时间光线。场景切换时由外层 AnimatedSwitcher 做交叉淡入。
class SceneBackdrop extends StatelessWidget {
  final SceneStyle scene;
  final DayPhase phase;
  final bool followTime;

  const SceneBackdrop({
    super.key,
    required this.scene,
    required this.phase,
    required this.followTime,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      scene.asset,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );
    final graded = scene.gradeOpacity <= 0
        ? image
        : ColorFiltered(
            colorFilter: ColorFilter.mode(
              scene.grade.withValues(alpha: scene.gradeOpacity),
              scene.gradeBlend,
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                scene.grade.withValues(alpha: 0.22),
                BlendMode.softLight,
              ),
              child: image,
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: graded),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scene.topGlow,
                  Colors.transparent,
                  scene.bottomGlow,
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),
        if (followTime && phase.opacity > 0)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    phase.tint.withValues(alpha: phase.opacity * 1.25),
                    phase.tint.withValues(alpha: phase.opacity * 0.35),
                    phase.tint.withValues(alpha: phase.opacity * 0.75),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 氛围粒子：雪、樱花、雨、萤火、天灯、星星、极光、余烬、蒸汽、落叶、气泡。
///
/// 全部由同一个 60fps 主时钟驱动，和人物动画共用一个时间源；低配模式
/// 自动减半粒子数量。
class SceneAtmosphere extends StatelessWidget {
  final SceneStyle scene;
  final double clock;
  final bool lowQuality;

  const SceneAtmosphere({
    super.key,
    required this.scene,
    required this.clock,
    required this.lowQuality,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AtmospherePainter(
          scene: scene,
          clock: clock,
          lowQuality: lowQuality,
        ),
      ),
    );
  }
}

double _frac(double v) => v - v.floorToDouble();

class _AtmospherePainter extends CustomPainter {
  final SceneStyle scene;
  final double clock;
  final bool lowQuality;

  _AtmospherePainter({
    required this.scene,
    required this.clock,
    required this.lowQuality,
  });

  int _count(int n) => lowQuality ? (n / 2).ceil() : n;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.aurora) _paintAurora(canvas, size);
    for (final p in scene.particles) {
      switch (p) {
        case SceneParticle.star:
          _paintStars(canvas, size);
        case SceneParticle.snow:
          _paintSnow(canvas, size);
        case SceneParticle.petal:
          _paintPetals(canvas, size);
        case SceneParticle.rain:
          _paintRain(canvas, size);
        case SceneParticle.firefly:
          _paintFireflies(canvas, size);
        case SceneParticle.lantern:
          _paintLanterns(canvas, size);
        case SceneParticle.sparkle:
          _paintSparkles(canvas, size);
        case SceneParticle.ember:
          _paintEmbers(canvas, size);
        case SceneParticle.steam:
          _paintSteam(canvas, size);
        case SceneParticle.leaf:
          _paintLeaves(canvas, size);
        case SceneParticle.bubble:
          _paintBubbles(canvas, size);
        case SceneParticle.bat:
          _paintBats(canvas, size);
      }
    }
  }

  void _paintAurora(Canvas canvas, Size size) {
    final ribbons = lowQuality ? 2 : 3;
    for (var layer = 0; layer < ribbons; layer++) {
      final topBase = size.height * (0.12 + layer * 0.055);
      final bottomBase = topBase + size.height * (0.16 + layer * 0.035);
      final path = Path();
      const steps = 18;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y = topBase +
            math.sin(clock * math.pi * 1.6 + i * 0.55 + layer * 1.9) *
                size.height *
                (0.035 + layer * 0.012) +
            math.sin(clock * math.pi * 3.1 + i * 1.13) * size.height * 0.014;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      for (var i = steps; i >= 0; i--) {
        final x = size.width * i / steps;
        final y = bottomBase +
            math.sin(clock * math.pi * 1.2 - i * 0.42 + layer * 2.4) *
                size.height *
                (0.05 + layer * 0.012);
        path.lineTo(x, y);
      }
      path.close();
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF7CFFD8).withValues(alpha: 0.2 - layer * 0.04),
          const Color(0xFF8FA8FF).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(
          0, topBase - 30, size.width, bottomBase - topBase + 60));
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, lowQuality ? 8 : 14),
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final n = _count(46);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.6180339887);
      final seed2 = _frac(i * 0.7548776662 + 0.31);
      final x = size.width * seed;
      final y = size.height * seed2 * 0.48;
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(clock * math.pi * 2 * 2 + i));
      final r = 0.7 + seed2 * 1.3;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.55 * twinkle),
      );
    }
    final shoot = _frac(clock * 0.55);
    if (shoot < 0.16) {
      final p = shoot / 0.16;
      final start = Offset(size.width * 0.78 - p * size.width * 0.3,
          size.height * 0.12 + p * size.height * 0.08);
      final tail =
          Offset(start.dx + size.width * 0.09, start.dy - size.height * 0.035);
      canvas.drawLine(
        start,
        tail,
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - p) * 0.7)
          ..strokeWidth = 1.4,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final n = _count(60);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.6180339887 + 0.11);
      final speed = 0.022 + seed * 0.04;
      final y = _frac(seed * 2.3 + clock * speed * 6) * size.height;
      final x =
          _frac(seed + math.sin(clock * 1.7 + i * 2.1) * 0.045) * size.width;
      final r = 0.8 + seed * 1.7 + (i % 9 == 0 ? 1.1 : 0);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color =
              const Color(0xFFEAF6FF).withValues(alpha: 0.48 + seed * 0.38),
      );
    }
  }

  void _paintPetals(Canvas canvas, Size size) {
    final n = _count(40);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.583 + 0.07);
      final y =
          _frac(seed * 1.9 + clock * (0.018 + seed * 0.03) * 6) * size.height;
      final x = _frac(seed + math.sin(clock * 1.5 + i) * 0.03) * size.width;
      final w = 6.0 + seed * 9;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(clock * math.pi * 2 * (0.4 + seed) + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.52),
        Paint()
          ..color = Color.lerp(
                  const Color(0xFFFFC9DE), const Color(0xFFFF6FA5), seed)!
              .withValues(alpha: 0.72 + seed * 0.22),
      );
      canvas.restore();
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final n = _count(68);
    final paint = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.731 + 0.13);
      final speed = 0.22 + seed * 0.18;
      final y = _frac(seed * 2.1 + clock * speed) * size.height * 1.1;
      final x = _frac(seed + y / size.height * 0.06) * size.width;
      final len = 10 + seed * 22;
      paint.color =
          const Color(0xFFBFE7F5).withValues(alpha: 0.24 + seed * 0.22);
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + len), paint);
    }
  }

  void _paintFireflies(Canvas canvas, Size size) {
    final n = _count(18);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.617 + 0.23);
      final x =
          _frac(seed + math.sin(clock * 0.9 + i * 2.3) * 0.035) * size.width;
      final y =
          _frac(seed * 1.7 + 0.18 + math.cos(clock * 0.7 + i * 1.7) * 0.03) *
              size.height *
              0.72;
      final blink = (0.5 + 0.5 * math.sin(clock * math.pi * 2 * 1.4 + i * 2.1))
          .clamp(0.0, 1.0);
      if (blink < 0.18) continue;
      const c = Color(0xFFFFE08A);
      canvas.drawCircle(Offset(x, y), 4.2,
          Paint()..color = c.withValues(alpha: 0.08 * blink));
      canvas.drawCircle(Offset(x, y), 1.5,
          Paint()..color = c.withValues(alpha: 0.75 * blink));
    }
  }

  void _paintLanterns(Canvas canvas, Size size) {
    final n = _count(12);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.533 + 0.17);
      final y = size.height * (0.9 - _frac(seed + clock * 0.012) * 0.78);
      final x = size.width * (seed + math.sin(clock * 0.5 + i) * 0.02);
      final w = 7.0 + seed * 7;
      final h = w * 1.35;
      canvas.drawCircle(
        Offset(x, y),
        w * 1.9,
        Paint()..color = const Color(0xFFFFB45E).withValues(alpha: 0.07),
      );
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        Radius.circular(w * 0.35),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Color.lerp(
                  const Color(0xFFFFD08A), const Color(0xFFFF7E4D), seed)!
              .withValues(alpha: 0.75),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, y + h * 0.62), width: w * 0.18, height: h * 0.16),
        Paint()..color = const Color(0xFFFFE2A8).withValues(alpha: 0.8),
      );
    }
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final n = _count(20);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.571 + 0.09);
      final x = size.width * seed;
      final y = size.height * _frac(seed * 1.3 + 0.1) * 0.7;
      final twinkle = 0.5 + 0.5 * math.sin(clock * math.pi * 2 * 1.7 + i * 1.3);
      final r = (2.5 + seed * 4) * (0.7 + twinkle * 0.5);
      final paint = Paint()
        ..color =
            const Color(0xFFFFD98A).withValues(alpha: 0.25 + twinkle * 0.5);
      final path = Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x + r * 0.18, y - r * 0.18, x + r, y)
        ..quadraticBezierTo(x + r * 0.18, y + r * 0.18, x, y + r)
        ..quadraticBezierTo(x - r * 0.18, y + r * 0.18, x - r, y)
        ..quadraticBezierTo(x - r * 0.18, y - r * 0.18, x, y - r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintEmbers(Canvas canvas, Size size) {
    final n = _count(24);
    final cx = size.width * scene.fireX;
    final cy = size.height * scene.fireY;
    final rand = math.Random(42);
    for (var i = 0; i < n; i++) {
      final seed = rand.nextDouble();
      final phase = _frac(clock * (0.6 + seed * 0.8) + seed);
      final x = cx +
          (seed - 0.5) * size.width * 0.22 +
          math.sin(phase * 6 + seed * 10) * 8;
      final y = cy - phase * size.height * 0.36;
      final a = (1 - phase) * (0.3 + seed * 0.5);
      final r = 0.8 + seed * 1.6;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xFFFFB45E).withValues(alpha: a),
      );
    }
  }

  void _paintSteam(Canvas canvas, Size size) {
    final n = _count(16);
    final cx = size.width * scene.fireX;
    final baseY = size.height * (scene.fireY + 0.06);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.467 + 0.21);
      final phase = _frac(clock * (0.9 + seed * 1.1) + seed);
      final x = cx + (seed - 0.5) * size.width * 0.9 +
          math.sin(phase * 7 + i * 1.7) * size.width * 0.03;
      final y = baseY - phase * size.height * 0.34;
      final r = (10 + seed * 26) * (0.5 + phase * 1.4);
      final a = (1 - phase) * (0.20 + seed * 0.18);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFFF2FBFF).withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
    }
  }

  void _paintLeaves(Canvas canvas, Size size) {
    final n = _count(30);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.329 + 0.19);
      final y =
          _frac(seed * 2.2 + clock * (0.026 + seed * 0.03) * 6) * size.height;
      final x =
          _frac(seed + math.sin(clock * 1.3 + i * 1.9) * 0.07) * size.width;
      final w = 7.0 + seed * 8;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(clock * math.pi * 1.4 + i * 2.3) * 0.9 + i);
      final path = Path()
        ..moveTo(-w * 0.5, 0)
        ..quadraticBezierTo(0, -w * 0.42, w * 0.5, 0)
        ..quadraticBezierTo(0, w * 0.42, -w * 0.5, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(const Color(0xFFFF9A4E),
                  const Color(0xFFD94A2E), seed)!
              .withValues(alpha: 0.62 + seed * 0.28),
      );
      canvas.restore();
    }
  }

  void _paintBubbles(Canvas canvas, Size size) {
    final n = _count(16);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.673 + 0.37);
      final phase = _frac(clock * (1.1 + seed * 1.4) + seed);
      final y = size.height * (0.92 - phase * 0.5);
      final x = size.width * seed +
          math.sin(phase * 9 + i * 2.1) * size.width * 0.02;
      final r = 2.2 + seed * 5.5;
      final a = (1 - phase) * (0.18 + seed * 0.22);
      stroke.color = const Color(0xFFCDEAFF).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, stroke);
      canvas.drawCircle(
        Offset(x - r * 0.35, y - r * 0.35),
        r * 0.18,
        Paint()..color = Colors.white.withValues(alpha: a * 1.6),
      );
    }
  }

  void _paintBats(Canvas canvas, Size size) {
    final n = _count(7);
    final paint = Paint()..color = const Color(0xFF1A1224);
    for (var i = 0; i < n; i++) {
      final seed = _frac(i * 0.377 + 0.15);
      final x = _frac(seed + clock * (0.08 + seed * 0.1)) * size.width;
      final y = size.height * (0.1 + seed * 0.3) +
          math.sin(clock * math.pi * 6 + i * 2.4) * size.height * 0.02;
      final s = 7.0 + seed * 8;
      // 拍翅：翼尖高度随时间起伏
      final flap = math.sin(clock * math.pi * 2 * 5.5 + i * 1.8);
      final path = Path()
        ..moveTo(x - s, y - s * 0.35 * flap)
        ..quadraticBezierTo(x - s * 0.45, y - s * 0.5, x - s * 0.18, y)
        ..quadraticBezierTo(x, y - s * 0.22, x + s * 0.18, y)
        ..quadraticBezierTo(x + s * 0.45, y - s * 0.5, x + s, y - s * 0.35 * flap)
        ..quadraticBezierTo(x + s * 0.5, y + s * 0.28, x, y + s * 0.16)
        ..quadraticBezierTo(x - s * 0.5, y + s * 0.28, x - s, y - s * 0.35 * flap)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.clock != clock ||
      old.scene.id != scene.id ||
      old.lowQuality != lowQuality;
}

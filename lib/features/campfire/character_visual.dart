import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../chat/widgets.dart';

enum ReactionType { pat, poke, surprise, hug, tail, angry, yawn, sing, note }

class Reaction {
  final ReactionType type;
  final DateTime at;

  const Reaction(this.type, this.at);

  double progress([DateTime? now]) {
    final ms = (now ?? DateTime.now()).difference(at).inMilliseconds;
    return (ms / 850).clamp(0.0, 1.0);
  }

  bool get active => progress() < 1.0;
}

/// 场景里的一个角色。当前是“单张立绘 + 程序化动作 + 表情 overlay”；
/// 之后接 Rive / Live2D 时，只需要替换 [_SpriteLayer]，对外仍然暴露
/// Mood / Motion / Reaction 这几个输入。
class CharacterVisual extends StatelessWidget {
  final Character character;
  final ui.Image? image;
  final double width;
  final double height;
  final double phase;
  final double clock; // 0..1 主时钟
  final EmotionState emotion;
  final Reaction? reaction;
  final bool speaking;
  final bool talking;
  final bool concert;
  final String motionQuality;
  final ValueChanged<PokeZone> onPoke;
  final VoidCallback onSurprise;
  final VoidCallback onHug;

  const CharacterVisual({
    super.key,
    required this.character,
    required this.image,
    required this.width,
    required this.height,
    required this.phase,
    required this.clock,
    required this.emotion,
    required this.reaction,
    required this.speaking,
    required this.talking,
    required this.concert,
    required this.motionQuality,
    required this.onPoke,
    required this.onSurprise,
    required this.onHug,
  });

  @override
  Widget build(BuildContext context) {
    final quality = motionQuality;
    final idleAmp = quality == 'low' ? 2.0 : (quality == 'high' ? 5.0 : 3.5);
    final t = (clock * 3.2 + phase) % 1.0;
    final s = sin(2 * pi * t);
    final breath = sin(2 * pi * (clock * 1.35 + phase));
    final bobAmp =
        speaking ? idleAmp * 1.8 : (concert ? idleAmp * 2.2 : idleAmp);
    final tiltAmp = speaking ? 0.035 : (concert ? 0.055 : 0.014);

    var dx = 0.0;
    var dy = s * bobAmp;
    var rot = s * tiltAmp;
    var scaleX = 1.0 + breath * 0.006;
    var scaleY = 1.0 + breath * 0.008;
    if (talking) {
      scaleX += 0.004 * sin(2 * pi * clock * 10);
      scaleY += 0.004 * sin(2 * pi * clock * 10);
    }

    final r = reaction;
    if (r != null && r.active) {
      final p = r.progress();
      final wave = sin(pi * p);
      switch (r.type) {
        case ReactionType.pat:
          scaleY -= 0.05 * wave;
          scaleX += 0.025 * wave;
          dy -= 4 * wave;
          break;
        case ReactionType.poke:
          dx += 7 * sin(10 * pi * p) * (1 - p);
          break;
        case ReactionType.surprise:
          dy -= 20 * wave;
          scaleX += 0.06 * wave;
          scaleY += 0.06 * wave;
          rot += 0.02 * sin(12 * pi * p) * (1 - p);
          break;
        case ReactionType.hug:
          dy -= 7 * wave;
          scaleX += 0.03 * wave;
          scaleY += 0.03 * wave;
          break;
        case ReactionType.tail:
          rot += 0.05 * sin(6 * pi * p) * (1 - p);
          dx += 4 * sin(6 * pi * p) * (1 - p);
          break;
        case ReactionType.angry:
          dx += 4 * sin(16 * pi * p) * (1 - p);
          rot += 0.012 * sin(16 * pi * p) * (1 - p);
          break;
        case ReactionType.yawn:
          scaleY -= 0.02 * wave;
          rot -= 0.02 * wave;
          break;
        case ReactionType.sing:
          dy -= 9 * sin(2 * pi * p).abs() * (1 - p);
          rot += 0.02 * sin(4 * pi * p);
          break;
        case ReactionType.note:
          dy -= 3 * wave;
          break;
      }
    }

    return Semantics(
      label: '${character.name}，点一下可以互动',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final local = details.localPosition;
          final zone = _zoneAt(local);
          onPoke(zone);
        },
        onDoubleTap: onSurprise,
        onLongPress: onHug,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rot,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: _sprite()),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: EmotePainter(
                            mood: emotion.isNeutral ? null : emotion.mood,
                            reaction: r,
                            clock: clock,
                          ),
                        ),
                      ),
                      // 正在说话的提示交给底部字幕卡/名字胶囊，避免头顶多一个小气泡
                      // 跟别人重叠。
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PokeZone _zoneAt(Offset p) {
    final y = p.dy / height;
    final x = p.dx / width;
    final hasTail = const {'dafeiyu', 'gemini', 'gpt'}.contains(character.id);
    if (hasTail && x > 0.74 && y > 0.42) return PokeZone.tail;
    if (y < 0.3) return PokeZone.head;
    if (y < 0.52) return PokeZone.face;
    return PokeZone.body;
  }

  Widget _sprite() {
    if (image == null) {
      return Center(
        child: AvatarDot(character: character, size: height * 0.4),
      );
    }
    final raw = RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (motionQuality == 'low') return raw;
    return raw;
  }
}

/// 用 Canvas 画表情/动作 overlay：不依赖新美术，也能让立绘“有反应”。
class EmotePainter extends CustomPainter {
  final String? mood;
  final Reaction? reaction;
  final double clock;

  EmotePainter({this.mood, this.reaction, required this.clock});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    switch (mood) {
      case '害羞':
        paint.color = const Color(0xFFFF6F91).withValues(alpha: 0.42);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.36, h * 0.205),
              width: w * 0.11,
              height: h * 0.035),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.64, h * 0.205),
              width: w * 0.11,
              height: h * 0.035),
          paint,
        );
        _heart(canvas, Offset(w * 0.76, h * 0.13), w * 0.035,
            const Color(0xFFFF8FA8));
        break;
      case '生气':
        _anger(canvas, Offset(w * 0.72, h * 0.09), w * 0.035);
        break;
      case '困倦':
        _zzz(canvas, Offset(w * 0.74, h * 0.1), w, h);
        break;
      case '开心':
      case '兴奋':
        _sparkle(canvas, Offset(w * 0.28, h * 0.16), w * 0.03,
            const Color(0xFFFFD166));
        _sparkle(canvas, Offset(w * 0.75, h * 0.24), w * 0.024,
            const Color(0xFFFFD166));
        if (mood == '兴奋') {
          _sparkle(canvas, Offset(w * 0.7, h * 0.1), w * 0.018,
              const Color(0xFFFFF0B0));
        }
        break;
      case '得意':
        _note(canvas, Offset(w * 0.76, h * 0.12), w * 0.045);
        break;
      case '无语':
        _sweat(canvas, Offset(w * 0.7, h * 0.16), w * 0.022);
        break;
      case '难过':
        _tear(canvas, Offset(w * 0.41, h * 0.26), w * 0.018);
        _tear(canvas, Offset(w * 0.59, h * 0.26), w * 0.018);
        break;
    }

    final r = reaction;
    if (r != null && r.active) {
      final p = r.progress();
      final fade = 1 - p;
      switch (r.type) {
        case ReactionType.pat:
        case ReactionType.hug:
          for (var i = 0; i < 3; i++) {
            final yy = h * (0.08 + i * 0.04) - p * h * 0.12;
            _heart(
              canvas,
              Offset(w * (0.35 + i * 0.14), yy),
              w * (0.02 + 0.008 * i),
              const Color(0xFFFF8FA8).withValues(alpha: 0.7 * fade),
            );
          }
          break;
        case ReactionType.poke:
        case ReactionType.surprise:
          _bang(canvas, Offset(w * 0.78, h * 0.08), w * 0.05,
              r.type == ReactionType.surprise ? '!!' : '!');
          break;
        case ReactionType.tail:
          _note(canvas, Offset(w * 0.78, h * 0.42), w * 0.04);
          break;
        case ReactionType.angry:
          _anger(canvas, Offset(w * 0.72, h * 0.09), w * 0.045);
          break;
        case ReactionType.yawn:
          _zzz(canvas, Offset(w * 0.72, h * 0.1), w, h);
          break;
        case ReactionType.sing:
          _note(canvas, Offset(w * 0.72, h * 0.16), w * 0.05);
          _note(canvas, Offset(w * 0.84, h * 0.08), w * 0.035);
          break;
        case ReactionType.note:
          _note(canvas, Offset(w * 0.74, h * 0.14), w * 0.04);
          break;
      }
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.75)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.2, c.dx - r * 0.55, c.dy - r * 1.2,
          c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.55, c.dy - r * 1.2, c.dx + r * 1.6, c.dy - r * 0.2,
          c.dx, c.dy + r * 0.75)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _anger(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D5E)
      ..strokeWidth = r * 0.35
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
        Offset(c.dx + cos(a) * r, c.dy + sin(a) * r),
        Offset(c.dx + cos(a) * r * 1.7, c.dy + sin(a) * r * 1.7),
        paint,
      );
      canvas.drawLine(
        Offset(c.dx - cos(a) * r, c.dy - sin(a) * r),
        Offset(c.dx - cos(a) * r * 1.7, c.dy - sin(a) * r * 1.7),
        paint,
      );
    }
  }

  void _zzz(Canvas canvas, Offset c, double w, double h) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Z',
        style: TextStyle(
            color: Color(0xFFBFD7FF),
            fontSize: 14,
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final drift = sin(clock * 2 * pi) * 3;
    tp.paint(canvas, c);
    tp.paint(canvas, c + Offset(12 + drift, -14));
    tp.paint(canvas, c + Offset(22 + drift, -26));
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy - r * 0.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy + r * 0.2, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy + r * 0.2, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.2, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.8));
  }

  void _note(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.9, height: r * 0.65),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx + r * 0.32, c.dy - r * 1.6, r * 0.16, r * 1.6),
      paint,
    );
  }

  void _sweat(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r, c.dy + r * 0.5, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy + r * 0.5, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
        path, Paint()..color = const Color(0xFF8ECDF7).withValues(alpha: 0.8));
  }

  void _tear(Canvas canvas, Offset c, double r) {
    _sweat(canvas, c, r);
  }

  void _bang(Canvas canvas, Offset c, double r, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: const Color(0xFFFFD166),
            fontSize: r * 2,
            fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c);
  }

  @override
  bool shouldRepaint(EmotePainter old) =>
      old.mood != mood ||
      old.reaction?.type != reaction?.type ||
      old.reaction?.at != reaction?.at ||
      old.clock != clock;
}

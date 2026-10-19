import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/camp_state.dart';
import '../../core/scenes.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../chat/widgets.dart';
import 'character_visual.dart';
import 'scene_atmosphere.dart';

class StageSpot {
  final double x;
  final double y;
  final double scale;

  const StageSpot(this.x, this.y, this.scale);
}

const _officialSpots = <String, StageSpot>{
  'dafeiyu': StageSpot(0.135, 0.715, 1.0),
  'claude': StageSpot(0.315, 0.625, 0.97),
  'gpt': StageSpot(0.50, 0.55, 0.93),
  'gemini': StageSpot(0.685, 0.625, 0.97),
  'grok': StageSpot(0.865, 0.705, 1.0),
};

const _chibiSpots = <String, StageSpot>{
  'dafeiyu': StageSpot(0.155, 0.73, 0.93),
  'claude': StageSpot(0.325, 0.65, 0.9),
  'gpt': StageSpot(0.50, 0.605, 0.86),
  'gemini': StageSpot(0.675, 0.65, 0.9),
  'grok': StageSpot(0.845, 0.70, 0.93),
};

class _Placed {
  final Character character;
  final StageSpot spot;
  final double left;
  final double top;
  final double width;
  final double height;
  final double feetX;
  final double feetY;

  const _Placed({
    required this.character,
    required this.spot,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.feetX,
    required this.feetY,
  });

  double get headTop => top;
  double get centerX => left + width / 2;
}

class CampfireStage extends StatelessWidget {
  final Animation<double> clock;
  final Map<String, ui.Image> images;
  final ChatController chat;
  final CampState camp;
  final Map<String, Reaction> reactions;
  final Map<String, String> talking;
  final SceneStyle scene;
  final DayPhase phase;
  final bool followTime;
  final bool atmosphereEnabled;
  final void Function(Character, PokeZone) onPoke;
  final ValueChanged<Character> onDoubleTap;
  final ValueChanged<Character> onHug;
  final ValueChanged<Character> onNameplateTap;
  final ValueChanged<ChatMessage> onBubbleTap;

  const CampfireStage({
    super.key,
    required this.clock,
    required this.images,
    required this.chat,
    required this.camp,
    required this.reactions,
    required this.talking,
    required this.scene,
    required this.phase,
    required this.followTime,
    required this.atmosphereEnabled,
    required this.onPoke,
    required this.onDoubleTap,
    required this.onHug,
    required this.onNameplateTap,
    required this.onBubbleTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = chat.settings;
    final chibi = settings.spriteStyle == 'chibi';
    final spots = chibi ? _chibiSpots : _officialSpots;
    final characters = resolvedCharacters;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        // Q版头大、官方裙摆宽：分别给一套基准高，避免五个人挤成一团。
        final base = h * (chibi ? 0.19 : 0.21);
        final placed = <_Placed>[];
        for (final c in characters) {
          final spot = spots[c.id]!;
          final img = images[c.id];
          final aspect = img == null ? 0.58 : img.width / img.height;
          var spriteH = base * spot.scale;
          var spriteW = spriteH * aspect;
          final maxW = w * 0.30;
          if (spriteW > maxW) {
            spriteW = maxW;
            spriteH = spriteW / aspect;
          }
          final rawLeft = spot.x * w - spriteW / 2;
          final left = rawLeft.clamp(6.0, max(6.0, w - spriteW - 6)).toDouble();
          final feetY = spot.y * h;
          final top = max(0.0, feetY - spriteH);
          placed.add(_Placed(
            character: c,
            spot: spot,
            left: left,
            top: top,
            width: spriteW,
            height: spriteH,
            feetX: left + spriteW / 2,
            feetY: feetY,
          ));
        }
        final byDepth = [...placed]
          ..sort((a, b) => a.spot.y.compareTo(b.spot.y));
        final bubbles = _layoutBubbles(context, placed, w, h);
        final caption = _captionMessage();

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: SceneBackdrop(
                key: ValueKey<String>(scene.id),
                scene: scene,
                phase: phase,
                followTime: followTime,
              ),
            ),
            if (atmosphereEnabled)
              AnimatedBuilder(
                animation: clock,
                builder: (context, _) => SceneAtmosphere(
                  scene: scene,
                  clock: clock.value,
                  lowQuality: settings.motionQuality == 'low',
                ),
              ),
            if (chat.concert) const _ConcertLighting(),
            // 只有火光/人物/余烬随主时钟重建；背景、气泡、名字胶囊、
            // 字幕卡都是静态层，不再每帧重新布局和测量文字。
            AnimatedBuilder(
              animation: clock,
              builder: (context, _) {
                final t = clock.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (scene.fire) _fireGlow(w, h, t),
                    for (final p in byDepth) _shadow(p),
                    for (final p in byDepth) _character(p, w, t),
                  ],
                );
              },
            ),
            for (final b in bubbles) _bubbleWidget(b, w, h),
            for (final p in placed) _nameplate(context, p, w, h),
            if (caption != null) _captionCard(caption, w),
            _Vignette(
              tint: scene.id == 'campfire'
                  ? AppColors.bg
                  : Color.lerp(AppColors.bg, scene.topGlow, 0.55) ??
                      AppColors.bg,
            ),
          ],
        );
      },
    );
  }

  ChatMessage? _captionMessage() {
    final now = DateTime.now();
    for (var i = chat.messages.length - 1;
        i >= 0 && i >= chat.messages.length - 8;
        i--) {
      final m = chat.messages[i];
      if (m.isSystem || m.isUser || m.isSticker) continue;
      if (now.difference(m.time) > const Duration(seconds: 9)) break;
      if (m.text.trim().isEmpty) continue;
      if (m.isStreaming || m.text.length > 20) return m;
    }
    return null;
  }

  Widget _captionCard(ChatMessage m, double w) {
    final c = characterById(m.senderId);
    if (c == null) return const SizedBox.shrink();
    final accent = Color(c.accentColor);
    final emo = camp.emotionFor(c.id);
    return Positioned(
      left: 10,
      right: 10,
      bottom: 8,
      child: GestureDetector(
        onTap: () => onBubbleTap(m),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xEE121722),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(c.name,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                  if (!emo.isNeutral) ...[
                    const SizedBox(width: 5),
                    Text(emo.emoji, style: const TextStyle(fontSize: 10)),
                  ],
                  const Spacer(),
                  Text(m.isStreaming ? '正在说…' : '点击查看',
                      style:
                          const TextStyle(fontSize: 8.5, color: AppColors.dim)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${m.text}${m.isStreaming ? '▍' : ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.42, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _character(_Placed p, double w, double t) {
    final c = p.character;
    final emotion = camp.emotionFor(c.id);
    final speaking = chat.typingIds.contains(c.id);
    final talk = talking[c.id] != null;
    return Positioned(
      left: p.left,
      top: p.top,
      width: p.width,
      height: p.height,
      child: CharacterVisual(
        character: c,
        image: images[c.id],
        width: p.width,
        height: p.height,
        phase: max(0, kCharacters.indexWhere((x) => x.id == c.id)) * 0.19,
        clock: t,
        emotion: emotion,
        reaction: reactions[c.id],
        speaking: speaking,
        talking: talk,
        concert: chat.concert,
        motionQuality: chat.settings.motionQuality,
        onPoke: (zone) => onPoke(c, zone),
        onSurprise: () => onDoubleTap(c),
        onHug: () => onHug(c),
      ),
    );
  }

  Widget _shadow(_Placed p) {
    final shW = p.width * 1.12;
    final shH = p.height * 0.055;
    return Positioned(
      left: p.feetX - shW / 2,
      top: p.feetY - shH * 0.65,
      width: shW,
      height: shH,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(colors: [
              Colors.black.withValues(alpha: 0.42),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nameplate(BuildContext context, _Placed p, double w, double h) {
    final c = p.character;
    final emo = camp.emotionFor(c.id);
    final aff = camp.affinityFor(c.id);
    final accent = Color(c.accentColor);
    final speaking = chat.typingIds.contains(c.id);
    final tp = TextPainter(
      text: TextSpan(
        text: c.name,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final plateW = (tp.width + (emo.isNeutral ? 12 : 20) + 42)
        .clamp(70.0, 178.0)
        .toDouble();
    final left = (p.centerX - plateW / 2)
        .clamp(4.0, max(4.0, w - plateW - 4))
        .toDouble();
    return Positioned(
      left: left,
      width: plateW,
      top: (p.feetY + 7).clamp(0.0, h - 30).toDouble(),
      child: GestureDetector(
        onTap: () => onNameplateTap(c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 2, 7, 2),
          decoration: BoxDecoration(
            color: const Color(0xD90B0E14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: accent.withValues(alpha: speaking ? 0.65 : 0.3)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emo.isNeutral ? '·' : emo.emoji,
                  style: TextStyle(fontSize: 11, color: accent)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.favorite_rounded,
                  size: 7, color: accent.withValues(alpha: 0.62)),
              const SizedBox(width: 1),
              Text('${aff.value}',
                  style: TextStyle(
                      fontSize: 8.5, color: accent.withValues(alpha: 0.65))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fireGlow(double w, double h, double clock) {
    final t = (clock * 4.7272727) % 1.0;
    final tri = 1 - (t - 0.5).abs() * 2;
    final glow = Color.lerp(const Color(0xFFFF8A2B), scene.accent, 0.32)!;
    return Positioned(
      left: w * (scene.fireX - 0.26),
      top: h * (scene.fireY - 0.15),
      width: w * 0.52,
      height: h * 0.30,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              glow.withValues(alpha: 0.12 + 0.09 * tri),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- 气泡布局 ----------

  List<_Bubble> _layoutBubbles(
      BuildContext context, List<_Placed> placed, double w, double h) {
    final now = DateTime.now();
    const ttl = Duration(seconds: 9);
    final candidates = <_Bubble>[];

    for (final p in placed) {
      final c = p.character;
      final typing = chat.typingIds.contains(c.id);
      ChatMessage? last;
      for (var i = chat.messages.length - 1;
          i >= 0 && i >= chat.messages.length - 6;
          i--) {
        final m = chat.messages[i];
        if (m.senderId == c.id && !m.isSystem) {
          last = m;
          break;
        }
      }
      final recent = last != null && now.difference(last.time) <= ttl;
      if (!typing && !recent) continue;
      // 长台词/正在流式输出的台词走底部字幕卡，避免气泡盖住别人的脸。
      if (recent && (last.isStreaming || last.text.length > 20)) continue;
      if (typing && (last == null || !recent || !last.isStreaming)) {
        candidates.add(_Bubble(
          placed: p,
          message: last != null && recent ? last : null,
          typing: true,
          age: 0,
        ));
      } else if (last != null) {
        candidates.add(_Bubble(
          placed: p,
          message: last,
          typing: false,
          age: now.difference(last.time).inMilliseconds,
        ));
      }
    }
    candidates.sort((a, b) => b.placed.feetY.compareTo(a.placed.feetY));
    final selected = candidates.take(2).toList();
    final placedRects = <Rect>[];

    for (final b in selected) {
      final isSticker = b.message?.isSticker ?? false;
      final bubbleW = isSticker ? min(150.0, w * 0.4) : min(w * 0.62, 260.0);
      double bubbleH;
      if (b.typing) {
        bubbleH = 42;
      } else if (isSticker) {
        bubbleH = bubbleW;
      } else {
        final tp = TextPainter(
          text: TextSpan(
            text: b.message!.text,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
          maxLines: 4,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bubbleW - 22);
        bubbleH = tp.height + 26;
      }
      final tail = isSticker ? 0.0 : 7.0;
      final left = (b.placed.centerX - bubbleW / 2)
          .clamp(6.0, max(6.0, w - bubbleW - 6))
          .toDouble();
      var top = b.placed.headTop - bubbleH - tail - 4;
      var rect = Rect.fromLTWH(left, top, bubbleW, bubbleH + tail);
      var guard = 0;
      while (placedRects.any((r) => r.overlaps(rect)) && guard < 4) {
        top -= (bubbleH + 10);
        rect = Rect.fromLTWH(left, top, bubbleW, bubbleH + tail);
        guard++;
      }
      if (top < 2) {
        top = 2;
        rect = Rect.fromLTWH(left, top, bubbleW, bubbleH + tail);
      }
      placedRects.add(rect);
      b
        ..width = bubbleW
        ..height = bubbleH
        ..left = left
        ..top = top
        ..tailX =
            (b.placed.centerX - left).clamp(16.0, bubbleW - 16.0).toDouble();
    }
    return selected;
  }

  Widget _bubbleWidget(_Bubble b, double w, double h) {
    final c = b.placed.character;
    final accent = Color(c.accentColor);
    final age = b.typing ? 300 : b.age;
    final fadeIn = (age / 220).clamp(0.0, 1.0);
    final fadeOut = ((9000 - age) / 700).clamp(0.0, 1.0);
    final opacity = min(fadeIn, fadeOut);
    final content = b.typing
        ? _typingBubble(accent)
        : (b.message!.isSticker
            ? _stickerBubble(b, accent)
            : _textBubble(b, accent));
    return Positioned(
      left: b.left,
      top: b.top,
      width: b.width,
      child: IgnorePointer(
        ignoring: b.typing,
        child: GestureDetector(
          onTap: b.message == null ? null : () => onBubbleTap(b.message!),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, (1 - fadeIn) * 8),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textBubble(_Bubble b, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: b.height - 7),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          decoration: BoxDecoration(
            color: const Color(0xF2141823),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            b.message!.isStreaming ? '${b.message!.text}▍' : b.message!.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5, height: 1.42, color: AppColors.text),
          ),
        ),
        Transform.translate(
          offset: Offset(b.tailX - b.width / 2, 0),
          child: CustomPaint(
            size: const Size(14, 7),
            painter: _TailPainter(color: accent),
          ),
        ),
      ],
    );
  }

  Widget _stickerBubble(_Bubble b, Color accent) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xCC141823),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.asset(b.message!.sticker!, fit: BoxFit.contain),
      ),
    );
  }

  Widget _typingBubble(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF2141823),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: TypingDots(color: accent, size: 5),
    );
  }
}

class _Bubble {
  final _Placed placed;
  final ChatMessage? message;
  final bool typing;
  final int age;
  double width = 0;
  double height = 0;
  double left = 0;
  double top = 0;
  double tailX = 0;

  _Bubble({
    required this.placed,
    required this.message,
    required this.typing,
    required this.age,
  });
}

class _TailPainter extends CustomPainter {
  final Color color;

  _TailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xF2141823));
    final edge = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      edge,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

class _Vignette extends StatelessWidget {
  final Color tint;

  const _Vignette({this.tint = AppColors.bg});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.05,
            colors: [
              Colors.transparent,
              tint.withValues(alpha: 0.18),
              tint.withValues(alpha: 0.55),
            ],
            stops: const [0.55, 0.82, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ConcertLighting extends StatelessWidget {
  const _ConcertLighting();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black.withValues(alpha: 0.32)),
          CustomPaint(painter: _SpotlightPainter()),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  static const colors = [
    Color(0xFF7EC8E3),
    Color(0xFFFFD9A0),
    Color(0xFFF3F3F8),
    Color(0xFFB3A5E0),
    Color(0xFFC9A227),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final x = size.width * (0.14 + i * 0.18);
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.width * 0.11, size.height * 0.72)
        ..lineTo(x - size.width * 0.07, size.height * 0.72)
        ..close();
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors[i].withValues(alpha: 0.18),
          colors[i].withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => false;
}

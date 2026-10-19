// Rive 0.14 推荐 Data Binding；这里用 state machine inputs 是为了让
// `.riv` 作者的接入成本最低（mood/talking/blink/mouth 四个输入）。
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' hide LinearGradient, RadialGradient;

import '../../core/theme.dart';
import '../../models/models.dart';

/// 每个角色可选的“表情差分”状态图。
///
/// 目前只有 Claude 有官方设定图里对齐的三张脸（中性 / 闭眼笑 / 撑脸得意），
/// 所以先把它做成完整的眨眼/口型试点；其余角色只有半身底图 + 情绪 overlay。
/// 新增角色时，把对齐的状态图放到 `assets/portraits/<id>/states/`，
/// 再加一行即可；Rive 资产就绪后走 [_RivePortrait]。
const _stateAssets = <String, Map<String, String>>{
  'claude': {
    'closed': 'assets/portraits/claude/states/closed.png',
    'smug': 'assets/portraits/claude/states/smug.png',
  },
};

const _faceAt = <String, Offset>{
  'dafeiyu': Offset(0.50, 0.240),
  'claude': Offset(0.50, 0.350),
  'gpt': Offset(0.50, 0.240),
  'gemini': Offset(0.50, 0.260),
  'grok': Offset(0.50, 0.270),
};

const _moodOrder = [
  '开心',
  '傲娇',
  '生气',
  '困倦',
  '得意',
  '害羞',
  '无语',
  '兴奋',
  '平静',
  '难过',
];

/// 半身立绘：呼吸/摇摆 + 可选表情差分 + 情绪 overlay + 口型波形。
/// 如果 `assets/rive/<id>.riv` 存在，则自动改用 Rive 状态机。
class CharacterPortrait extends StatefulWidget {
  final Character character;
  final String mood;
  final bool talking;
  final double width;
  final double height;
  final bool framed;

  const CharacterPortrait({
    super.key,
    required this.character,
    required this.mood,
    this.talking = false,
    this.width = 132,
    this.height = 156,
    this.framed = true,
  });

  @override
  State<CharacterPortrait> createState() => _CharacterPortraitState();
}

class _CharacterPortraitState extends State<CharacterPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  final _rng = Random();
  Timer? _blinkTimer;
  Timer? _blinkOffTimer;
  bool _blink = false;
  bool? _hasRive;
  int _blinkToken = 0;

  Map<String, String> get _states =>
      _stateAssets[widget.character.id] ?? const {};

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
    _checkRive();
    _scheduleBlink();
  }

  Future<void> _checkRive() async {
    try {
      await rootBundle.load('assets/rive/${widget.character.id}.riv');
      if (mounted) setState(() => _hasRive = true);
    } catch (_) {
      if (mounted) setState(() => _hasRive = false);
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(seconds: 3 + _rng.nextInt(4)), () {
      if (!mounted) return;
      if ((_states.containsKey('closed') || _hasRive == true) &&
          !widget.talking) {
        setState(() {
          _blink = true;
          _blinkToken++;
        });
        _blinkOffTimer = Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _blink = false);
        });
      }
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkOffTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  String _stateKey() {
    final states = _states;
    if (states.isEmpty) return 'base';
    if (_blink && states.containsKey('closed')) return 'closed';
    if (widget.talking && states.containsKey('smug')) return 'smug';
    final mood = widget.mood;
    if (widget.character.id == 'claude') {
      if (const {'害羞', '开心', '兴奋', '困倦'}.contains(mood)) {
        return 'closed';
      }
      if (const {'傲娇', '得意'}.contains(mood)) return 'smug';
    }
    return 'base';
  }

  String get _asset {
    final key = _stateKey();
    final states = _states;
    if (key != 'base' && states[key] != null) return states[key]!;
    return 'assets/portraits/${widget.character.id}/base.png';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasRive == true) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _RivePortrait(
          character: widget.character,
          mood: widget.mood,
          talking: widget.talking,
          blinkToken: _blinkToken,
        ),
      );
    }
    final accent = Color(widget.character.accentColor);
    return Semantics(
      label: '${widget.character.name}的半身像',
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.framed ? 16 : 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.framed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(widget.character.color).withValues(alpha: 0.30),
                        AppColors.surface2.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              if (widget.framed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.15),
                          radius: 0.75,
                          colors: [
                            accent.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) {
                    final t = _breath.value * 2 * pi;
                    final sway = sin(t);
                    return Transform.translate(
                      offset: Offset(0, -1.4 * sway),
                      child: Transform.rotate(
                        angle: 0.006 * sway,
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scaleX: 1 + 0.006 * sway,
                          scaleY: 1 + 0.010 * sway,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Image.asset(
                      _asset,
                      key: ValueKey(_asset),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(widget.character.initial,
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: accent)),
                      ),
                    ),
                  ),
                ),
              ),
              if (_states.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PortraitEmotePainter(
                        mood: widget.mood,
                        accent: accent,
                        face: _faceAt[widget.character.id] ??
                            const Offset(0.5, 0.25),
                      ),
                    ),
                  ),
                ),
              if (_states.isNotEmpty && widget.mood == '害羞')
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PortraitEmotePainter(
                        mood: widget.mood,
                        accent: accent,
                        face: _faceAt[widget.character.id] ??
                            const Offset(0.5, 0.25),
                        blushOnly: true,
                      ),
                    ),
                  ),
                ),
              if (widget.talking)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: _TalkWave(color: accent, animation: _breath),
                ),
              if (widget.framed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkWave extends StatelessWidget {
  final Color color;
  final Animation<double> animation;

  const _TalkWave({required this.color, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value * 2 * pi;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 2.6,
                  height: 4.0 + 9.0 * (0.5 + 0.5 * sin(t * 4 + i * 1.3)).abs(),
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 不做“换脸手术”，只加不会破坏原画的表情层：腮红/泪/怒筋/Zzz/星星/音符。
class PortraitEmotePainter extends CustomPainter {
  final String mood;
  final Color accent;
  final Offset face;
  final bool blushOnly;

  PortraitEmotePainter({
    required this.mood,
    required this.accent,
    required this.face,
    this.blushOnly = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * face.dx;
    final cy = size.height * face.dy;
    final w = size.width;
    final h = size.height;
    final p = Paint()..style = PaintingStyle.fill;

    if (!blushOnly && (mood == '害羞' || mood == '开心' || mood == '兴奋')) {
      p.color = const Color(0xFFFF6F91).withValues(alpha: 0.30);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - w * 0.115, cy + h * 0.045),
            width: w * 0.115,
            height: h * 0.028),
        p,
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * 0.115, cy + h * 0.045),
            width: w * 0.115,
            height: h * 0.028),
        p,
      );
    }
    if (blushOnly) return;

    switch (mood) {
      case '生气':
        _vein(canvas, Offset(cx + w * 0.16, cy - h * 0.055), w * 0.035);
        break;
      case '难过':
        _tear(canvas, Offset(cx + w * 0.075, cy + h * 0.045), w * 0.018);
        _tear(canvas, Offset(cx + w * 0.13, cy + h * 0.075), w * 0.014);
        break;
      case '困倦':
        _zzz(canvas, Offset(cx + w * 0.15, cy - h * 0.07), w);
        break;
      case '兴奋':
      case '开心':
        _spark(canvas, Offset(cx - w * 0.19, cy - h * 0.04), w * 0.028,
            const Color(0xFFFFD166));
        _spark(canvas, Offset(cx + w * 0.2, cy - h * 0.02), w * 0.022,
            const Color(0xFFFFE7A8));
        break;
      case '得意':
        _note(canvas, Offset(cx + w * 0.18, cy - h * 0.06), w * 0.04);
        break;
    }
  }

  void _vein(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D5E)
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3;
      canvas.drawLine(Offset(c.dx + cos(a) * r, c.dy + sin(a) * r),
          Offset(c.dx + cos(a) * r * 1.6, c.dy + sin(a) * r * 1.6), paint);
      canvas.drawLine(Offset(c.dx - cos(a) * r, c.dy - sin(a) * r),
          Offset(c.dx - cos(a) * r * 1.6, c.dy - sin(a) * r * 1.6), paint);
    }
  }

  void _tear(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r, c.dy + r * 0.5, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy + r * 0.5, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
        path, Paint()..color = const Color(0xFF8ECDF7).withValues(alpha: 0.85));
  }

  void _zzz(Canvas canvas, Offset c, double w) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Z',
        style: TextStyle(
            color: Color(0xFFBFD7FF),
            fontSize: 13,
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c);
    tp.paint(canvas, c + Offset(w * 0.04, -w * 0.04));
    tp.paint(canvas, c + Offset(w * 0.075, -w * 0.078));
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy - r * 0.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy + r * 0.2, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy + r * 0.2, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.2, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
  }

  void _note(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.9);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 0.9, height: r * 0.65), paint);
    canvas.drawRect(
        Rect.fromLTWH(c.dx + r * 0.32, c.dy - r * 1.5, r * 0.16, r * 1.5),
        paint);
  }

  @override
  bool shouldRepaint(PortraitEmotePainter old) =>
      old.mood != mood || old.face != face || old.blushOnly != blushOnly;
}

/// 真正的 Rive 播放器：把 `mood / talking / blink` 喂给名为 `Portrait` 的状态机。
/// 没有 `.riv` 时上面的 fallback 会接管；资产规格见 `assets/rive/README.md`。
class _RivePortrait extends StatefulWidget {
  final Character character;
  final String mood;
  final bool talking;
  final int blinkToken;

  const _RivePortrait({
    required this.character,
    required this.mood,
    required this.talking,
    required this.blinkToken,
  });

  @override
  State<_RivePortrait> createState() => _RivePortraitState();
}

class _RivePortraitState extends State<_RivePortrait>
    with SingleTickerProviderStateMixin {
  StateMachineController? _controller;
  SMINumber? _moodInput;
  SMIBool? _talkingInput;
  SMITrigger? _blinkInput;
  SMINumber? _mouthInput;
  int _lastBlink = 0;
  late final AnimationController _mouth;

  @override
  void initState() {
    super.initState();
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(_applyMouth);
  }

  void _applyMouth() {
    _mouthInput?.value = widget.talking ? 0.25 + 0.75 * _mouth.value : 0.0;
  }

  void _onInit(Artboard artboard) {
    _controller?.dispose();
    final controller =
        StateMachineController.fromArtboard(artboard, 'Portrait');
    if (controller == null) return;
    artboard.addController(controller);
    _controller = controller;
    _moodInput = controller.findInput<double>('mood') as SMINumber?;
    _talkingInput = controller.findInput<bool>('talking') as SMIBool?;
    _blinkInput = controller.findInput<bool>('blink') as SMITrigger?;
    _mouthInput = controller.findInput<double>('mouth') as SMINumber?;
    _applyInputs();
  }

  void _applyInputs() {
    _moodInput?.value = _moodOrder.indexOf(widget.mood).clamp(0, 9).toDouble();
    _talkingInput?.value = widget.talking;
    if (widget.blinkToken != _lastBlink) {
      _lastBlink = widget.blinkToken;
      _blinkInput?.fire();
    }
    if (widget.talking && !_mouth.isAnimating) {
      _mouth.repeat(reverse: true);
    } else if (!widget.talking && _mouth.isAnimating) {
      _mouth.stop();
      _mouthInput?.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _RivePortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyInputs();
  }

  @override
  void dispose() {
    _mouth.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/rive/${widget.character.id}.riv',
      stateMachines: const [],
      onInit: _onInit,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      placeHolder: const SizedBox.shrink(),
    );
  }
}

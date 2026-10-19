import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live2d/flutter_live2d.dart';

import '../../core/live2d_cache.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../portrait/live2d_registry.dart';

/// 私聊里的“全身像”舞台。
///
/// - 有 Live2D 模型（目前是大肥鱼）：用 Cubism 原生渲染，带眨眼、物理、
///   口型动作和表情；
/// - 没有模型：退回全身立绘 + 网格形变（呼吸 / 摇摆 / 头部微动），
///   仍然保持“一个完整的人站在你面前”的观感。
class Live2DPortraitStage extends StatefulWidget {
  final Character character;
  final String mood;
  final bool talking;
  final bool thinking;
  final bool voiceSpeaking;
  final double height;
  final String spriteStyle;
  final bool paused;
  final VoidCallback? onCollapse;
  final ValueChanged<PokeZone>? onPoke;
  final VoidCallback? onSurprise;

  const Live2DPortraitStage({
    super.key,
    required this.character,
    required this.mood,
    required this.height,
    this.talking = false,
    this.thinking = false,
    this.voiceSpeaking = false,
    this.spriteStyle = 'official',
    this.paused = false,
    this.onCollapse,
    this.onPoke,
    this.onSurprise,
  });

  @override
  State<Live2DPortraitStage> createState() => _Live2DPortraitStageState();
}

class _Live2DPortraitStageState extends State<Live2DPortraitStage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Live2DViewController? _controller;
  Live2DModelSpec? _spec;
  bool _modelReady = false;
  bool _modelFailed = false;
  bool _appPaused = false;
  bool _wasTalking = false;
  bool _wasThinking = false;
  int? _expressionIndex;
  String? _expressionOverride;
  Timer? _overrideTimer;
  Timer? _idleMoodTimer;
  final math.Random _rng = math.Random();

  late final AnimationController _ambient;
  late final AnimationController _reaction;
  int _reactionSeed = 0;
  String? _tapHint;
  Timer? _tapHintTimer;
  Timer? _singleTapTimer;
  Offset? _pointerDown;
  DateTime? _pointerDownAt;
  DateTime? _lastTapAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _spec = live2dSpecFor(widget.character.id);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (_spec != null) {
      _controller = Live2DViewController();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadModel());
    }
  }

  Future<void> _loadModel() async {
    final controller = _controller;
    final spec = _spec;
    if (controller == null || spec == null) return;
    final sw = Stopwatch()..start();
    try {
      // 提前解包资源（main 启动时已经在后台跑）；这里 await 一下既避免
      // 和插件自己的解包互相覆盖，也能让首开耗时更可控。
      await prewarmLive2DModels();
      await controller.whenAttached.timeout(const Duration(seconds: 10));
      // Android 的 TextureView 在 platform view create 之后才拿到
      // SurfaceTexture。`whenAttached` 只代表 view 挂上了，此时原生侧
      // 的宽高可能还是 0，loadModel 会直接返回 false。这里做短轮询，
      // 等原生 surface 量出尺寸后再真正加载；用 60ms 而不是 250ms，
      // 避免平白多等一拍。
      var ok = false;
      for (var attempt = 0; attempt < 40 && mounted; attempt++) {
        ok = await controller.loadModel(
          modelDir: spec.directory,
          modelFileName: spec.fileName,
        );
        if (ok) break;
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      if (!mounted) return;
      if (!ok) {
        setState(() => _modelFailed = true);
        return;
      }
      setState(() => _modelReady = true);
      _applyPaused();
      try {
        await controller.startMotion(group: 'Idle', index: 0, priority: 1);
      } catch (_) {
        // 模型没有 Idle 组时也不影响待机，下一帧继续用默认姿势。
      }
      _syncModel(force: true);
      _scheduleIdleMood();
      debugPrint(
          'Live2D ready in ${sw.elapsedMilliseconds}ms (${widget.character.id})');
    } on TimeoutException {
      if (mounted) setState(() => _modelFailed = true);
    } catch (e) {
      debugPrint('Live2D load failed: $e');
      if (mounted) setState(() => _modelFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant Live2DPortraitStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      _applyPaused();
    }
    if (oldWidget.mood != widget.mood ||
        oldWidget.talking != widget.talking ||
        oldWidget.thinking != widget.thinking) {
      _syncModel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused = state != AppLifecycleState.resumed;
    _applyPaused();
  }

  void _applyPaused() {
    if (!_modelReady) return;
    _safe(() => _controller!.setRenderingPaused(widget.paused || _appPaused));
  }

  void _syncModel({bool force = false}) {
    final controller = _controller;
    final spec = _spec;
    if (!_modelReady || controller == null || spec == null) return;

    _applyExpression(
      _expressionOverride ?? _expressionForMood(widget.mood),
      force: force,
    );

    if (widget.thinking && (force || !_wasThinking)) {
      _wasThinking = true;
      _wasTalking = false;
      _safe(() => controller.startMotion(
            group: 'Anima',
            index: spec.thinkingMotionIndex,
            priority: 3,
          ));
    } else if (widget.talking && (force || !_wasTalking)) {
      _wasTalking = true;
      _wasThinking = false;
      _safe(() => controller.startMotion(
            group: 'Anima',
            index: spec.speakMotionIndex,
            priority: 3,
          ));
    } else if (!widget.talking && _wasTalking) {
      _wasTalking = false;
      _safe(() => controller.startMotion(
            group: 'Anima',
            index: spec.thinkEndMotionIndex,
            priority: 2,
          ));
    }
    if (!widget.thinking) _wasThinking = false;
  }

  void _applyExpression(String? name, {bool force = false}) {
    final controller = _controller;
    final spec = _spec;
    if (!_modelReady || controller == null || spec == null) return;
    if (name == null) return;
    final index = spec.expressionIndex(name);
    if (index == null) return;
    if (!force && index == _expressionIndex) return;
    _expressionIndex = index;
    _safe(() => controller.setExpression(index));
  }

  void _setExpressionOverride(String name, Duration duration) {
    _overrideTimer?.cancel();
    _expressionOverride = name;
    _applyExpression(name, force: true);
    _overrideTimer = Timer(duration, () {
      if (!mounted) return;
      _expressionOverride = null;
      _applyExpression(_expressionForMood(widget.mood), force: true);
    });
  }

  void _playReaction(int motionIndex, String expression) {
    final controller = _controller;
    final spec = _spec;
    if (!_modelReady || controller == null || spec == null) return;
    _safe(() => controller.startMotion(
          group: 'Reaction',
          index: motionIndex,
          priority: 2,
        ));
    _setExpressionOverride(expression, const Duration(seconds: 2));
  }

  void _scheduleIdleMood() {
    _idleMoodTimer?.cancel();
    _idleMoodTimer = Timer(
      Duration(seconds: 16 + _rng.nextInt(12)),
      () {
        if (!mounted) return;
        final idle = _modelReady &&
            !widget.paused &&
            !widget.talking &&
            !widget.thinking &&
            _expressionOverride == null;
        if (idle && _spec != null) {
          const names = ['smug', 'wink', 'sleepy', 'love', 'happy2'];
          final name = names[_rng.nextInt(names.length)];
          _setExpressionOverride(
              name, const Duration(seconds: 2, milliseconds: 400));
          if (_rng.nextDouble() < 0.45) {
            final motion = _rng.nextBool()
                ? _spec!.tailMotionIndex
                : _spec!.waveMotionIndex;
            _safe(() => _controller!.startMotion(
                  group: 'Reaction',
                  index: motion,
                  priority: 2,
                ));
          }
        }
        _scheduleIdleMood();
      },
    );
  }

  void _safe(Future<void> Function() action) {
    unawaited(action().catchError((Object e) {
      debugPrint('Live2D command failed: $e');
    }));
  }

  String? _expressionForMood(String mood) {
    switch (mood) {
      case '开心':
      case '兴奋':
        return 'happy';
      case '害羞':
        return 'shy';
      case '得意':
        return 'smug';
      case '傲娇':
        return 'pout';
      case '无语':
      case '困惑':
        return 'puzzled';
      case '困倦':
        return 'sleepy';
      case '生气':
        return 'angry';
      case '难过':
        return 'sad';
      default:
        // relax 的参数全部为 0，用来把上一个表情淡出，回到中性脸。
        return 'relax';
    }
  }

  void _tap(Offset localPosition) {
    _reactionSeed++;
    _reaction.forward(from: 0);
    final zone =
        localPosition.dy < widget.height * 0.38 ? PokeZone.head : PokeZone.body;
    _showTapHint(zone == PokeZone.head ? '摸摸头' : '戳了戳她');
    final spec = _spec;
    if (spec != null) {
      if (zone == PokeZone.head) {
        _playReaction(spec.patMotionIndex, 'shy');
      } else {
        _playReaction(spec.surpriseMotionIndex, 'surprised');
      }
    }
    widget.onPoke?.call(zone);
  }

  void _doubleTap() {
    _reactionSeed++;
    _reaction.forward(from: 0);
    _showTapHint('被逗得跳了一下');
    final spec = _spec;
    if (spec != null) {
      _playReaction(spec.bounceMotionIndex, 'smug');
    }
    widget.onSurprise?.call();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.localPosition;
    _pointerDownAt = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _pointerDown;
    final downAt = _pointerDownAt;
    _pointerDown = null;
    _pointerDownAt = null;
    if (down == null || downAt == null) return;
    final now = DateTime.now();
    if ((event.localPosition - down).distance > 18 ||
        now.difference(downAt) > const Duration(milliseconds: 520)) {
      return;
    }
    final size = context.size;
    // 右上角是“收起全身像”按钮，不要顺手触发摸头。
    if (size != null &&
        event.localPosition.dx > size.width - 64 &&
        event.localPosition.dy < 64) {
      return;
    }
    final last = _lastTapAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 320)) {
      _lastTapAt = null;
      _singleTapTimer?.cancel();
      _doubleTap();
      return;
    }
    _lastTapAt = now;
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _lastTapAt = null;
      _tap(down);
    });
  }

  void _showTapHint(String text) {
    _tapHintTimer?.cancel();
    setState(() => _tapHint = text);
    _tapHintTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _tapHint = null);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapHintTimer?.cancel();
    _singleTapTimer?.cancel();
    _overrideTimer?.cancel();
    _idleMoodTimer?.cancel();
    _ambient.dispose();
    _reaction.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final accent = Color(c.accentColor);
    // 注意：只要模型没有失败，就必须先把 Live2DView 挂进树里，
    // controller.whenAttached 才会完成；不能等 _modelReady 再挂。
    final useLive2D = _spec != null && !_modelFailed && _controller != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _StageBackdrop(
                  character: c,
                  animation: _ambient,
                  accent: accent,
                  mood: widget.mood,
                ),
                if (useLive2D)
                  Center(
                    child: AspectRatio(
                      aspectRatio: 0.52,
                      child: IgnorePointer(
                        // 平台视图会直接吃掉落在它矩形内的原生触摸，导致
                        // 舞台外层的 GestureDetector 收不到 tap。这里让
                        // Flutter 不再把触摸路由给 Live2DView，轻点/双击
                        // 统一由舞台处理。
                        child: Transform.scale(
                          // Cubism 模型的画布比人物本身宽不少，原生侧按画布
                          // 宽度适配后人物只剩半屏；这里绕中心放大，并让脚底
                          // 落回舞台地面的阴影附近。
                          scale: 1.78,
                          alignment: Alignment.center,
                          child: Live2DView(controller: _controller),
                        ),
                      ),
                    ),
                  )
                else
                  _FullBodyRig(
                    character: c,
                    mood: widget.mood,
                    talking: widget.talking,
                    spriteStyle: widget.spriteStyle,
                    accent: accent,
                  ),
                // 模型还在编译 shader / 解码纹理时，先用同一张全身立绘顶着，
                // 用户不用对着空白舞台等；模型就绪后立绘淡出。
                if (useLive2D)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _modelReady ? 0 : 1,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      child: _FullBodyRig(
                        character: c,
                        mood: widget.mood,
                        talking: widget.talking,
                        spriteStyle: widget.spriteStyle,
                        accent: accent,
                      ),
                    ),
                  ),
                if (useLive2D)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              AppColors.bg.withValues(alpha: 0.30),
                            ],
                            stops: const [0.0, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                // 触摸由舞台最外层的 GestureDetector 接管；平台视图会吃掉
                // 兄弟节点的点击，放在祖先节点上才能稳定收到 tap/double tap。
                _StageChrome(
                  character: c,
                  mood: widget.mood,
                  accent: accent,
                  thinking: widget.thinking,
                  talking: widget.talking,
                  live2d: _modelReady,
                  hasModel: _spec != null,
                  failed: _modelFailed,
                  tapHint: _tapHint,
                  onCollapse: widget.onCollapse,
                ),
                if (_spec != null && !_modelReady && !_modelFailed)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ember,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _reaction,
                      builder: (context, _) {
                        if (!_reaction.isAnimating) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _TapSparkPainter(
                            progress: _reaction.value,
                            seed: _reactionSeed,
                            accent: accent,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 背景
// ---------------------------------------------------------------------------

class _StageBackdrop extends StatelessWidget {
  final Character character;
  final Animation<double> animation;
  final Color accent;
  final String mood;

  const _StageBackdrop({
    required this.character,
    required this.animation,
    required this.accent,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackdropPainter(
            t: animation.value,
            color: Color(character.color),
            accent: accent,
            mood: mood,
            seed: character.id.hashCode,
          ),
        );
      },
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double t;
  final Color color;
  final Color accent;
  final String mood;
  final int seed;

  _BackdropPainter({
    required this.t,
    required this.color,
    required this.accent,
    required this.mood,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = t * math.pi * 2;

    // 深夜底色：角色主题色从顶部淡淡压下来。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.bg, color, 0.34)!,
            AppColors.bg,
            const Color(0xFF07090E),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // 月亮与雾光
    final moon = Offset(size.width * 0.79, size.height * 0.16);
    final moonR = size.shortestSide * 0.105;
    canvas.drawCircle(
      moon,
      moonR * 2.6,
      Paint()
        ..shader = RadialGradient(colors: [
          accent.withValues(alpha: 0.20),
          accent.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: moon, radius: moonR * 2.6)),
    );
    canvas.drawCircle(
      moon,
      moonR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3D6), Color(0xFFE8D9B0)],
        ).createShader(Rect.fromCircle(center: moon, radius: moonR)),
    );
    canvas.drawCircle(
      moon + Offset(moonR * 0.28, -moonR * 0.18),
      moonR * 0.16,
      Paint()..color = const Color(0xFFE8D9B0).withValues(alpha: 0.35),
    );

    // 星星
    final rand = math.Random(seed);
    for (var i = 0; i < 46; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height * 0.55;
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * (0.5 + i % 5 * 0.2) + i));
      canvas.drawCircle(
        Offset(x, y),
        0.6 + (i % 3) * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.18 + twinkle * 0.35),
      );
    }

    // 地面光晕与角色阴影位
    final floor =
        Rect.fromLTWH(0, size.height * 0.70, size.width, size.height * 0.30);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: [
            accent.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(floor),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.945),
        width: size.width * 0.48,
        height: size.shortestSide * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 漂浮的光点
    for (var i = 0; i < 16; i++) {
      final s = rand.nextDouble();
      final p = (t * (0.25 + s * 0.35) + s) % 1.0;
      final x = size.width * (0.12 + s * 0.76) + math.sin(p * 5 + s * 12) * 10;
      final y = size.height * (0.92 - p * 0.72);
      final a = (1 - p) * (0.15 + s * 0.35);
      canvas.drawCircle(
        Offset(x, y),
        0.8 + s * 1.6,
        Paint()..color = accent.withValues(alpha: a),
      );
    }

    // 情绪浮游物：让“开心/害羞/困倦/生气”即使不说话也有东西在动。
    _paintMoodMotes(canvas, size, rand);

    // 暗角
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.20),
            Colors.black.withValues(alpha: 0.58),
          ],
          stops: const [0.52, 0.82, 1.0],
        ).createShader(rect),
    );
  }

  void _paintMoodMotes(Canvas canvas, Size size, math.Random rand) {
    final heartMood = const {'害羞', '开心', '兴奋', '得意'}.contains(mood);
    final sleepy = mood == '困倦';
    final angry = mood == '生气';
    if (!heartMood && !sleepy && !angry) return;
    for (var i = 0; i < 5; i++) {
      final s = rand.nextDouble();
      final p = (t * (0.16 + s * 0.10) + i / 5 + s * 0.08) % 1.0;
      final x = size.width * (0.24 + s * 0.52) +
          math.sin(p * 6.0 + i) * (heartMood ? 16 : 8);
      final y = size.height * (0.58 - p * 0.42);
      final fade = math.sin(math.pi * p).clamp(0.0, 1.0);
      if (heartMood) {
        final color =
            i.isEven ? const Color(0xFFFF8FB1) : const Color(0xFFFFD166);
        _heart(canvas, Offset(x, y), 3.2 + s * 3.0,
            color.withValues(alpha: 0.30 * fade));
      } else if (sleepy) {
        canvas.drawCircle(
          Offset(x, y),
          2.0 + s * 3.0,
          Paint()
            ..color = const Color(0xFFBFD7FF).withValues(alpha: 0.30 * fade),
        );
      } else {
        _spark(canvas, Offset(x, y), 3.0 + s * 2.0,
            const Color(0xFFFF6B6B).withValues(alpha: 0.26 * fade));
      }
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.8)
      ..cubicTo(c.dx - r * 1.5, c.dy - r * 0.2, c.dx - r * 0.7, c.dy - r * 1.2,
          c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.7, c.dy - r * 1.2, c.dx + r * 1.5, c.dy - r * 0.2,
          c.dx, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy - r * 0.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy + r * 0.2, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy + r * 0.2, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.2, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.color != color ||
      old.mood != mood;
}

// ---------------------------------------------------------------------------
// 没有 moc3 时的全身立绘（网格形变）
// ---------------------------------------------------------------------------

class _FullBodyRig extends StatefulWidget {
  final Character character;
  final String mood;
  final bool talking;
  final String spriteStyle;
  final Color accent;

  const _FullBodyRig({
    required this.character,
    required this.mood,
    required this.talking,
    required this.spriteStyle,
    required this.accent,
  });

  @override
  State<_FullBodyRig> createState() => _FullBodyRigState();
}

class _FullBodyRigState extends State<_FullBodyRig>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  late final AnimationController _clock;
  int _loadToken = 0;

  String get _asset {
    final file = widget.spriteStyle == 'chibi' ? 'chibi.png' : 'f0.png';
    return 'assets/sprites/${widget.character.id}/$file';
  }

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9600),
    )..repeat();
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    try {
      final data = await rootBundle.load(_asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 720,
      );
      final frame = await codec.getNextFrame();
      if (!mounted || token != _loadToken) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = frame.image;
      });
    } catch (e) {
      debugPrint('full-body rig load failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _FullBodyRig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spriteStyle != widget.spriteStyle ||
        oldWidget.character.id != widget.character.id) {
      _load();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return Center(
        child: Text(
          widget.character.initial,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: widget.accent,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        return CustomPaint(
          painter: _RigPainter(
            image: image,
            t: _clock.value,
            mood: widget.mood,
            accent: widget.accent,
            talking: widget.talking,
          ),
        );
      },
    );
  }
}

class _RigPainter extends CustomPainter {
  final ui.Image image;
  final double t;
  final String mood;
  final Color accent;
  final bool talking;

  static const int _cols = 16;
  static const int _rows = 26;

  _RigPainter({
    required this.image,
    required this.t,
    required this.mood,
    required this.accent,
    required this.talking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = math.min(
      (size.width * 0.98) / iw,
      (size.height * 0.98) / ih,
    );
    final dw = iw * scale;
    final dh = ih * scale;
    final dx = (size.width - dw) / 2;
    final dy = size.height - dh;

    // 脚下影子
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.975),
        width: dw * 0.52,
        height: math.max(8, dh * 0.020),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // 身后的角色色光
    final aura = Rect.fromLTWH(
      size.width * 0.5 - dw * 0.55,
      dy + dh * 0.18,
      dw * 1.10,
      dh * 0.72,
    );
    canvas.drawRect(
      aura,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.13),
            Colors.transparent,
          ],
        ).createShader(aura),
    );

    final phase = t * math.pi * 2;
    final sway = math.sin(phase * 0.62 + 0.4);
    final breath = math.sin(phase * 0.90);

    final positions = Float32List(_cols * _rows * 2);
    final texCoords = Float32List(_cols * _rows * 2);
    var p = 0;
    for (var j = 0; j < _rows; j++) {
      final ny = j / (_rows - 1); // 0 = 脚底, 1 = 头顶
      final head = ((ny - 0.64) / 0.36).clamp(0.0, 1.0).toDouble();
      for (var i = 0; i < _cols; i++) {
        final nx = i / (_cols - 1);
        // 底部锚定的呼吸：身体横向略收放，胸口以上更明显。
        final sx = 1 + 0.0045 * breath * (0.35 + 0.65 * (1 - ny));
        final sy = 1 + 0.0070 * breath * (0.25 + 0.75 * (1 - ny));
        var px = (nx - 0.5) * dw * sx + dw * 0.5;
        var py = dh - ny * dh * sy;
        // 整体轻摆：越高摆幅越大。
        px += sway * 0.006 * dw * math.pow(1 - ny, 1.7);
        py += breath * 0.0030 * dh * (1 - ny * 0.55);
        // 头部微转 / 点头（不破坏原画，只做网格弯曲）。
        px += head * dw * 0.014 * math.sin(phase * 0.55 + 0.9);
        py += head * dh * 0.0045 * math.sin(phase * 0.82 + 2.0);
        positions[p] = dx + px;
        positions[p + 1] = dy + py;
        texCoords[p] = nx * iw;
        texCoords[p + 1] = (1 - ny) * ih;
        p += 2;
      }
    }

    final indices = Uint16List((_cols - 1) * (_rows - 1) * 6);
    var q = 0;
    for (var j = 0; j < _rows - 1; j++) {
      for (var i = 0; i < _cols - 1; i++) {
        final a = j * _cols + i;
        final b = a + 1;
        final c = a + _cols;
        final d = c + 1;
        indices[q++] = a;
        indices[q++] = b;
        indices[q++] = c;
        indices[q++] = b;
        indices[q++] = d;
        indices[q++] = c;
      }
    }

    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
        indices: indices,
      ),
      BlendMode.srcOver,
      Paint()..shader = shader,
    );

    _paintMood(canvas, Rect.fromLTWH(dx, dy, dw, dh));
    if (talking) {
      _paintTalkHint(canvas, Offset(dx + dw * 0.54, dy + dh * 0.30));
    }
  }

  void _paintMood(Canvas canvas, Rect r) {
    final face = Offset(r.left + r.width * 0.50, r.top + r.height * 0.185);
    final w = r.width;
    switch (mood) {
      case '害羞':
      case '开心':
      case '兴奋':
        final paint = Paint()
          ..color = const Color(0xFFFF6F91).withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawOval(
          Rect.fromCenter(
            center: face + Offset(-w * 0.045, r.height * 0.026),
            width: w * 0.060,
            height: r.height * 0.014,
          ),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: face + Offset(w * 0.045, r.height * 0.026),
            width: w * 0.060,
            height: r.height * 0.014,
          ),
          paint,
        );
        _spark(canvas, face + Offset(-w * 0.16, -r.height * 0.055), w * 0.020,
            const Color(0xFFFFD166));
        _spark(canvas, face + Offset(w * 0.17, -r.height * 0.035), w * 0.015,
            const Color(0xFFFFE7A8));
        break;
      case '生气':
      case '傲娇':
        _vein(canvas, face + Offset(w * 0.085, -r.height * 0.030), w * 0.030);
        break;
      case '难过':
        _tear(canvas, face + Offset(w * 0.040, r.height * 0.020), w * 0.012);
        break;
      case '困倦':
        _zzz(canvas, face + Offset(w * 0.10, -r.height * 0.040), w);
        break;
      case '得意':
        _note(canvas, face + Offset(w * 0.13, -r.height * 0.050), w * 0.026);
        break;
    }
  }

  void _paintTalkHint(Canvas canvas, Offset c) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    for (var i = 0; i < 3; i++) {
      final p = (t * 2.2 + i * 0.18) % 1.0;
      final r = 3.0 + p * 10.0;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi * 0.38,
        math.pi * 0.76,
        false,
        paint..color = accent.withValues(alpha: (1 - p) * 0.45),
      );
    }
  }

  void _vein(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D5E).withValues(alpha: 0.85)
      ..strokeWidth = r * 0.26
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        c + Offset(math.cos(a) * r, math.sin(a) * r),
        c + Offset(math.cos(a) * r * 1.5, math.sin(a) * r * 1.5),
        paint,
      );
      canvas.drawLine(
        c - Offset(math.cos(a) * r, math.sin(a) * r),
        c - Offset(math.cos(a) * r * 1.5, math.sin(a) * r * 1.5),
        paint,
      );
    }
  }

  void _tear(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r, c.dy + r * 0.6, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy + r * 0.6, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF8ECDF7).withValues(alpha: 0.8),
    );
  }

  void _zzz(Canvas canvas, Offset c, double w) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          color: const Color(0xFFBFD7FF).withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c);
    tp.paint(canvas, c + Offset(w * 0.028, -w * 0.028));
    tp.paint(canvas, c + Offset(w * 0.052, -w * 0.052));
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy - r * 0.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy + r * 0.2, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy + r * 0.2, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.2, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.8),
    );
  }

  void _note(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.9, height: r * 0.65),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx + r * 0.30, c.dy - r * 1.5, r * 0.16, r * 1.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RigPainter old) =>
      old.t != t ||
      old.image != image ||
      old.mood != mood ||
      old.talking != talking;
}

// ---------------------------------------------------------------------------
// 浮层
// ---------------------------------------------------------------------------

class _StageChrome extends StatelessWidget {
  final Character character;
  final String mood;
  final Color accent;
  final bool thinking;
  final bool talking;
  final bool live2d;
  final bool hasModel;
  final bool failed;
  final String? tapHint;
  final VoidCallback? onCollapse;

  const _StageChrome({
    required this.character,
    required this.mood,
    required this.accent,
    required this.thinking,
    required this.talking,
    required this.live2d,
    required this.hasModel,
    required this.failed,
    this.tapHint,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final status = tapHint ??
        (thinking
            ? '正在想怎么回你…'
            : talking
                ? '正在说话…'
                : '火边很安静');
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
            decoration: BoxDecoration(
              color: const Color(0xB30B0E14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  character.name,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  mood.isEmpty ? '·' : _moodEmoji(mood),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 2,
          child: IconButton(
            tooltip: '收起全身像',
            onPressed: onCollapse,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 21),
            color: AppColors.muted,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Positioned(
          left: 14,
          right: 12,
          bottom: 9,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.text.withValues(alpha: 0.66),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x9910151F),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.9),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      live2d
                          ? Icons.accessibility_new_rounded
                          : Icons.portrait_rounded,
                      size: 10,
                      color: live2d
                          ? AppColors.ember
                          : hasModel && failed
                              ? AppColors.danger
                              : AppColors.dim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      live2d
                          ? 'LIVE2D · 全身'
                          : hasModel && failed
                              ? 'Live2D 载入失败'
                              : hasModel
                                  ? 'Live2D 载入中'
                                  : '全身立绘',
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 0.4,
                        color: live2d
                            ? AppColors.emberSoft
                            : hasModel && failed
                                ? AppColors.danger
                                : AppColors.dim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _moodEmoji(String mood) {
    const emoji = {
      '开心': '😊',
      '傲娇': '😤',
      '生气': '💢',
      '困倦': '😴',
      '得意': '😎',
      '害羞': '😳',
      '无语': '😑',
      '兴奋': '✨',
      '平静': '🌙',
      '难过': '🥺',
    };
    return emoji[mood] ?? '🌙';
  }
}

class _TapSparkPainter extends CustomPainter {
  final double progress;
  final int seed;
  final Color accent;

  _TapSparkPainter({
    required this.progress,
    required this.seed,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed * 31 + 7);
    final cx = size.width * 0.5;
    final cy = size.height * 0.27;
    final fade = (1 - progress).clamp(0.0, 1.0);
    // 先画一圈扩散的光环，保证在深色背景/蓝色裙子上也看得见。
    final ringR = 18 + progress * 66;
    canvas.drawCircle(
      Offset(cx, cy),
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * fade
        ..color = const Color(0xFFFFD166).withValues(alpha: 0.55 * fade),
    );
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + (rand.nextDouble() - 0.5) * 2.8;
      final d = progress * (34 + rand.nextDouble() * 58);
      final p =
          Offset(cx + math.cos(a) * d, cy + math.sin(a) * d - progress * 26);
      final r = (3.4 + rand.nextDouble() * 4.0) * (1 - progress * 0.35);
      final color = switch (i % 3) {
        0 => const Color(0xFFFF8FB1),
        1 => const Color(0xFFFFD166),
        _ => Colors.white,
      };
      if (i.isEven) {
        _heart(canvas, p, r, color.withValues(alpha: fade * 0.95));
      } else {
        _spark(canvas, p, r, color.withValues(alpha: fade * 0.95));
      }
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.2, c.dx - r * 0.8, c.dy - r * 1.2,
          c.dx, c.dy - r * 0.45)
      ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.2, c.dx + r * 1.4, c.dy - r * 0.2,
          c.dx, c.dy + r * 0.9)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy - r * 0.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.2, c.dy + r * 0.2, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy + r * 0.2, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.2, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TapSparkPainter old) =>
      old.progress != progress || old.seed != seed;
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio_service.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../chat/widgets.dart';

class RhythmResult {
  final int score;
  final int maxCombo;
  final int perfect;
  final int total;

  const RhythmResult({
    required this.score,
    required this.maxCombo,
    required this.perfect,
    required this.total,
  });

  double get accuracy => total == 0 ? 0 : perfect / total;
}

Future<RhythmResult?> showRhythmGame(BuildContext context) {
  return Navigator.of(context).push<RhythmResult>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const _RhythmGamePage(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _Note {
  final double time;
  final int lane;
  bool judged = false;
  bool hit = false;
  bool perfect = false;

  _Note(this.time, this.lane);
}

class _RhythmGamePage extends StatefulWidget {
  const _RhythmGamePage();

  @override
  State<_RhythmGamePage> createState() => _RhythmGamePageState();
}

class _RhythmGamePageState extends State<_RhythmGamePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Note> _notes;
  final List<_HitFx> _fx = [];
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfect = 0;
  bool _finished = false;

  static const _duration = 22.0;
  static const _approach = 2.0;

  @override
  void initState() {
    super.initState();
    _notes = _buildNotes();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_duration * 1000).round()),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_finished) _finish();
      })
      ..forward();
  }

  List<_Note> _buildNotes() {
    final rng = Random(20261019);
    final notes = <_Note>[];
    var t = 1.4;
    while (t < _duration - 0.8) {
      final lane = rng.nextInt(resolvedCharacters.length);
      notes.add(_Note(t, lane));
      if (rng.nextDouble() < 0.32) {
        final second = (lane + 1 + rng.nextInt(resolvedCharacters.length - 1)) %
            resolvedCharacters.length;
        notes.add(_Note(t + 0.16, second));
      }
      t += 0.38 + rng.nextDouble() * 0.28;
    }
    return notes;
  }

  double get _elapsed => _c.value * _duration;

  void _tapAt(Offset local, Size size) {
    if (_finished) return;
    if (local.dy < size.height * 0.58) return;
    final lane = (local.dx / size.width * resolvedCharacters.length)
        .floor()
        .clamp(0, resolvedCharacters.length - 1);
    _judge(lane);
  }

  void _judge(int lane) {
    final now = _elapsed;
    _Note? best;
    var bestDelta = double.infinity;
    for (final n in _notes) {
      if (n.judged || n.lane != lane) continue;
      final d = (n.time - now).abs();
      if (d < bestDelta && d < 0.24) {
        bestDelta = d;
        best = n;
      }
    }
    if (best == null) {
      setState(() {
        _combo = 0;
        _fx.add(_HitFx(lane, now, false, false));
      });
      return;
    }
    final note = best;
    note
      ..judged = true
      ..hit = true
      ..perfect = bestDelta < 0.09;
    setState(() {
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
      if (note.perfect) {
        _perfect++;
        _score += 20 + _combo.clamp(0, 20);
      } else {
        _score += 10 + _combo.clamp(0, 10);
      }
      _fx.add(_HitFx(lane, now, true, note.perfect));
    });
    final audio = context.read<AudioService>();
    audio.playSfx(note.perfect ? Sfx.sparkle : Sfx.pluck);
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    _c.stop();
  }

  void _close() {
    Navigator.pop(
      context,
      RhythmResult(
        score: _score,
        maxCombo: _maxCombo,
        perfect: _perfect,
        total: _notes.length,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tapAt(d.localPosition, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _NotePainter(
                    notes: _notes,
                    elapsed: _elapsed,
                    duration: _duration,
                    approach: _approach,
                    fx: _fx,
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
                        child: Row(
                          children: [
                            const Text('LIVE · 篝火演唱会',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emberSoft)),
                            const Spacer(),
                            Text('$_score',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(width: 6),
                            const Text('分',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.muted)),
                            IconButton(
                              onPressed: _finished ? _close : () => _close(),
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _combo >= 3 ? '$_combo COMBO' : '跟着节拍点角色',
                          style: TextStyle(
                            fontSize: _combo >= 3 ? 13 : 11,
                            fontWeight: _combo >= 3
                                ? FontWeight.w800
                                : FontWeight.normal,
                            color: _combo >= 3
                                ? AppColors.emberSoft
                                : AppColors.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_finished) _resultCard(),
                      if (!_finished)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '在鼓点落下的瞬间点她的名字',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.dim.withValues(alpha: 0.9)),
                          ),
                        ),
                      Container(
                        height: 88,
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Row(
                          children: [
                            for (var i = 0; i < resolvedCharacters.length; i++)
                              Expanded(
                                child: _LaneButton(
                                  character: resolvedCharacters[i],
                                  active: _activeLane(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _activeLane(int lane) {
    final now = _elapsed;
    for (final n in _notes) {
      if (!n.judged && n.lane == lane && (n.time - now).abs() < 0.12) {
        return true;
      }
    }
    return false;
  }

  Widget _resultCard() {
    final acc = _notes.isEmpty ? 0 : (_perfect * 100 / _notes.length).round();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 34),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎸 演出结束',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$_score 分',
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.emberSoft)),
            const SizedBox(height: 4),
            Text('最高连击 $_maxCombo · 完美 $acc%',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _close,
                child: const Text('收下掌声'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneButton extends StatelessWidget {
  final Character character;
  final bool active;

  const _LaneButton({required this.character, required this.active});

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentColor);
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? accent : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarDot(character: character, size: 26),
            const SizedBox(height: 4),
            Text(character.name,
                style: TextStyle(
                    fontSize: 9.5, color: active ? accent : AppColors.muted)),
            Text(character.instrument,
                style: const TextStyle(fontSize: 11, height: 1.1)),
          ],
        ),
      ),
    );
  }
}

class _HitFx {
  final int lane;
  final double time;
  final bool hit;
  final bool perfect;

  const _HitFx(this.lane, this.time, this.hit, this.perfect);
}

class _NotePainter extends CustomPainter {
  final List<_Note> notes;
  final double elapsed;
  final double duration;
  final double approach;
  final List<_HitFx> fx;

  _NotePainter({
    required this.notes,
    required this.elapsed,
    required this.duration,
    required this.approach,
    required this.fx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / resolvedCharacters.length;
    final hitY = size.height * 0.70;
    final topY = size.height * 0.10;
    final speed = (hitY - topY) / approach;

    for (var i = 0; i <= resolvedCharacters.length; i++) {
      final x = i * laneW;
      canvas.drawLine(
        Offset(x, topY - 30),
        Offset(x, hitY + 20),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..strokeWidth = 1,
      );
    }
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.ember.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );
    for (var i = 0; i < resolvedCharacters.length; i++) {
      final accent = Color(resolvedCharacters[i].accentColor);
      canvas.drawRect(
        Rect.fromLTWH(i * laneW, hitY - 14, laneW, 28),
        Paint()..color = accent.withValues(alpha: 0.04),
      );
    }

    for (final n in notes) {
      if (n.judged) continue;
      final dy = hitY - (n.time - elapsed) * speed;
      if (dy < -60 || dy > size.height) continue;
      final x = (n.lane + 0.5) * laneW;
      final accent = Color(resolvedCharacters[n.lane].accentColor);
      const r = 11.0;
      canvas.drawCircle(
        Offset(x, dy),
        r + 5,
        Paint()
          ..color = accent.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(Offset(x, dy), r, Paint()..color = accent);
      canvas.drawCircle(
        Offset(x, dy),
        r * 0.45,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    for (final f in fx) {
      final age = elapsed - f.time;
      if (age < 0 || age > 0.45) continue;
      final p = age / 0.45;
      final x = (f.lane + 0.5) * laneW;
      final accent = Color(resolvedCharacters[f.lane].accentColor);
      canvas.drawCircle(
        Offset(x, hitY),
        14 + p * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - p)
          ..color = (f.perfect ? AppColors.emberSoft : accent)
              .withValues(alpha: 1 - p),
      );
      if (f.perfect) {
        final tp = TextPainter(
          text: const TextSpan(
            text: 'PERFECT',
            style: TextStyle(
                color: AppColors.emberSoft,
                fontSize: 11,
                fontWeight: FontWeight.w800),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, hitY - 48 - p * 20));
      }
    }
  }

  @override
  bool shouldRepaint(_NotePainter old) =>
      old.elapsed != elapsed || old.notes.length != notes.length;
}

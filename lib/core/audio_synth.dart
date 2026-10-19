import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 纯 Dart 合成音频，避免引入任何版权音频素材：
/// - 篝火小调 BGM（演唱会）
/// - 篝火噼啪环境音
/// - 交互音效（点击/心跳/生气/星星/音符/鼓/军鼓/拨弦）
class AudioSynth {
  static const _sampleRate = 22050;

  static Future<File> _cached(String name, Uint8List Function() build) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (await file.exists() && await file.length() > 44) return file;
    await file.writeAsBytes(build(), flush: true);
    return file;
  }

  static Future<File> ensureCampfireBgm() =>
      _cached('campfire_bgm_v2.wav', _buildBgm);

  static Future<File> ensureAmbience() =>
      _cached('campfire_ambience_v1.wav', _buildAmbience);

  static Future<File> ensureSfx(String name) =>
      _cached('campfire_sfx_$name.wav', () => _buildSfx(name));

  // A 小调五声音阶：A C D E G
  static const _a4 = 440.0,
      _c5 = 523.25,
      _d5 = 587.33,
      _e5 = 659.25,
      _g5 = 783.99,
      _g4 = 392.0;

  /// (音高, 步数)，每步约 0.24s，两段共 32 步 ≈ 7.7s
  static const _melody = <List<Object>>[
    [_a4, 1],
    [_c5, 1],
    [_d5, 1],
    [_e5, 2],
    [_d5, 1],
    [_c5, 1],
    [_a4, 2],
    [_g4, 1],
    [_a4, 1],
    [_c5, 3],
    [_e5, 1],
    [_d5, 1],
    [_c5, 1],
    [_a4, 2],
    [_g4, 1],
    [_a4, 1],
    [_c5, 1],
    [_d5, 1],
    [_e5, 1],
    [_g5, 2],
    [_e5, 1],
    [_d5, 1],
    [_c5, 2],
    [_a4, 1],
    [_g4, 1],
    [_a4, 4],
  ];

  static Uint8List _buildBgm() {
    const stepSec = 0.24;
    final totalSteps = _melody.fold<int>(0, (sum, n) => sum + (n[1] as int));
    final seconds = max(6.0, totalSteps * stepSec);
    final n = (seconds * _sampleRate).toInt();
    final buf = Float64List(n);

    void tone(double freq, double start, double dur, double amp) {
      final s0 = (start * _sampleRate).toInt();
      final len = (dur * _sampleRate).toInt();
      for (var i = 0; i < len && s0 + i < n; i++) {
        final t = i / _sampleRate;
        final env =
            min(1.0, i / (0.02 * _sampleRate)) * pow(2.718281828, -3.0 * t);
        buf[s0 + i] += amp *
            env *
            (sin(2 * pi * freq * t) + 0.35 * sin(4 * pi * freq * t));
      }
    }

    void thump(double start, double amp) {
      final s0 = (start * _sampleRate).toInt();
      final len = (0.12 * _sampleRate).toInt();
      for (var i = 0; i < len && s0 + i < n; i++) {
        final t = i / _sampleRate;
        buf[s0 + i] +=
            amp * pow(2.718281828, -18 * t) * sin(2 * pi * (120 - 70 * t) * t);
      }
    }

    var pos = 0.0;
    for (final note in _melody) {
      final dur = (note[1] as int) * stepSec;
      tone(note[0] as double, pos, dur * 0.92, 0.5);
      pos += dur;
    }
    final loopLen = pos;
    for (var t = 0.0; t < loopLen; t += 0.48) {
      thump(t, 0.45);
    }
    for (var t = 0.24; t < loopLen; t += 0.96) {
      thump(t, 0.2);
    }
    return _wav(buf);
  }

  static Uint8List _buildSfx(String name) {
    const n = 0.5;
    final len = (_sampleRate * n).toInt();
    final buf = Float64List(len);
    final rng = Random(7);

    void sweep(double f0, double f1, double dur, double amp,
        {double decay = 14}) {
      final l = (dur * _sampleRate).toInt();
      var phase = 0.0;
      for (var i = 0; i < l && i < len; i++) {
        final t = i / _sampleRate;
        final f = f0 + (f1 - f0) * (t / dur);
        phase += 2 * pi * f / _sampleRate;
        buf[i] += amp * exp(-decay * t) * sin(phase);
      }
    }

    void noise(double dur, double amp, {double decay = 25}) {
      final l = (dur * _sampleRate).toInt();
      for (var i = 0; i < l && i < len; i++) {
        final t = i / _sampleRate;
        buf[i] += amp * exp(-decay * t) * (rng.nextDouble() * 2 - 1);
      }
    }

    void bell(double freq, double start, double dur, double amp) {
      final s0 = (start * _sampleRate).toInt();
      final l = (dur * _sampleRate).toInt();
      for (var i = 0; i < l && s0 + i < len; i++) {
        final t = i / _sampleRate;
        buf[s0 + i] += amp *
            exp(-6 * t) *
            (sin(2 * pi * freq * t) + 0.5 * sin(4 * pi * freq * t));
      }
    }

    switch (name) {
      case 'tap':
        sweep(720, 320, 0.09, 0.5, decay: 30);
        noise(0.03, 0.08, decay: 60);
        break;
      case 'heart':
        bell(880, 0.0, 0.18, 0.45);
        bell(1320, 0.08, 0.22, 0.3);
        break;
      case 'angry':
        sweep(150, 70, 0.22, 0.55, decay: 12);
        noise(0.12, 0.18, decay: 20);
        break;
      case 'sparkle':
        bell(1200, 0.0, 0.14, 0.24);
        bell(1600, 0.06, 0.16, 0.22);
        bell(2000, 0.12, 0.2, 0.2);
        break;
      case 'note':
        bell(660, 0.0, 0.22, 0.4);
        bell(990, 0.04, 0.24, 0.2);
        break;
      case 'kick':
        sweep(150, 45, 0.22, 0.9, decay: 16);
        break;
      case 'snare':
        noise(0.16, 0.5, decay: 28);
        bell(190, 0.0, 0.1, 0.2);
        break;
      case 'pluck':
        sweep(520, 500, 0.3, 0.45, decay: 10);
        bell(1040, 0.0, 0.12, 0.15);
        break;
      case 'shutter':
        noise(0.05, 0.4, decay: 70);
        sweep(2200, 1200, 0.06, 0.2, decay: 40);
        break;
      default:
        bell(660, 0.0, 0.2, 0.3);
    }
    return _wav(buf);
  }

  static Uint8List _buildAmbience() {
    const seconds = 9.0;
    final n = (seconds * _sampleRate).toInt();
    final buf = Float64List(n);
    final rng = Random(11);
    var brown = 0.0;
    for (var i = 0; i < n; i++) {
      final white = rng.nextDouble() * 2 - 1;
      brown = (brown + 0.02 * white).clamp(-1.0, 1.0);
      buf[i] = brown * 0.16;
    }
    // 随机噼啪
    for (var t = 0.15; t < seconds - 0.2; t += 0.28 + rng.nextDouble() * 0.9) {
      final s0 = (t * _sampleRate).toInt();
      final dur = (0.015 + rng.nextDouble() * 0.05 * _sampleRate).toInt();
      final amp = 0.12 + rng.nextDouble() * 0.3;
      for (var i = 0; i < dur && s0 + i < n; i++) {
        final f = (1 - i / dur);
        buf[s0 + i] += amp * f * f * (rng.nextDouble() * 2 - 1);
      }
    }
    // 首尾淡入淡出，循环不爆音
    final fade = (0.25 * _sampleRate).toInt();
    for (var i = 0; i < fade; i++) {
      final k = i / fade;
      buf[i] *= k;
      buf[n - 1 - i] *= k;
    }
    return _wav(buf);
  }

  static Uint8List _wav(Float64List samples) {
    final n = samples.length;
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      pcm[i] = (samples[i] * 32767).clamp(-32000, 32000).toInt();
    }
    final bytes = Uint8List(44 + n * 2);
    final bd = ByteData.sublistView(bytes);
    void ascii(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[off + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + n * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, _sampleRate, Endian.little);
    bd.setUint32(28, _sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bd.setUint32(40, n * 2, Endian.little);
    bytes.buffer.asInt16List().setRange(44 ~/ 2, (44 ~/ 2) + n, pcm, 0);
    return bytes;
  }
}

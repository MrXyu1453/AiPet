import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/models.dart';
import '../state/settings_controller.dart';

class _VoiceJob {
  final Character character;
  final String text;

  const _VoiceJob(this.character, this.text);
}

/// 系统 TTS 声线。每个角色用不同的 pitch/rate，至少让“说话”这件事有声音。
/// 如果设备没有中文 TTS 引擎，会安全地退化为静音。
///
/// 所有台词都进入同一个 FIFO 队列：上一句播完才播下一句。之前每条台词
/// 开始前都会 `tts.stop()`，于是下一个角色一开口就把上一个角色的话掐断，
/// 听起来就像在抢话。
class VoiceService extends ChangeNotifier {
  final SettingsController settings;
  final FlutterTts _tts = FlutterTts();

  final List<_VoiceJob> _queue = [];
  bool _draining = false;
  bool _stopping = false;
  int _generation = 0;

  bool _available = true;
  bool _ready = false;
  bool _speaking = false;
  String? _speakingId;

  VoiceService(this.settings);

  bool get available => _available;
  bool get speaking => _speaking;
  String? get speakingId => _speakingId;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setVolume(0.92);
      // speak() 要等到这一句真正播完才返回，队列才能排得下去。
      await _tts.awaitSpeakCompletion(true);
      // 说话状态由 _speakJob 的 await/finally 管理。不要在 completion
      // handler 里清状态：如果引擎的回调晚于下一句开始，会把下一句的
      // “正在说话”误关掉。
      _tts.setErrorHandler((dynamic error) {
        debugPrint('tts error: $error');
      });
      _ready = true;
    } catch (e) {
      debugPrint('tts init failed: $e');
      _available = false;
    }
  }

  /// 入队一句台词。不会打断正在播的那一句。
  Future<void> speak(Character c, String text) async {
    if (!settings.ttsEnabled || !_available) return;
    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) return;
    _queue.add(_VoiceJob(c, clean));
    if (!_draining && !_stopping) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    final generation = _generation;
    try {
      while (_queue.isNotEmpty && generation == _generation) {
        final job = _queue.removeAt(0);
        await _speakJob(job, generation);
      }
    } finally {
      _draining = false;
      if (generation == _generation) {
        _speaking = false;
        _speakingId = null;
        notifyListeners();
      }
      // stop() 期间可能有新台词入队：等引擎真正停下来后再继续排，
      // 避免 _tts.stop() 把刚开口的下一句一起掐掉。
      if (_queue.isNotEmpty && !_stopping) {
        unawaited(_drain());
      }
    }
  }

  Future<void> _speakJob(_VoiceJob job, int generation) async {
    if (!settings.ttsEnabled || !_available) return;
    await init();
    if (!_ready || generation != _generation) return;
    try {
      await _tts.setPitch(job.character.ttsPitch);
      await _tts.setSpeechRate(job.character.ttsRate);
      if (generation != _generation) return;
      _speakingId = job.character.id;
      _speaking = true;
      notifyListeners();
      await _tts.speak(job.text);
    } catch (e) {
      debugPrint('tts speak failed: $e');
    } finally {
      if (generation == _generation) {
        _speaking = false;
        _speakingId = null;
        notifyListeners();
      }
    }
  }

  String _cleanForSpeech(String text) {
    var t = text
        .replaceAll(RegExp(r'[\[【][^\]】]*[\]】]'), '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .trim();
    if (t.length > 180) t = t.substring(0, 180);
    return t;
  }

  /// 用户主动停止/退到后台：清空待播队列并掐断当前这句。
  Future<void> stop() async {
    _generation++;
    _queue.clear();
    // 先同步清掉状态，再去等引擎停；否则新台词可能在 await 期间开始，
    // 被这边的收尾误关掉“正在说话”。
    _speaking = false;
    _speakingId = null;
    _stopping = true;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
    _stopping = false;
    if (!_draining && _queue.isNotEmpty) {
      unawaited(_drain());
    }
  }

  @override
  void dispose() {
    _queue.clear();
    _generation++;
    _tts.stop();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/audio_service.dart';
import '../core/camp_state.dart';
import '../core/chat_engine.dart';
import '../core/prompts.dart';
import '../core/storage.dart';
import '../core/voice_service.dart';
import '../data/characters.dart';
import '../models/models.dart';
import 'chat_session.dart';
import 'settings_controller.dart';

class _PrivateTurn {
  final String text;
  final String? replyToId;

  const _PrivateTurn(this.text, this.replyToId);
}

/// 一对一私聊：没有导演、没有群规，只有你和她的火堆边。
///
/// 和群聊一样使用串行任务队列：用户消息、表情包、重试都排队，上一句
/// 完整说完才会开始下一句，不会出现两个回复同时流式输出的情况。
class PrivateChatSession extends ChatSession {
  final SettingsController settings;
  final CampState camp;
  final AudioService audio;
  final VoiceService voice;
  final Character character;
  final ChatStorage _storage;
  late final ChatEngine engine;

  final List<Future<void> Function()> _jobs = [];
  bool _draining = false;
  int _generation = 0;

  late Future<void> _ready;
  Timer? _persistTimer;
  bool _disposed = false;

  PrivateChatSession({
    required this.settings,
    required this.camp,
    required this.audio,
    required this.voice,
    required this.character,
    ChatStorage? storage,
  }) : _storage = storage ?? ChatStorage() {
    engine = ChatEngine(settings, camp);
    _ready = _restore();
  }

  @override
  bool get canChat => settings.configured || settings.demoMode;

  @override
  bool get demoMode => settings.demoMode;

  @override
  bool get supportsMentions => false;

  @override
  String get title => character.name;

  @override
  String? get characterId => character.id;

  Future<void> _restore() async {
    final loaded = await _storage.load(channel: _channel);
    if (loaded.isEmpty) return;
    messages.addAll(
        loaded.map((m) => m.isStreaming ? m.copyWith(isStreaming: false) : m));
    _notify();
  }

  String get _channel => 'private_${character.id}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _persist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 450), () {
      if (!_disposed) _storage.save(messages, channel: _channel);
    });
  }

  void _schedule(Future<void> Function() job) {
    if (_disposed) return;
    final generation = _generation;
    _jobs.add(() async {
      if (generation != _generation) return;
      await job();
    });
    if (_draining) {
      _notify();
      return;
    }
    unawaited(_drainJobs());
  }

  Future<void> _drainJobs() async {
    if (_draining || _disposed) return;
    _draining = true;
    running = true;
    beginRequest();
    _notify();
    try {
      while (_jobs.isNotEmpty && !stopRequested) {
        final job = _jobs.removeAt(0);
        try {
          await job();
        } catch (e, st) {
          debugPrint('私聊任务失败：$e\n$st');
        }
      }
    } finally {
      _draining = false;
      if (_disposed) {
        running = false;
      } else if (_jobs.isNotEmpty) {
        unawaited(_drainJobs());
      } else {
        running = false;
        _notify();
      }
    }
  }

  @override
  Future<void> sendUser(String text, {String? replyToId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ready;
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'user',
      text: trimmed,
      replyToId: replyToId,
    ));
    _persist();
    _notify();
    camp.rememberFromUserText(trimmed, characterId: character.id);
    if (!canChat) {
      _addSystem(
        '还没有配置 API Key。私聊里的话需要真实模型才能说出口，'
        '可以先打开“试玩模式”听她说两句。',
        isError: true,
      );
      return;
    }
    _schedule(() => _replyNow(_PrivateTurn(trimmed, replyToId)));
  }

  Future<void> _replyNow(_PrivateTurn turn, {String? intent}) async {
    if (stopRequested || _disposed) return;
    typingIds.add(character.id);
    _notify();
    final placeholderId = newId();
    final placeholder = ChatMessage(
      id: placeholderId,
      time: DateTime.now(),
      senderId: character.id,
      text: '',
      isStreaming: true,
    );
    messages.add(placeholder);
    _notify();

    try {
      final history = List.of(messages)
        ..removeWhere((m) => m.id == placeholderId);
      final reply = await engine.generate(
        character: character,
        history: history,
        privateMode: true,
        intent: intent ??
            '你们正在私聊。回应主人刚才的话，可以暧昧一点、放松一点，'
                '不要像群聊那样东张西望。',
        replyQuote: quoteFor(turn.replyToId),
        extraScene: '火堆只剩一小团火，周围很安静，只有你们两个人和偶尔的虫鸣。',
        isCancelled: () => stopRequested,
        onDelta: (raw) {
          final parsed = parseReply(raw, characterName: character.name);
          _updateMessage(
            placeholderId,
            placeholder.copyWith(
              text: parsed.body,
              mood: parsed.mood,
              actions: parsed.actions,
            ),
          );
        },
      );
      if (stopRequested) {
        _finalizeStreaming();
        return;
      }
      final parsed = reply.parsed;
      var body = parsed.body.trim();
      if (body.isEmpty) {
        body =
            character.catchphrases[rng.nextInt(character.catchphrases.length)];
      }
      final finalMsg = placeholder.copyWith(
        text: body,
        mood: parsed.mood,
        actions: parsed.actions,
        isStreaming: false,
      );
      _updateMessage(placeholderId, finalMsg);
      if (parsed.mood != null) {
        camp.setEmotion(character.id, parsed.mood!,
            intensity: reply.demo ? 0.55 : 0.7, reason: '私聊时的对话');
      }
      camp.addAffinity(character.id, 1);
      unawaited(voice.speak(character, body));
      if (rng.nextDouble() < 0.1) {
        messages.add(ChatMessage(
          id: newId(),
          time: DateTime.now(),
          senderId: character.id,
          text: '',
          mood: parsed.mood,
          sticker: character.stickerAsset,
          kind: MessageKind.sticker,
        ));
      }
      _persist();
    } on LlmException catch (e) {
      if (e.kind != LlmErrorKind.cancelled && !stopRequested) {
        _failPlaceholder(placeholderId);
        _addSystem(e.message, isError: true, retryFor: character.id);
      }
    } catch (e) {
      if (!stopRequested) {
        _failPlaceholder(placeholderId);
        _addSystem('${character.name}沉默了…（$e）',
            isError: true, retryFor: character.id);
      }
    } finally {
      typingIds.remove(character.id);
      _notify();
      if (!stopRequested) {
        await Future<void>.delayed(
            Duration(milliseconds: 300 + rng.nextInt(450)));
      }
    }
  }

  void _updateMessage(String id, ChatMessage next) {
    final i = messages.indexWhere((m) => m.id == id);
    if (i < 0 || messages[i] == next) return;
    messages[i] = next;
    _notify();
  }

  void _failPlaceholder(String id) {
    final current = messageById(id);
    if (current == null) return;
    if (current.text.trim().isEmpty) {
      messages.removeWhere((m) => m.id == id);
    } else {
      _updateMessage(id, current.copyWith(isStreaming: false));
    }
  }

  void _finalizeStreaming() {
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].isStreaming) {
        messages[i] = messages[i].copyWith(isStreaming: false);
      }
    }
    _notify();
  }

  void _addSystem(String text, {bool isError = false, String? retryFor}) {
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'system',
      text: text,
      isError: isError,
      retryFor: retryFor,
    ));
    _persist();
    _notify();
  }

  @override
  Future<void> sendSticker(String asset) async {
    await _ready;
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'user',
      text: '',
      sticker: asset,
      kind: MessageKind.sticker,
    ));
    _persist();
    _notify();
    if (!canChat) return;
    // 以前忙碌时直接 return，表情包就永远没人接。现在排队等她说完。
    _schedule(() => _replyNow(
          const _PrivateTurn('（主人发来一张表情包）', null),
          intent: '主人突然发来一张表情包。按你的性格做出反应：害羞、吐槽、'
              '抢过来、或者反过来逗主人。只回一句，像私聊里那样放松。',
        ));
  }

  @override
  Future<void> stop() async {
    _generation++;
    cancelRequested();
    _jobs.clear();
    _finalizeStreaming();
    unawaited(voice.stop());
    _notify();
  }

  @override
  Future<void> retry(ChatMessage message) async {
    messages.removeWhere((m) => m.id == message.id);
    _notify();
    if (message.retryFor == null) return;
    _schedule(() => _replyNow(const _PrivateTurn('（刚才没说完）', null)));
  }

  @override
  Future<void> clear() async {
    await stop();
    messages.clear();
    typingIds.clear();
    _jobs.clear();
    await _storage.clear(channel: _channel);
    _notify();
  }

  Future<String> exportChat() => _storage.exportMarkdown(
        messages,
        {for (final c in resolvedCharacters) c.id: c},
      );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _jobs.clear();
    _persistTimer?.cancel();
    _storage.save(messages, channel: _channel);
    super.dispose();
  }
}

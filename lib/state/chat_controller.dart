import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/audio_service.dart';
import '../core/camp_state.dart';
import '../core/chat_engine.dart';
import '../core/demo.dart';
import '../core/director.dart';
import '../core/prompts.dart';
import '../core/storage.dart';
import '../core/voice_service.dart';
import '../data/characters.dart';
import '../data/events.dart';
import '../models/models.dart';
import 'chat_session.dart';
import 'settings_controller.dart';

class _QueuedTurn {
  final String text;
  final String? replyToId;

  const _QueuedTurn(this.text, this.replyToId);
}

/// 群聊：导演选人、流式发言、接话、戳一戳、投喂、事件、演唱会、闲置话题。
///
/// 所有“角色开口”的动作（回应用户、接话、被戳、投喂、事件、演唱会、
/// 闲置聊天）都进入同一个串行任务队列。上一个角色完整输出（包括流式结束
/// 后的短暂停顿）之前，下一个人不会开始生成，因此不会出现两条消息同时
/// 往外冒、或者后来的角色把前一个角色的话顶掉的情况。
class ChatController extends ChatSession {
  final SettingsController settings;
  final CampState camp;
  final AudioService audio;
  final VoiceService voice;
  final ChatStorage _storage;

  late final ChatEngine engine;
  late final Director director;
  late Future<void> _ready;

  final List<Future<void> Function()> _jobs = [];
  bool _draining = false;
  int _generation = 0;

  final Map<String, DateTime> _lastPoke = {};
  Timer? _idleTimer;
  Timer? _concertTimer;
  Timer? _persistTimer;
  bool _disposed = false;
  bool concert = false;
  String? _sceneNote;

  ChatController({
    required this.settings,
    required this.camp,
    required this.audio,
    required this.voice,
    ChatStorage? storage,
    ChatEngine? engine,
    Director? director,
  }) : _storage = storage ?? ChatStorage() {
    this.engine = engine ?? ChatEngine(settings, camp);
    this.director = director ?? Director(camp);
    _ready = _restore();
  }

  @override
  bool get canChat => settings.configured || settings.demoMode;

  @override
  bool get demoMode => settings.demoMode;

  @override
  bool get supportsMentions => true;

  @override
  String get title => '篝火夜话';

  Future<void> _restore() async {
    final loaded = await _storage.load();
    if (loaded.isEmpty) return;
    messages.addAll(
        loaded.map((m) => m.isStreaming ? m.copyWith(isStreaming: false) : m));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _persist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 450), () {
      if (!_disposed) _storage.save(messages);
    });
  }

  // ---------- 串行发言队列 ----------

  /// 把任务排到队尾。任务本身可能连续说好几句，但同一时间只会有
  /// 一个任务在跑，所以两个角色绝不会同时流式输出。
  void _schedule(Future<void> Function() job) {
    if (_disposed) return;
    final generation = _generation;
    _jobs.add(() async {
      if (generation != _generation) return;
      await job();
    });
    if (_draining) {
      // 让“正在说话”状态和队列长度相关的 UI 立即更新。
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
          // 单个任务出错不能把整条队列带走，否则聊几句就会永久卡住。
          debugPrint('群聊任务失败：$e\n$st');
        }
      }
    } finally {
      _draining = false;
      if (_disposed) {
        running = false;
      } else if (_jobs.isNotEmpty) {
        // stop() 之后用户又发了消息/触发了互动：重新开一轮。
        unawaited(_drainJobs());
      } else {
        running = false;
        _notify();
        _restartIdleTimer();
      }
    }
  }

  // ---------- 用户发言 ----------

  @override
  Future<void> sendUser(String text, {String? replyToId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ready;
    final msg = ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'user',
      text: trimmed,
      replyToId: replyToId,
    );
    messages.add(msg);
    _persist();
    _notify();
    camp.rememberFromUserText(trimmed);
    onUserActive();

    if (!canChat) {
      _addSystem(
        '还没有配置 API Key。去设置页填一个 Key，她们才会真的开口；'
        '也可以打开“试玩模式”先听听她们的声音。',
        isError: true,
      );
      return;
    }
    _schedule(() => _respond(_QueuedTurn(trimmed, replyToId)));
  }

  Future<void> _respond(_QueuedTurn turn) async {
    final picks = director.pickResponders(
      userText: turn.text,
      history: List.of(messages),
      replyToId: turn.replyToId,
    );
    final ids =
        picks.isEmpty ? [director.pickIdleOpener(history: messages)] : picks;
    final quote = quoteFor(turn.replyToId);
    ChatMessage? last;

    for (final id in ids) {
      if (stopRequested) return;
      final spoken = await _speakNow(
        id,
        intent: '用户刚发了一条新消息。你自然地接话：可以吐槽、接梗、转移话题，'
            '也可以只回一句短话。不要复述用户的话。',
        replyQuote: quote,
      );
      if (spoken != null) {
        last = spoken;
        camp.addAffinity(id, 1);
      }
    }

    var chained = 0;
    while (last != null && chained < 2 && !stopRequested) {
      final next = director.pickChain(
        lastSpeaker: last.senderId,
        replyText: last.text,
        history: messages,
      );
      if (next == null) break;
      final spoken = await _speakNow(
        next,
        intent: '你在接 ${characterById(last.senderId)?.name ?? '她'} 的话。'
            '可以拆台、补刀、起哄，或者把话题拉回自己身上。',
        allowSticker: false,
      );
      if (spoken == null) break;
      last = spoken;
      chained++;
    }
  }

  // ---------- 生成一条角色消息 ----------

  /// 只允许在串行任务里调用。返回 null 表示这一句没有说成（取消/失败）。
  Future<ChatMessage?> _speakNow(
    String characterId, {
    String? intent,
    String? replyQuote,
    bool allowSticker = true,
  }) async {
    if (stopRequested || _disposed) return null;
    final c = characterById(characterId);
    if (c == null) return null;
    typingIds.add(characterId);
    _notify();

    final placeholderId = newId();
    final placeholder = ChatMessage(
      id: placeholderId,
      time: DateTime.now(),
      senderId: characterId,
      text: '',
      isStreaming: true,
    );
    messages.add(placeholder);
    _notify();

    ChatMessage? result;
    try {
      final history = List.of(messages)
        ..removeWhere((m) => m.id == placeholderId);
      final reply = await engine.generate(
        character: c,
        history: history,
        privateMode: false,
        intent: intent,
        replyQuote: replyQuote,
        extraScene: _sceneNote,
        isCancelled: () => stopRequested,
        onDelta: (raw) {
          final parsed = parseReply(raw, characterName: c.name);
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
        return null;
      }
      final parsed = reply.parsed;
      var body = parsed.body.trim();
      if (body.isEmpty) {
        body = c.catchphrases[rng.nextInt(c.catchphrases.length)];
      }
      result = placeholder.copyWith(
        text: body,
        mood: parsed.mood,
        actions: parsed.actions,
        isStreaming: false,
      );
      _updateMessage(placeholderId, result);
      if (parsed.mood != null) {
        camp.setEmotion(
          characterId,
          parsed.mood!,
          intensity: reply.demo ? 0.58 : 0.72,
          reason: '刚才的对话',
        );
      }
      unawaited(voice.speak(c, body));
      if (allowSticker &&
          parsed.mood != null &&
          const {'开心', '兴奋', '得意', '害羞'}.contains(parsed.mood) &&
          rng.nextDouble() < 0.16) {
        messages.add(ChatMessage(
          id: newId(),
          time: DateTime.now(),
          senderId: characterId,
          text: '',
          mood: parsed.mood,
          sticker: c.stickerAsset,
          kind: MessageKind.sticker,
        ));
      }
      _persist();
    } on LlmException catch (e) {
      if (e.kind != LlmErrorKind.cancelled && !stopRequested) {
        _failPlaceholder(placeholderId);
        _addSystem(e.message, isError: true, retryFor: characterId);
      }
    } catch (e) {
      if (!stopRequested) {
        _failPlaceholder(placeholderId);
        _addSystem('${c.name} 的话说到一半，信号被鲸鱼吞了…（$e）',
            isError: true, retryFor: characterId);
      }
    } finally {
      typingIds.remove(characterId);
      _notify();
      if (!stopRequested) {
        // 两条消息之间留一点呼吸感，也让 UI 有时间把上一条收尾。
        await Future<void>.delayed(
            Duration(milliseconds: 320 + rng.nextInt(520)));
      }
    }
    if (stopRequested) return null;
    return result;
  }

  /// 本地台词（试玩模式的投喂回应），同样只允许在串行任务里调用。
  Future<ChatMessage?> _localLine(Character c, DemoLine line) async {
    if (stopRequested || _disposed) return null;
    typingIds.add(c.id);
    _notify();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (stopRequested) return null;
      final msg = ChatMessage(
        id: newId(),
        time: DateTime.now(),
        senderId: c.id,
        text: line.text,
        mood: line.mood,
        actions: line.actions,
      );
      messages.add(msg);
      camp.setEmotion(c.id, line.mood, intensity: 0.62, reason: '刚才的互动');
      unawaited(voice.speak(c, line.text));
      _persist();
      _notify();
      return msg;
    } finally {
      typingIds.remove(c.id);
      _notify();
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

  void _addSystem(
    String text, {
    bool isError = false,
    String? retryFor,
    MessageKind kind = MessageKind.system,
  }) {
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'system',
      text: text,
      kind: kind,
      isError: isError,
      retryFor: retryFor,
    ));
    _persist();
    _notify();
  }

  // ---------- 停止 / 重试 / 清空 ----------

  @override
  Future<void> stop() async {
    // 让正在跑的旧任务作废，但保留 stop() 之后新入队的任务。
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
    final id = message.retryFor;
    if (id == null) return;
    _schedule(() async {
      await _speakNow(
        id,
        intent: '刚才网络断了，请把没说完的话接着说，不要解释故障。',
      );
    });
  }

  @override
  Future<void> clear() async {
    await stop();
    messages.clear();
    typingIds.clear();
    _jobs.clear();
    await _storage.clear();
    _notify();
  }

  // ---------- 戳一戳 ----------

  Future<void> poke(String characterId, {PokeZone zone = PokeZone.face}) async {
    await _ready;
    final c = characterById(characterId);
    if (c == null) return;
    final now = DateTime.now();
    final last = _lastPoke[characterId];
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastPoke[characterId] = now;
    camp.addAffinity(characterId, 1);
    _addSystem('你${_zoneAction(zone)}。');
    if (!canChat) return;

    // 不再“忙的时候随便塞一句本地台词”。排队，等当前角色说完再反应。
    _schedule(() async {
      await _speakNow(
        characterId,
        intent: '${_zoneAction(zone)}。按你的性格对“被${_zoneName(zone)}”这件事做出反应：'
            '可以生气、害羞、傲娇、无语或者反过来调戏用户。只回一句台词。',
        allowSticker: false,
      );
    });
  }

  String _zoneName(PokeZone z) => switch (z) {
        PokeZone.head => '摸头',
        PokeZone.face => '戳脸',
        PokeZone.body => '戳肩膀',
        PokeZone.tail => '碰尾巴',
      };

  String _zoneAction(PokeZone z) => switch (z) {
        PokeZone.head => '摸了摸她的头',
        PokeZone.face => '戳了戳她的脸',
        PokeZone.body => '戳了戳她的肩膀',
        PokeZone.tail => '轻轻碰了碰她的尾巴',
      };

  // ---------- 表情包 / 真心话 ----------

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
    onUserActive();

    if (!canChat) return;
    _schedule(() async {
      if (stopRequested) return;
      final id = director.pickIdleOpener(history: messages);
      await _speakNow(
        id,
        intent: '主人突然发来一张表情包。按你的性格做出反应：可以害羞、吐槽、'
            '把表情包抢过来，或者反过来发一张更欠揍的。只回一句。',
        allowSticker: false,
      );
    });
  }

  /// 真心话 / 大冒险：用户点名一个人，把问题或任务递给她。
  Future<void> askTruth(
    String characterId,
    String prompt, {
    bool dare = false,
  }) async {
    await _ready;
    final c = characterById(characterId);
    if (c == null) return;
    final label = dare ? '大冒险' : '真心话';
    _addSystem(
      '🕯️ $label · 你点名 ${c.name}：$prompt',
      kind: MessageKind.event,
    );
    camp.addMemory(
      '$label：你问${c.name}「$prompt」',
      characterId: characterId,
      kind: MemoryKind.event,
    );
    camp.addAffinity(characterId, 2);
    if (!canChat) return;
    _schedule(() async {
      await _speakNow(
        characterId,
        intent: dare
            ? '主人给你抽了一个大冒险：$prompt。'
                '按你的性格完成它（可以夸张、嘴硬、讨价还价），然后说一句台词。'
            : '主人问了你一个真心话：$prompt。'
                '认真回答。可以嘴硬、害羞、转移话题，但最后要露出一点真心。',
        allowSticker: false,
      );
    });
  }

  // ---------- 投喂 ----------

  Future<void> giveGift(String characterId, GiftItem gift) async {
    await _ready;
    final c = characterById(characterId);
    if (c == null) return;
    final liked =
        c.likes.any((l) => gift.name.contains(l) || l.contains(gift.name));
    final disliked =
        c.dislikes.any((l) => gift.name.contains(l) || l.contains(gift.name));
    final delta = liked ? 6 : (disliked ? 0 : 3);
    camp.addAffinity(characterId, delta);
    camp.addMemory('送过${c.name}一个${gift.name}',
        characterId: characterId, kind: MemoryKind.event);
    if (liked) {
      camp.setEmotion(characterId, '开心',
          intensity: 0.8, reason: '收到了${gift.name}');
    } else if (disliked) {
      camp.setEmotion(characterId, '无语',
          intensity: 0.6, reason: '收到了${gift.name}');
    }
    _addSystem('你把 ${gift.emoji}${gift.name} 递给了 ${c.name}。'
        '${liked ? '她的眼睛亮了一下。' : disliked ? '她看起来不太想要。' : ''}');
    if (!canChat) return;

    _schedule(() async {
      if (stopRequested) return;
      if (demoMode) {
        await _localLine(c, engine.demo.gift(c, gift.name, liked));
        return;
      }
      await _speakNow(
        characterId,
        intent: '主人送了你 ${gift.emoji}${gift.name}。'
            '${liked ? '你很喜欢这个礼物。' : disliked ? '你不喜欢这个礼物。' : '你对这个礼物感觉一般。'}'
            '按你的性格回应，可以嘴硬，也可以真心道谢。',
        allowSticker: false,
      );
    });
  }

  // ---------- 篝火事件 ----------

  Future<void> chooseEvent(CampEvent event, CampEventChoice choice) async {
    await _ready;
    if (camp.lastEventId == event.id && !camp.eventAvailableToday) return;
    camp.markEventDone(event.id);
    camp.addMemory('${event.title}：${choice.label}',
        characterId: 'all', kind: MemoryKind.event);
    _addSystem(
      '${event.emoji} ${event.title}\n${choice.label}',
      kind: MessageKind.event,
    );

    final picks = director.pickResponders(
      userText: choice.intent,
      history: List.of(messages),
      maxPicks: 2,
    );
    if (!canChat) return;
    for (final id in picks) {
      camp.addAffinity(id, choice.affinity);
      camp.setEmotion(id, choice.mood, intensity: 0.75, reason: event.title);
    }
    // 以前 busy 时直接 return，事件就没人接话，看起来像聊天断了。
    // 现在排队，等当前发言结束后依次反应。
    _schedule(() async {
      for (final id in picks) {
        if (stopRequested) break;
        await _speakNow(
          id,
          intent: '营地事件：${event.title}。${choice.intent} '
              '按你的性格对这件事做出反应，可以吐槽、起哄、说真心话，或者只回一句。',
          allowSticker: false,
        );
      }
    });
  }

  // ---------- 演唱会 ----------

  Future<void> toggleConcert() async {
    concert = !concert;
    await audio.setConcert(concert);
    if (concert) {
      _sceneNote = '篝火被清空成舞台，彩色灯光打在湖面上，五个人抄起了各自的乐器。';
      _addSystem('🎶 演唱会开始！五个娘抄起各自的家伙，火堆变成了舞台。');
      _concertTimer?.cancel();
      _concertTimer = Timer.periodic(const Duration(seconds: 14), (_) {
        unawaited(_concertBeat());
      });
      unawaited(_concertBeat());
    } else {
      _concertTimer?.cancel();
      _concertTimer = null;
      _sceneNote = null;
      _addSystem('演唱会散场，大家重新围着火堆坐下。');
    }
    _notify();
  }

  Future<void> _concertBeat() async {
    if (!concert || !canChat) return;
    // 不把演唱会节拍排到聊天后面；忙碌时跳过这一拍，等下一拍。
    if (_draining || _jobs.isNotEmpty || typingIds.isNotEmpty) return;
    _schedule(() async {
      if (!concert || stopRequested) return;
      final singer = director.pickIdleOpener(history: messages);
      final c = characterById(singer);
      await _speakNow(
        singer,
        intent: '演唱会进行中。你现在站在火堆前担当主唱（乐队位置：${c?.instrument ?? '🎤'}），'
            '唱一句应景的歌词、带节奏的喊话，或者边跳边说。心情尽量兴奋或开心。',
        allowSticker: false,
      );
    });
  }

  Future<void> announceConcertResult(int score, int combo) async {
    _addSystem('🎸 演唱会结束：得分 $score，最高连击 $combo。');
    if (!canChat) return;
    _schedule(() async {
      if (stopRequested) return;
      final id = director.pickIdleOpener(history: messages);
      await _speakNow(
        id,
        intent: '刚刚的演唱会结束了，观众（主人）拿到了 $score 分。'
            '以你的性格评价一下这场演出，可以嘴硬也可以夸。',
        allowSticker: false,
      );
    });
  }

  // ---------- 闲置：娘际互聊 ----------

  @override
  void onUserActive() => _restartIdleTimer();

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (_disposed) return;
    // 上一版要等 90 秒，很多时候用户以为“她们不说话了”。45 秒足够让
    // 一个人读完回复；用户一打字/发消息就会重新计时。
    _idleTimer = Timer(const Duration(seconds: 45), () {
      unawaited(_banter());
    });
  }

  Future<void> _banter() async {
    if (!canChat || concert || _disposed) {
      _restartIdleTimer();
      return;
    }
    // 已经有人在说、或者队列里还有互动：不插队，稍后再试。
    if (_draining || _jobs.isNotEmpty || typingIds.isNotEmpty) {
      _restartIdleTimer();
      return;
    }
    _schedule(() async {
      if (stopRequested) return;
      final opener = director.pickIdleOpener(history: messages);
      final first = await _speakNow(
        opener,
        intent: '主人已经安静了一会儿。你主动挑起一个话题：'
            '可以聊吃的、吐槽主人、互相挑衅，或者提起之前聊过的事。',
        allowSticker: false,
      );
      if (first == null || stopRequested) return;
      if (rng.nextDouble() < 0.78) {
        final next = director.pickChain(
          lastSpeaker: opener,
          replyText: first.text,
          history: messages,
        );
        if (next != null) {
          await _speakNow(next,
              intent: '接住刚才的话题，自然一点。', allowSticker: false);
        }
      }
    });
  }

  // ---------- 导出 ----------

  Future<String> exportChat() => _storage.exportMarkdown(
        messages,
        {for (final c in resolvedCharacters) c.id: c},
      );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _jobs.clear();
    _idleTimer?.cancel();
    _concertTimer?.cancel();
    _persistTimer?.cancel();
    _storage.save(messages);
    super.dispose();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/characters.dart';
import '../models/models.dart';
import 'storage.dart';

/// 营地长期状态：情绪、好感、记忆、夜次。全部落盘，重启后她们还记得。
class CampState extends ChangeNotifier {
  final JsonStore store;
  CampState([JsonStore? store]) : store = store ?? JsonStore();

  final Map<String, EmotionState> _emotions = {};
  final Map<String, AffinityState> _affinities = {};
  final List<MemoryItem> _memories = [];
  String _visitDay = '';
  int _nightCount = 1;
  DateTime? _lastEventAt;
  String? _lastEventId;
  bool _loaded = false;
  Timer? _saveTimer;
  int _seq = 0;

  bool get loaded => _loaded;
  int get nightCount => _nightCount;
  DateTime? get lastEventAt => _lastEventAt;
  String? get lastEventId => _lastEventId;
  List<MemoryItem> get memories => List.unmodifiable(_memories);

  String get _today => AffinityState.dayKeyOf(DateTime.now());

  Future<void> load() async {
    final raw = await store.read('camp_state.json');
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final emotions = map['emotions'];
      if (emotions is Map) {
        for (final e in emotions.entries) {
          final v = e.value;
          if (v is Map) {
            _emotions[e.key.toString()] =
                EmotionState.fromJson(Map<String, dynamic>.from(v));
          }
        }
      }
      final affinities = map['affinities'];
      if (affinities is Map) {
        for (final e in affinities.entries) {
          final v = e.value;
          if (v is Map) {
            _affinities[e.key.toString()] =
                AffinityState.fromJson(Map<String, dynamic>.from(v));
          }
        }
      }
      final memories = map['memories'];
      if (memories is List) {
        for (final m in memories) {
          if (m is Map) {
            _memories.add(MemoryItem.fromJson(Map<String, dynamic>.from(m)));
          }
        }
      }
      _visitDay = (map['visitDay'] as String?) ?? '';
      _nightCount = ((map['nightCount'] as num?) ?? 1).toInt();
      _lastEventAt = DateTime.tryParse((map['lastEventAt'] as String?) ?? '');
      _lastEventId = map['lastEventId'] as String?;
    }
    if (_visitDay != _today) {
      _visitDay = _today;
      _nightCount = max(1, _nightCount + 1);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await store.write('camp_state.json', {
      'emotions': _emotions.map((k, v) => MapEntry(k, v.toJson())),
      'affinities': _affinities.map((k, v) => MapEntry(k, v.toJson())),
      'memories': _memories.map((m) => m.toJson()).toList(),
      'visitDay': _visitDay,
      'nightCount': _nightCount,
      'lastEventAt': _lastEventAt?.toIso8601String(),
      'lastEventId': _lastEventId,
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveTimer = null;
      flush();
    });
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${Random().nextInt(9999)}';

  // ---------- 情绪 ----------

  EmotionState emotionFor(String characterId) {
    final state = _emotions[characterId];
    if (state == null) return EmotionState.neutral(DateTime.now());
    return state.decayed(DateTime.now());
  }

  void setEmotion(
    String characterId,
    String mood, {
    double intensity = 0.65,
    String? reason,
  }) {
    if (!kMoodEmojis.containsKey(mood)) return;
    if (mood == kNeutralMood) {
      _emotions[characterId] =
          EmotionState.neutral(DateTime.now()).copyWith(reason: reason);
    } else {
      _emotions[characterId] = EmotionState(
        mood: mood,
        intensity: intensity.clamp(0.15, 1.0),
        reason: reason,
        updatedAt: DateTime.now(),
      );
    }
    _scheduleSave();
    notifyListeners();
  }

  // ---------- 好感 ----------

  AffinityState affinityFor(String characterId) {
    final state = _affinities[characterId];
    if (state == null) return AffinityState.initial(DateTime.now());
    return state.normalized(DateTime.now());
  }

  int addAffinity(String characterId, int delta) {
    final before = affinityFor(characterId).value;
    final next = affinityFor(characterId).gain(delta, DateTime.now());
    _affinities[characterId] = next;
    if (next.value != before) {
      _scheduleSave();
      notifyListeners();
    }
    return next.value - before;
  }

  // ---------- 记忆 ----------

  List<MemoryItem> memoriesFor(String characterId, {int limit = 24}) {
    final list = _memories
        .where((m) => m.characterId == characterId || m.characterId == 'all')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  MemoryItem? addMemory(
    String text, {
    String characterId = 'all',
    MemoryKind kind = MemoryKind.fact,
  }) {
    final clean = text.trim();
    if (clean.length < 2) return null;
    final normalized = clean.replaceAll(RegExp(r'\s+'), '');
    for (final m in _memories) {
      if (m.text.replaceAll(RegExp(r'\s+'), '') == normalized) return null;
    }
    final item = MemoryItem(
      id: newId(),
      text: clean,
      characterId: characterId,
      kind: kind,
      createdAt: DateTime.now(),
    );
    _memories.insert(0, item);
    if (_memories.length > 160) _memories.removeRange(160, _memories.length);
    _scheduleSave();
    notifyListeners();
    return item;
  }

  void removeMemory(String id) {
    _memories.removeWhere((m) => m.id == id);
    _scheduleSave();
    notifyListeners();
  }

  void clearMemories() {
    _memories.clear();
    _scheduleSave();
    notifyListeners();
  }

  /// 从用户输入里做轻量事实抽取，不额外花 token。
  MemoryItem? rememberFromUserText(String text, {String? characterId}) {
    final patterns = <(RegExp, MemoryKind, String)>[
      (RegExp(r'我(?:叫|名字叫)\s*([^\s，。,.!?！？]{1,12})'), MemoryKind.fact, '主人叫'),
      (
        RegExp(r'我(?:喜欢|最爱|爱)\s*([^\s，。,.!?！？]{1,24})'),
        MemoryKind.fact,
        '主人喜欢'
      ),
      (
        RegExp(r'我(?:讨厌|不喜欢|怕|害怕)\s*([^\s，。,.!?！？]{1,24})'),
        MemoryKind.fact,
        '主人害怕/讨厌'
      ),
      (
        RegExp(r'我(?:的)?生日(?:是|在)?\s*([^\s，。,.!?！？]{1,20})'),
        MemoryKind.fact,
        '主人生日'
      ),
      (RegExp(r'记住[：:，,\s]*(.{2,48})'), MemoryKind.promise, '主人让我记住'),
      (
        RegExp(r'答应[^，。,.!?！？]{0,8}[：:，,\s]*(.{2,48})'),
        MemoryKind.promise,
        '约定'
      ),
    ];
    for (final p in patterns) {
      final m = p.$1.firstMatch(text);
      if (m != null) {
        final value = m.group(1)?.trim();
        if (value == null || value.isEmpty) continue;
        final label = p.$3;
        if (label == '主人叫') {
          return addMemory('主人的名字是$value', characterId: 'all');
        }
        if (label == '约定') {
          return addMemory('约定：$value',
              characterId: characterId ?? 'all', kind: MemoryKind.promise);
        }
        return addMemory('$label$value',
            characterId: characterId ?? 'all', kind: p.$2);
      }
    }
    return null;
  }

  // ---------- 事件 ----------

  bool get eventAvailableToday {
    final last = _lastEventAt;
    if (last == null) return true;
    return AffinityState.dayKeyOf(last) != _today;
  }

  void markEventDone(String eventId) {
    _lastEventAt = DateTime.now();
    _lastEventId = eventId;
    _scheduleSave();
    notifyListeners();
  }

  // ---------- 提示词上下文 ----------

  String promptContext(String characterId, {required String nickname}) {
    final c = characterById(characterId);
    final emotion = emotionFor(characterId);
    final aff = affinityFor(characterId);
    final mem = memoriesFor(characterId, limit: 6);
    final now = DateTime.now();
    final scene = sceneLabel(now);
    final b = StringBuffer()
      ..writeln('【营地状态】')
      ..writeln('时间是 ${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}，$scene。')
      ..writeln('用户称呼：$nickname。你在心里对他的好感：'
          '${aff.value}/100（${aff.tier}）。');
    if (!emotion.isNeutral) {
      b.writeln(
          '你此刻的心情：${emotion.mood}（强度 ${emotion.intensity.toStringAsFixed(2)}'
          '${emotion.reason == null ? '' : '，因为${emotion.reason}'}）。');
    } else {
      b.writeln('你此刻心情平静，但带着一点篝火夜的困意。');
    }
    if (mem.isNotEmpty) {
      b.writeln('你记得这些事：');
      for (final m in mem) {
        b.writeln('· ${m.text}');
      }
    }
    if (c != null) {
      b.writeln('你和大家的关系：${c.relationships}');
    }
    return b.toString().trim();
  }

  String sceneLabel(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 8) return '天刚蒙蒙亮，篝火只剩暗红的炭';
    if (h >= 8 && h < 17) return '白天，篝火营地安静得有点不像话';
    if (h >= 17 && h < 19) return '黄昏，湖面被晚霞染成橘色';
    if (h >= 19 && h < 23) return '夜谈正酣，火星噼啪作响';
    if (h >= 23 || h < 2) return '夜深了，篝火快灭了，大家都压低声音';
    return '凌晨，困得眼睛都睁不开，但谁也不想先走';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    flush();
    super.dispose();
  }
}

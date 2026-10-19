import 'dart:math';

import '../data/characters.dart';
import '../models/models.dart';
import 'camp_state.dart';

/// 本地导演：用 @、引用、沉默时长、心情、好感做加权，不额外消耗 token。
/// 需要“理解气氛”的复杂情况再交给模型（由 ChatEngine 的 intent 完成）。
class Director {
  final CampState camp;
  final Random rng;

  Director(this.camp, [Random? rng]) : rng = rng ?? Random();

  List<String> mentioned(String text) {
    final lower = text.toLowerCase();
    final result = <String>[];
    for (final c in resolvedCharacters) {
      if (text.contains('@${c.name}') ||
          lower.contains('@${c.id}') ||
          text.contains('@${c.name.replaceAll('娘', '')}')) {
        result.add(c.id);
      }
    }
    return result;
  }

  int _lastSpoke(List<ChatMessage> history, String id) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].senderId == id) return i;
    }
    return -1;
  }

  double _score(
    Character c,
    List<ChatMessage> history, {
    required String userText,
    required Set<String> mentionedIds,
    String? replyToId,
  }) {
    var score = 0.18 + rng.nextDouble() * 0.45;
    if (mentionedIds.contains(c.id)) score += 4.2;
    if (replyToId == c.id) score += 3.0;

    final last = _lastSpoke(history, c.id);
    score += (history.length - last).clamp(0, 12) * 0.045;

    final aff = camp.affinityFor(c.id);
    score += (aff.value / 100.0) * 0.5;
    final emo = camp.emotionFor(c.id);
    if (!emo.isNeutral) score += emo.intensity * 0.45;

    final asks = RegExp(r'[?？]|谁|吗|怎么|为什么|哪|要不要|帮我').hasMatch(userText);
    if (asks) score += 0.18;
    if (userText.length > 24) score += 0.08;
    return score;
  }

  List<String> pickResponders({
    required String userText,
    required List<ChatMessage> history,
    int maxPicks = 2,
    String? replyToId,
  }) {
    final mentionedIds = mentioned(userText).toSet();
    if (mentionedIds.isNotEmpty) {
      return mentionedIds.take(maxPicks).toList();
    }
    final scored = resolvedCharacters
        .map((c) => MapEntry(
            c.id,
            _score(c, history,
                userText: userText,
                mentionedIds: mentionedIds,
                replyToId: replyToId)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final picks = <String>[scored.first.key];
    if (maxPicks > 1 &&
        scored.length > 1 &&
        scored[1].value > scored.first.value * 0.82) {
      picks.add(scored[1].key);
    }
    return picks;
  }

  /// 接话：优先接回复里 @ 的人；否则有概率随机补刀。
  String? pickChain({
    required String lastSpeaker,
    required String replyText,
    required List<ChatMessage> history,
  }) {
    final mentionedIds = mentioned(replyText).where((id) => id != lastSpeaker);
    if (mentionedIds.isNotEmpty) return mentionedIds.first;
    if (rng.nextDouble() > 0.52) return null;

    final others = resolvedCharacters
        .where((c) => c.id != lastSpeaker)
        .map((c) => MapEntry(
            c.id,
            _score(c, history,
                userText: replyText,
                mentionedIds: const {},
                replyToId: lastSpeaker)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (others.isEmpty) return null;
    final top = others.take(2).toList();
    return top[rng.nextInt(top.length)].key;
  }

  String pickIdleOpener({required List<ChatMessage> history}) {
    final scored = resolvedCharacters
        .map((c) => MapEntry(
              c.id,
              _score(c, history,
                  userText: '大家都安静了，谁想找点话说？',
                  mentionedIds: const {}).toDouble(),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored[rng.nextInt(min(3, scored.length))].key;
  }
}

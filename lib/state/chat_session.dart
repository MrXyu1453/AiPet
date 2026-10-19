import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/characters.dart';
import '../models/models.dart';

/// 群聊与私聊的共同接口，聊天面板只依赖它。
abstract class ChatSession extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  final Set<String> typingIds = {};
  bool running = false;
  bool stopRequested = false;

  int _seq = 0;
  final Random rng = Random();

  bool get busy => running || typingIds.isNotEmpty;
  bool get canChat;
  bool get demoMode;
  bool get supportsMentions;
  String get title;
  String? get characterId => null;
  bool get isPrivate => characterId != null;

  Future<void> sendUser(String text, {String? replyToId});
  Future<void> stop();
  void onUserActive() {}
  Future<void> retry(ChatMessage message) async {}
  Future<void> clear();

  /// 用户发一张表情包。默认实现只把消息放进列表；群聊/私聊会覆盖它，
  /// 让角色对表情包做出反应。
  Future<void> sendSticker(String asset) async {
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'user',
      text: '',
      sticker: asset,
      kind: MessageKind.sticker,
    ));
    onUserActive();
    notifyListeners();
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${rng.nextInt(9999)}';

  ChatMessage? messageById(String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? quoteFor(String? id) {
    final m = messageById(id);
    if (m == null) return null;
    final who = m.isUser
        ? '你'
        : m.isSystem
            ? '营地'
            : characterName(m.senderId);
    final text = m.text.trim();
    return '$who：${text.length > 60 ? '${text.substring(0, 60)}…' : text}';
  }

  String characterName(String id) {
    // 走 characterById，这样角色设定里改过的名字/称呼也会同步到所有界面。
    return characterById(id)?.name ?? id;
  }

  @protected
  void cancelRequested() {
    stopRequested = true;
    typingIds.clear();
    notifyListeners();
  }

  @protected
  void beginRequest() {
    stopRequested = false;
  }

  @override
  void dispose() {
    stopRequested = true;
    typingIds.clear();
    super.dispose();
  }
}

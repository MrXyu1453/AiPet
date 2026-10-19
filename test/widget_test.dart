import 'package:flutter_test/flutter_test.dart';

import 'package:aining_app/data/characters.dart';
import 'package:aining_app/models/models.dart';

void main() {
  test('五个 AI 娘，id 唯一且都有头像/表情包/乐器', () {
    expect(kCharacters.length, 5);
    expect(kCharacters.map((c) => c.id).toSet().length, 5);
    for (final c in kCharacters) {
      expect(c.avatarAsset, isNotEmpty);
      expect(c.stickerAsset, isNotEmpty);
      expect(c.instrument, isNotEmpty);
    }
  });

  test('消息 JSON 往返（含心情与表情包）', () {
    final m = ChatMessage(
      id: '1',
      time: DateTime.now(),
      senderId: 'dafeiyu',
      text: '才不是吃白饭的！',
      mood: '傲娇',
      sticker: 'assets/stickers/dafeiyu.png',
    );
    final j = ChatMessage.fromJson(m.toJson());
    expect(j.senderId, 'dafeiyu');
    expect(j.text, m.text);
    expect(j.mood, '傲娇');
    expect(j.sticker, m.sticker);
  });

  test('旧版消息（无 mood/sticker 字段）可恢复', () {
    final j = ChatMessage.fromJson({
      'id': '1',
      'time': DateTime.now().toIso8601String(),
      'senderId': 'user',
      'text': 'hi',
    });
    expect(j.mood, isNull);
    expect(j.sticker, isNull);
  });
}

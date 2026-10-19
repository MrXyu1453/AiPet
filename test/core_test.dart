import 'package:flutter_test/flutter_test.dart';

import 'package:aining_app/core/api_client.dart';
import 'package:aining_app/core/camp_state.dart';
import 'package:aining_app/core/director.dart';
import 'package:aining_app/core/prompts.dart';
import 'package:aining_app/data/characters.dart';
import 'package:aining_app/data/events.dart';
import 'package:aining_app/models/models.dart';

void main() {
  group('Base URL 归一化', () {
    test('根地址自动补 /v1/chat/completions', () {
      expect(ApiClient.normalizeEndpoint('https://api.deepseek.com').toString(),
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('已带 /v1 不重复', () {
      expect(
          ApiClient.normalizeEndpoint('https://api.openai.com/v1').toString(),
          'https://api.openai.com/v1/chat/completions');
      expect(
          ApiClient.normalizeEndpoint('https://api.openai.com/v1/').toString(),
          'https://api.openai.com/v1/chat/completions');
    });

    test('完整 endpoint 保持原样', () {
      expect(
          ApiClient.normalizeEndpoint(
                  'https://host.example/v1/chat/completions')
              .toString(),
          'https://host.example/v1/chat/completions');
    });

    test('没有 scheme 时补 https', () {
      expect(ApiClient.normalizeEndpoint('api.deepseek.com').toString(),
          'https://api.deepseek.com/v1/chat/completions');
    });
  });

  group('回复解析', () {
    test('心情 + 动作 + 正文', () {
      final p = parseReply('[心情:傲娇][动作:甩尾巴] 哼，才不是为你做的。', characterName: '大肥鱼');
      expect(p.mood, '傲娇');
      expect(p.actions, ['甩尾巴']);
      expect(p.body, '哼，才不是为你做的。');
    });

    test('全角括号与别名', () {
      final p = parseReply('【心情：高兴】今天也还行吧。');
      expect(p.mood, '开心');
      expect(p.body, '今天也还行吧。');
    });

    test('没有标签时从文本推断', () {
      final p = parseReply('哼，笨蛋，才不告诉你。');
      expect(p.mood, '傲娇');
    });

    test('去掉模型自带的名字前缀和引号', () {
      final p = parseReply('[心情:平静] Claude酱：“请坐。”', characterName: 'Claude酱');
      expect(p.body, '请坐。');
    });
  });

  group('情绪与好感', () {
    test('情绪随时间衰减到平静', () {
      final now = DateTime(2026, 10, 19, 23);
      final e = EmotionState(mood: '害羞', intensity: 1, updatedAt: now);
      expect(e.decayed(now.add(const Duration(minutes: 1))).intensity,
          lessThan(1));
      expect(e.decayed(now.add(const Duration(hours: 2))).mood, kNeutralMood);
    });

    test('好感有每日上限', () {
      final now = DateTime(2026, 10, 19, 23);
      final a = AffinityState.initial(now).gain(20, now);
      expect(a.value, 22);
      expect(a.todayGain, 14);
      final b = a.gain(20, now);
      expect(b.value, 22);
    });

    test('跨天重置今日增长', () {
      final now = DateTime(2026, 10, 19, 23);
      final a = AffinityState.initial(now).gain(10, now);
      final next = a.normalized(now.add(const Duration(days: 1)));
      expect(next.todayGain, 0);
      expect(next.value, a.value);
    });
  });

  group('记忆与事件', () {
    test('从用户输入抽取事实', () {
      final camp = CampState();
      final item = camp.rememberFromUserText('我叫小鱼，我最喜欢饭团。');
      expect(item, isNotNull);
      expect(camp.memories.any((m) => m.text.contains('小鱼')), isTrue);
    });

    test('每天的事件是稳定且存在的', () {
      final day = DateTime(2026, 10, 19);
      final e1 = eventForDay(day);
      final e2 = eventForDay(day.add(const Duration(hours: 3)));
      expect(e1.id, e2.id);
      expect(kCampEvents.any((e) => e.id == e1.id), isTrue);
      expect(e1.choices.length, greaterThanOrEqualTo(2));
    });

    test('角色数据完整', () {
      expect(kCharacters.length, 5);
      for (final c in kCharacters) {
        expect(c.likes, isNotEmpty);
        expect(c.avatarAsset.endsWith('_face.png'), isTrue);
        expect(c.stickerAsset.endsWith('.png'), isTrue);
      }
    });
  });

  group('导演', () {
    test('@ 优先', () {
      final camp = CampState();
      final director = Director(camp);
      final picks = director.pickResponders(
        userText: '@Grok娘 你怎么看？',
        history: const [],
      );
      expect(picks.first, 'grok');
    });

    test('至少选一个人', () {
      final director = Director(CampState());
      final picks = director.pickResponders(
        userText: '今晚谁最会干饭？',
        history: const [],
      );
      expect(picks, isNotEmpty);
      expect(picks.length, lessThanOrEqualTo(2));
    });
  });
}

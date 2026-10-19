import 'package:flutter_test/flutter_test.dart';

import 'package:aining_app/core/prompts.dart';
import 'package:aining_app/core/scenes.dart';
import 'package:aining_app/data/characters.dart';
import 'package:aining_app/models/models.dart';

void main() {
  tearDown(() => applyPersonaOverrides(const {}));

  group('场景', () {
    test('场景 id 唯一、文案与资源完整', () {
      final ids = kScenes.map((s) => s.id).toSet();
      expect(ids.length, kScenes.length);
      for (final s in kScenes) {
        expect(s.name, isNotEmpty);
        expect(s.note, isNotEmpty);
        expect(s.asset, endsWith('.jpg'));
        expect(s.asset, 'assets/bg/${s.id}.jpg');
        expect(s.particles, isNotEmpty);
      }
      expect(sceneFor('not-a-scene').id, kScenes.first.id);
    });

    test('不同场景有不同的粒子与调色', () {
      expect(sceneFor('snow').particles, contains(SceneParticle.snow));
      expect(sceneFor('sakura').particles, contains(SceneParticle.petal));
      expect(sceneFor('rain').particles, contains(SceneParticle.rain));
      expect(sceneFor('aurora').aurora, isTrue);
      expect(sceneFor('campfire').gradeOpacity, 0);
      expect(sceneFor('hotspring').particles, contains(SceneParticle.steam));
      expect(sceneFor('maple').particles, contains(SceneParticle.leaf));
      expect(sceneFor('seaside').particles, contains(SceneParticle.bubble));
      expect(sceneFor('city').particles,
          containsAll([SceneParticle.rain, SceneParticle.sparkle]));
      expect(sceneFor('meadow').fire, isFalse);
      expect(sceneFor('halloween').particles, contains(SceneParticle.bat));
      expect(sceneFor('christmas').particles, contains(SceneParticle.snow));
      // 独立背景图时代：滤镜只做很淡的氛围色
      for (final s in kScenes) {
        expect(s.gradeOpacity, lessThanOrEqualTo(0.2));
      }
    });

    test('时间阶段覆盖一天且不重叠', () {
      final ids = <String>{};
      for (var h = 0; h < 24; h++) {
        ids.add(dayPhaseFor(DateTime(2026, 10, 19, h)).id);
      }
      expect(
          ids,
          containsAll([
            'dawn',
            'morning',
            'noon',
            'golden',
            'evening',
            'night',
            'late',
          ]));
      expect(dayPhaseFor(DateTime(2026, 10, 19, 23)).id, 'night');
      expect(dayPhaseFor(DateTime(2026, 10, 19, 3)).id, 'late');
    });
  });

  group('角色二创', () {
    test('补充项叠加，不覆盖官方人设', () {
      final base = characterById('claude')!;
      applyPersonaOverrides({
        'claude': const PersonaOverride(
          name: '克劳德',
          addressAs: '大小姐',
          personalityAdd: '其实怕黑，雨夜会把椅子挪近火堆。',
          extraLikes: ['雨声'],
          ttsPitch: 1.12,
        ),
      });
      final c = characterById('claude')!;
      expect(c.name, '克劳德');
      expect(c.addressAs, '大小姐');
      expect(c.personality, contains(base.personality));
      expect(c.personality, contains('怕黑'));
      expect(c.likes, containsAll([...base.likes, '雨声']));
      expect(c.ttsPitch, closeTo(1.12, 0.001));
      // 没有改的角色不受影响
      expect(characterById('gpt')!.name, 'GPT娘');
      expect(resolvedCharacters.length, kCharacters.length);
    });

    test('空覆盖不会改变角色', () {
      final before = characterById('grok')!.personality;
      applyPersonaOverrides({'grok': const PersonaOverride(name: '   ')});
      expect(characterById('grok')!.personality, before);
      expect(characterById('grok')!.name, 'Grok娘');
    });

    test('提示词会带上秘密、称呼、关系网和场景', () {
      applyPersonaOverrides({
        'dafeiyu': const PersonaOverride(addressAs: '小鱼干'),
      });
      final c = characterById('dafeiyu')!;
      final prompt = PromptBuilder.systemFor(
        c,
        nickname: '主人',
        campContext: '【营地状态】夜里',
        roster: '大肥鱼 / Claude酱',
        privateMode: false,
        extraScene: sceneFor('snow').note,
      );
      expect(prompt, contains('小鱼干'));
      expect(prompt, contains(c.secret));
      expect(prompt, contains('雪'));
      expect(prompt, contains('关系网'));
    });
  });
}

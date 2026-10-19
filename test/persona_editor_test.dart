import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aining_app/data/characters.dart';
import 'package:aining_app/data/personas.dart';
import 'package:aining_app/features/persona/persona_editor_screen.dart';
import 'package:aining_app/models/models.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonaStore.instance.load();
    await PersonaStore.instance.resetAll();
  });

  tearDown(() async {
    await PersonaStore.instance.resetAll();
    applyPersonaOverrides(const {});
  });

  testWidgets('编辑名字/称呼并保存后，characterById 立即生效', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    final base = characterById('dafeiyu')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonaEditorScreen(character: base),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.at(0), 'Luna');
    await tester.enterText(fields.at(2), 'captain');
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'Luna');
    expect(tester.widget<TextField>(fields.at(2)).controller?.text, 'captain');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(PersonaStore.instance.overrideFor('dafeiyu').name, 'Luna');

    final updated = characterById('dafeiyu')!;
    expect(updated.name, 'Luna');
    expect(updated.addressAs, 'captain');
    expect(updated.personality, contains(base.personality));
    expect(PersonaStore.instance.hasOverride('dafeiyu'), isTrue);

    applyPersonaOverrides(const {});
    await tester.binding.setSurfaceSize(null);
  });

  test('角色设定卡可序列化为 Character Card V2 结构', () {
    applyPersonaOverrides({
      'claude': const PersonaOverride(
        name: '克劳德',
        personalityAdd: '怕黑。',
      ),
    });
    final json = PersonaStore.instance.buildCardsJson();
    expect(json, contains('chara_card_v2'));
    expect(json, contains('character_id'));
    expect(json, contains('克劳德'));
    expect(json, contains('"spec_version": "2.0"'));
  });

  test('可导入单张 Character Card V2', () async {
    final card = jsonEncode({
      'spec': 'chara_card_v2',
      'spec_version': '2.0',
      'data': {
        'name': 'Grok娘',
        'description': '喜欢在深夜讲冷笑话。',
        'personality': '句尾偶尔带一声“笑死”。',
        'scenario': '在天台看城市灯。',
      },
    });
    final result = await PersonaStore.instance.importJson(card);
    expect(result.imported, 1);
    final grok = characterById('grok')!;
    expect(grok.personality, contains('冷笑话'));
    expect(grok.speakingStyle, contains('笑死'));
    expect(grok.relationships, contains('天台'));
  });
}

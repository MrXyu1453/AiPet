import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aining_app/data/characters.dart';
import 'package:aining_app/features/portrait/character_portrait.dart';

void main() {
  testWidgets('半身像 fallback 在 122x148 可构建', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CharacterPortrait(
              character: kCharacters.first,
              mood: '害羞',
              width: 122,
              height: 148,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.byType(CharacterPortrait), findsOneWidget);
  });

  testWidgets('Claude 有闭眼/得意状态时不崩溃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CharacterPortrait(
              character: kCharacters[1],
              mood: '傲娇',
              talking: true,
              width: 122,
              height: 148,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });
}

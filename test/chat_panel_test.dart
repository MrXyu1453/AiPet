import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aining_app/core/camp_state.dart';
import 'package:aining_app/core/theme.dart';
import 'package:aining_app/features/chat/chat_panel.dart';
import 'package:aining_app/features/chat/widgets.dart';
import 'package:aining_app/data/characters.dart';
import 'package:aining_app/models/models.dart';
import 'package:aining_app/state/chat_session.dart';
import 'package:aining_app/state/settings_controller.dart';

class _FakeSession extends ChatSession {
  @override
  bool get canChat => true;
  @override
  bool get demoMode => false;
  @override
  bool get supportsMentions => true;
  @override
  String get title => '测试夜话';

  @override
  Future<void> sendUser(String text, {String? replyToId}) async {
    messages.add(ChatMessage(
      id: newId(),
      time: DateTime.now(),
      senderId: 'user',
      text: text,
      replyToId: replyToId,
    ));
    notifyListeners();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> retry(ChatMessage message) async {}

  @override
  Future<void> clear() async {
    messages.clear();
    notifyListeners();
  }
}

Widget _wrap(SettingsController settings, CampState camp, ChatSession session) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: camp),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: ChatPanel(session: session)),
    ),
  );
}

void main() {
  testWidgets('群聊面板在 360x800 下不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    final camp = CampState();
    final session = _FakeSession();
    session.messages.addAll([
      ChatMessage(
        id: '1',
        time: DateTime.now().subtract(const Duration(minutes: 3)),
        senderId: 'system',
        text: '篝火点起来了。',
      ),
      ChatMessage(
        id: '2',
        time: DateTime.now().subtract(const Duration(minutes: 2)),
        senderId: 'user',
        text: '今晚谁最会干饭？',
      ),
      ChatMessage(
        id: '3',
        time: DateTime.now(),
        senderId: kCharacters.first.id,
        text: '呜…才不是在等你说话！只是碗空了。',
        mood: '傲娇',
        actions: const ['甩尾巴'],
      ),
    ]);
    await tester.pumpWidget(_wrap(settings, camp, session));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(MessageTile), findsNWidgets(3));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('320x640 小屏也不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    final camp = CampState();
    final session = _FakeSession();
    session.messages.add(ChatMessage(
      id: '1',
      time: DateTime.now(),
      senderId: kCharacters[1].id,
      text: '守则第一条：这个我不能答应，但理由可以说三点。',
      mood: '平静',
    ));
    await tester.pumpWidget(_wrap(settings, camp, session));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}

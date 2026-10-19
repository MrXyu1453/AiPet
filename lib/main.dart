import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio_service.dart';
import 'core/camp_state.dart';
import 'core/live2d_cache.dart';
import 'core/theme.dart';
import 'core/voice_service.dart';
import 'data/personas.dart';
import 'features/chat/campfire_screen.dart';
import 'features/settings/onboarding_screen.dart';
import 'state/chat_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final settings = SettingsController();
  await settings.load();
  await PersonaStore.instance.load();
  final camp = CampState();
  await camp.load();
  final audio = AudioService(settings);
  final voice = VoiceService(settings);
  final chat = ChatController(
    settings: settings,
    camp: camp,
    audio: audio,
    voice: voice,
  );

  runApp(AiningApp(
    settings: settings,
    camp: camp,
    chat: chat,
    audio: audio,
    voice: voice,
  ));
  // 首帧之后再解包 Live2D 资源，避免拖慢启动；私聊打开时通常已经就绪。
  unawaited(prewarmLive2DModels());
}

class AiningApp extends StatelessWidget {
  final SettingsController settings;
  final CampState camp;
  final ChatController chat;
  final AudioService audio;
  final VoiceService voice;

  const AiningApp({
    super.key,
    required this.settings,
    required this.camp,
    required this.chat,
    required this.audio,
    required this.voice,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: PersonaStore.instance),
        ChangeNotifierProvider.value(value: camp),
        ChangeNotifierProvider.value(value: chat),
        ChangeNotifierProvider.value(value: voice),
        Provider<AudioService>.value(value: audio),
      ],
      child: MaterialApp(
        title: 'AI娘篝火营地',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) {
          final s = context.watch<SettingsController>();
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(s.fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    if (!settings.onboardingDone) {
      return const OnboardingScreen();
    }
    return const CampfireScreen();
  }
}

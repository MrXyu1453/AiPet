import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio_service.dart';
import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../core/voice_service.dart';
import '../../models/models.dart';
import '../../state/private_chat_controller.dart';
import '../../state/settings_controller.dart';
import '../chat/chat_panel.dart';
import '../chat/widgets.dart';
import '../portrait/character_portrait.dart';
import 'live2d_stage.dart';

class PrivateChatScreen extends StatefulWidget {
  final Character character;

  const PrivateChatScreen({super.key, required this.character});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  late final PrivateChatSession _session;
  bool _showStage = true;

  @override
  void initState() {
    super.initState();
    _session = PrivateChatSession(
      settings: context.read<SettingsController>(),
      camp: context.read<CampState>(),
      audio: context.read<AudioService>(),
      voice: context.read<VoiceService>(),
      character: widget.character,
    );
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camp = context.watch<CampState>();
    final voice = context.watch<VoiceService>();
    final settings = context.watch<SettingsController>();
    final c = widget.character;
    final accent = Color(c.accentColor);
    final emotion = camp.emotionFor(c.id);
    final aff = camp.affinityFor(c.id);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final normalStageHeight =
        (MediaQuery.sizeOf(context).height * 0.46).clamp(260.0, 460.0);
    // 键盘弹出时不销毁舞台，只把它缩成一条小预览；平台视图/模型一直
    // 留在树里，关掉键盘后立刻恢复，不会重新加载。
    final stageHeight = keyboard ? 132.0 : normalStageHeight;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            ListenableBuilder(
              // 私聊会话是单独的 ChangeNotifier，不在 Provider 里；只让
              // 头部和舞台跟着它重建，聊天列表自己监听，避免每条流式
              // 片段都把整个页面重建一遍。
              listenable: _session,
              builder: (context, _) {
                final typing = _session.typingIds.contains(c.id);
                final talking = typing || voice.speakingId == c.id;
                final thinking = _session.running && !typing;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context, c, accent, emotion, aff, talking),
                    if (_showStage)
                      SizedBox(
                        height: stageHeight,
                        child: Live2DPortraitStage(
                          key: ValueKey('stage_${c.id}'),
                          character: c,
                          mood: emotion.mood,
                          height: stageHeight,
                          talking: talking,
                          thinking: thinking,
                          voiceSpeaking: voice.speakingId == c.id,
                          spriteStyle: settings.spriteStyle,
                          onCollapse: () => setState(() => _showStage = false),
                          onPoke: _stagePoke,
                          onSurprise: _stageSurprise,
                        ),
                      ),
                    if (!_showStage && !keyboard) _collapsedStageBar(c, accent),
                  ],
                );
              },
            ),
            Expanded(child: ChatPanel(session: _session, compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Character c,
    Color accent,
    EmotionState emotion,
    AffinityState aff,
    bool talking,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(c.color).withValues(alpha: 0.3),
            AppColors.bg,
          ],
        ),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          CharacterPortrait(
            character: c,
            width: 42,
            height: 54,
            framed: false,
            mood: emotion.mood,
            talking: talking,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    MoodBadge(
                        mood: emotion.isNeutral ? null : emotion.mood,
                        accent: accent,
                        compact: true),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${aff.tier} · ${aff.value}/100',
                        style: TextStyle(fontSize: 10.5, color: accent)),
                    const SizedBox(width: 8),
                    const Text('🔒 只有你们两个人',
                        style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            color: AppColors.surface,
            onSelected: (value) async {
              if (value == 'clear') {
                await _session.clear();
              } else if (value == 'export') {
                final messenger = ScaffoldMessenger.of(context);
                final path = await _session.exportChat();
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('已导出到：$path')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('导出这段私聊')),
              PopupMenuItem(value: 'clear', child: Text('清空这段私聊')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collapsedStageBar(Character c, Color accent) {
    return InkWell(
      onTap: () => setState(() => _showStage = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        color: const Color(0xFF10141C),
        child: Row(
          children: [
            Icon(Icons.accessibility_new_rounded, size: 15, color: accent),
            const SizedBox(width: 7),
            Text(
              '${c.name} 的全身像已收起',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const Spacer(),
            Text('展开',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
          ],
        ),
      ),
    );
  }

  void _stagePoke(PokeZone zone) {
    final audio = context.read<AudioService>();
    audio.playSfx(zone == PokeZone.head ? Sfx.heart : Sfx.tap);
  }

  void _stageSurprise() {
    context.read<AudioService>().playSfx(Sfx.sparkle);
  }
}

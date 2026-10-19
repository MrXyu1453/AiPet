import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/scenes.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../state/settings_controller.dart';
import '../chat/widgets.dart';
import '../scenes/scene_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  int _index = 0;
  bool _showKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    _baseUrl.text = s.baseUrl;
    _apiKey.text = s.apiKey;
    _model.text = s.model;
  }

  @override
  void dispose() {
    _page.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < 2) {
      await _page.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
      return;
    }
    await _finish();
  }

  Future<void> _skip() async {
    final s = context.read<SettingsController>();
    await s.setDemoMode(true);
    await s.setOnboardingDone(true);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final s = context.read<SettingsController>();
    if (_apiKey.text.trim().isNotEmpty) {
      await s.saveConnection(
        baseUrl: _baseUrl.text,
        apiKey: _apiKey.text,
        model: _model.text,
      );
      await s.setDemoMode(false);
    } else {
      await s.setDemoMode(true);
    }
    await s.setOnboardingDone(true);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text('先逛逛',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _Welcome(),
                  _Connect(
                    baseUrl: _baseUrl,
                    apiKey: _apiKey,
                    model: _model,
                    showKey: _showKey,
                    onToggleKey: () => setState(() => _showKey = !_showKey),
                  ),
                  const _Meet(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.ember : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _next,
                  child: Text(
                    _index == 2 ? '点火，开始第 1 夜' : '下一步',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 10),
      children: [
        const SizedBox(height: 24),
        const Center(child: Text('🏕️', style: TextStyle(fontSize: 66))),
        const SizedBox(height: 18),
        const Center(
          child: Text('AI娘篝火营地',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('五个有脾气的 AI 娘，围着同一堆火',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ),
        const SizedBox(height: 24),
        const Text('今晚想在哪里点火？',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kScenes.take(4).length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              final scene = kScenes[i];
              return SizedBox(
                width: 142,
                child: SceneThumb(
                  scene: scene,
                  selected: settings.scene.id == scene.id,
                  onTap: () => settings.setScene(scene.id),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        for (final item in const [
          ('🔥', '她们会自己聊', '导演选人、互相拆台、主动挑话题，不是排队回答的客服。'),
          ('💗', '情绪与好感会长', '心情会衰减，好感会累积；今天说的话，明天她还记得。'),
          ('🎭', '点一下有反应', '摸头、戳脸、碰尾巴、长按抱抱，立绘会动、会脸红、会生气。'),
          ('🌙', '每晚都不一样', '流星、湿柴、偷饭团、真心话，随机事件把夜谈串起来。'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(item.$3,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Connect extends StatelessWidget {
  final TextEditingController baseUrl;
  final TextEditingController apiKey;
  final TextEditingController model;
  final bool showKey;
  final VoidCallback onToggleKey;

  const _Connect({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.showKey,
    required this.onToggleKey,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      children: [
        const SizedBox(height: 6),
        const Text('接上模型',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('填一个 OpenAI 兼容的 Key，她们就会真的开口。\n不想填也可以“先逛逛”，用本地试玩台词。',
            style:
                TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted)),
        const SizedBox(height: 18),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: baseUrl,
          builder: (context, value, _) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in kLlmPresets.where((p) => p.baseUrl.isNotEmpty))
                ChoiceChip(
                  label: Text(p.name, style: const TextStyle(fontSize: 11.5)),
                  selected: value.text == p.baseUrl,
                  onSelected: (_) {
                    baseUrl.text = p.baseUrl;
                    model.text = p.model;
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: baseUrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            hintText: 'https://api.deepseek.com',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: apiKey,
          obscureText: !showKey,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: 'sk-…',
            suffixIcon: IconButton(
              onPressed: onToggleKey,
              icon: Icon(
                  showKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18),
              color: AppColors.dim,
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: model,
          decoration: const InputDecoration(
            labelText: '模型名',
            hintText: 'deepseek-chat',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.dim),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Key 只存在本机；聊天内容会发给你填的服务商。',
                style: TextStyle(fontSize: 10, color: AppColors.dim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Text('🪄', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '不会填？先跳过。试玩模式里五个人也会动、会吃醋、会记得你送过什么。',
                  style: TextStyle(
                      fontSize: 11, height: 1.5, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('当前：${settings.apiKey.isNotEmpty ? '已保存 Key' : '还没有 Key'}',
            style: const TextStyle(fontSize: 10, color: AppColors.dim)),
      ],
    );
  }
}

class _Meet extends StatelessWidget {
  const _Meet();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
      children: [
        const Text('认识一下',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('点立绘互动，长按抱抱，点头像看档案。',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 16),
        for (final c in resolvedCharacters)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AvatarDot(character: c, size: 46, ring: true),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(c.title,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                Text(c.instrument, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '长按聊天消息可以引用、复制、记进记忆册；\n'
          '右上角相机可以把这一幕存成合影。',
          style: TextStyle(fontSize: 10.5, height: 1.7, color: AppColors.dim),
        ),
      ],
    );
  }
}

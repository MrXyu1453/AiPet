import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/camp_state.dart';
import '../../core/scenes.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../data/personas.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../chat/widgets.dart';
import '../memory/memory_book_screen.dart';
import '../persona/persona_editor_screen.dart';
import '../scenes/scene_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _nickname;
  bool _showKey = false;
  bool _testing = false;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    _baseUrl = TextEditingController(text: s.baseUrl);
    _apiKey = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    _nickname = TextEditingController(text: s.nickname);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _saveConnection() async {
    final settings = context.read<SettingsController>();
    await settings.saveConnection(
      baseUrl: _baseUrl.text,
      apiKey: _apiKey.text,
      model: _model.text,
    );
    if (!mounted) return;
    _toast('连接设置已保存');
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = '';
    });
    try {
      final api = ApiClient(LlmConfig(
        baseUrl: _baseUrl.text,
        apiKey: _apiKey.text,
        model: _model.text,
      ));
      final reply = await api.chat(
        const [ChatTurn('user', '回复“篝火点起来了”六个字的任意二次元变体。')],
        maxTokens: 30,
        timeout: const Duration(seconds: 30),
        retries: 0,
      );
      if (!mounted) return;
      setState(() => _testResult = '✓ $reply');
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '✗ ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '✗ $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final camp = context.watch<CampState>();
    final persona = context.watch<PersonaStore>();
    final chat = context.read<ChatController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            tooltip: '保存连接',
            onPressed: _saveConnection,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const _SectionHeader('模型连接', subtitle: 'OpenAI 兼容接口都可以'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in kLlmPresets)
                ChoiceChip(
                  label: Text(p.name, style: const TextStyle(fontSize: 11.5)),
                  selected:
                      settings.baseUrl == p.baseUrl && (p.baseUrl.isNotEmpty),
                  onSelected: (_) {
                    setState(() {
                      _baseUrl.text = p.baseUrl;
                      if (p.model.isNotEmpty) _model.text = p.model;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com',
              helperText: '填服务商根地址或 /v1 都可以，会自动归一化',
              helperStyle: TextStyle(fontSize: 10, color: AppColors.dim),
            ),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKey,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(
                    _showKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18),
                color: AppColors.dim,
              ),
            ),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: 'deepseek-chat',
              helperText: '每个角色可以在下面单独覆盖模型',
              helperStyle: TextStyle(fontSize: 10, color: AppColors.dim),
            ),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bolt_outlined, size: 16),
                label: const Text('测试连接', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _testResult,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: _testResult.startsWith('✓')
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveConnection,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: const Text('保存连接设置'),
            ),
          ),
          const SizedBox(height: 26),
          const _SectionHeader('场景与氛围',
              subtitle: '换个地方点火；场景会写进提示词，她们真的会“看见”雪或极光'),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kScenes.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final scene = kScenes[i];
                return SizedBox(
                  width: 146,
                  child: SceneThumb(
                    scene: scene,
                    selected: settings.scene.id == scene.id,
                    onTap: () => settings.setScene(scene.id),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showSceneSheet(context),
              icon: const Icon(Icons.grid_view_rounded, size: 15),
              label: const Text('全部场景', style: TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.emberSoft,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.atmosphereEnabled,
            onChanged: settings.setAtmosphere,
            title: const Text('氛围粒子', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('雪、花瓣、雨、萤火、天灯；低配设备可关',
                style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            activeThumbColor: AppColors.ember,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.followTime,
            onChanged: settings.setFollowTime,
            title: const Text('光线随时间变化', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('破晓、黄昏、深夜会叠一层很淡的时间色',
                style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            activeThumbColor: AppColors.ember,
          ),
          const SizedBox(height: 20),
          const _SectionHeader('角色专属模型',
              subtitle: '可选：让 Grok 由 Grok 演、Claude 由 Claude 演'),
          for (final c in resolvedCharacters)
            _CharacterModelTile(character: c, settings: settings),
          const SizedBox(height: 26),
          const _SectionHeader('角色设定', subtitle: '给她们补充人设、改称呼、调声线；保存后下一句对话生效'),
          for (final c in resolvedCharacters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AvatarDot(character: c, size: 34, ring: true),
              title: Row(
                children: [
                  Flexible(
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  if (persona.hasOverride(c.id)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.ember.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('已二创',
                          style: TextStyle(
                              fontSize: 8.5, color: AppColors.emberSoft)),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '称呼你：${c.addressAs.trim().isEmpty ? settings.nickname : c.addressAs}'
                ' · 声线 ${c.ttsPitch.toStringAsFixed(2)}/${c.ttsRate.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, color: AppColors.dim),
              ),
              trailing: const Icon(Icons.edit_outlined,
                  size: 17, color: AppColors.dim),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonaEditorScreen(character: c),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const _SectionHeader('体验'),
          TextField(
            controller: _nickname,
            decoration: InputDecoration(
              labelText: '她怎么称呼你',
              hintText: '鱼片',
              suffixIcon: IconButton(
                onPressed: () async {
                  await settings.setNickname(_nickname.text);
                  if (mounted) _toast('称呼已保存');
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                color: AppColors.dim,
              ),
            ),
            onSubmitted: (v) => settings.setNickname(v),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          _SettingTile(
            title: '立绘风格',
            subtitle: '官方全身立绘 / Q版小人',
            child: _Segmented(
              values: const [
                ('official', '官方'),
                ('chibi', 'Q版'),
              ],
              selected: settings.spriteStyle,
              onChanged: settings.setSpriteStyle,
            ),
          ),
          _SettingTile(
            title: '动态质量',
            subtitle: '低配设备可以调低，省电',
            child: _Segmented(
              values: const [
                ('low', '省电'),
                ('balanced', '均衡'),
                ('high', '流畅'),
              ],
              selected: settings.motionQuality,
              onChanged: settings.setMotionQuality,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.ttsEnabled,
            onChanged: settings.setTts,
            title: const Text('语音朗读', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('用系统中文 TTS，每个角色不同声线',
                style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            activeThumbColor: AppColors.ember,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.ambienceEnabled,
            onChanged: settings.setAmbience,
            title: const Text('篝火环境音', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('合成的柴火噼啪声，不联网',
                style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            activeThumbColor: AppColors.ember,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.demoMode,
            onChanged: settings.setDemoMode,
            title: const Text('试玩模式', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text('没有 API Key 时用本地台词，也能体验完整互动',
                style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            activeThumbColor: AppColors.ember,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('字号', style: TextStyle(fontSize: 13.5)),
              Expanded(
                child: Slider(
                  value: settings.fontScale,
                  min: 0.9,
                  max: 1.2,
                  divisions: 3,
                  activeColor: AppColors.ember,
                  label: '${(settings.fontScale * 100).round()}%',
                  onChanged: settings.setFontScale,
                ),
              ),
              Text('${(settings.fontScale * 100).round()}%',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
            ],
          ),
          const SizedBox(height: 26),
          const _SectionHeader('数据'),
          _DataTile(
            icon: Icons.menu_book_outlined,
            title: '打开记忆册（${camp.memories.length} 条）',
            subtitle: '她们记住的关于你的事',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemoryBookScreen()),
            ),
          ),
          _DataTile(
            icon: Icons.ios_share_rounded,
            title: '导出聊天记录',
            subtitle: '保存为 Markdown 到应用文档目录',
            onTap: () async {
              final path = await chat.exportChat();
              if (mounted) _toast('已导出：$path');
            },
          ),
          _DataTile(
            icon: Icons.delete_sweep_outlined,
            title: '清空群聊记录',
            subtitle: '好感、记忆、情绪都会保留',
            onTap: () async {
              final ok = await _confirm('清空群聊记录？', '只清空对话，不重置好感与记忆。');
              if (ok) {
                await chat.clear();
                if (mounted) _toast('群聊已清空');
              }
            },
          ),
          _DataTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: '清空所有私聊缓存',
            subtitle: '下次进入私聊时会从空白开始',
            onTap: () async {
              final ok = await _confirm('清空所有私聊？', '这段操作不可撤销，好感不会变。');
              if (!ok) return;
              final storage = ChatStorage();
              for (final c in resolvedCharacters) {
                await storage.clear(channel: 'private_${c.id}');
              }
              if (mounted) _toast('私聊缓存已清空');
            },
          ),
          _DataTile(
            icon: Icons.auto_stories_outlined,
            title: '清空记忆册（${camp.memories.length} 条）',
            subtitle: '她们会忘记你记住的事',
            onTap: () async {
              final ok = await _confirm('清空记忆册？', '这会让她们忘记所有被记住的事。');
              if (ok) {
                camp.clearMemories();
                if (mounted) _toast('记忆册已清空');
              }
            },
          ),
          _DataTile(
            icon: Icons.badge_outlined,
            title: '导出角色设定卡',
            subtitle: 'Character Card V2 JSON，可备份、改机、分享',
            onTap: () async {
              final path = await PersonaStore.instance.exportCards();
              if (mounted) _toast('已导出：$path');
            },
          ),
          _DataTile(
            icon: Icons.file_upload_outlined,
            title: '导入角色设定卡',
            subtitle: '粘贴 JSON；兼容本应用导出与 SillyTavern 角色卡',
            onTap: _importPersonas,
          ),
          _DataTile(
            icon: Icons.layers_clear_outlined,
            title: '清空角色二创',
            subtitle: '恢复五个人原本的人设，不影响好感与记忆',
            onTap: () async {
              final ok = await _confirm('清空角色二创？', '只会清掉你写的补充，聊天记录和好感都会保留。');
              if (!ok) return;
              await PersonaStore.instance.resetAll();
              if (mounted) _toast('角色二创已清空');
            },
          ),
          _DataTile(
            icon: Icons.restart_alt_rounded,
            title: '重新看一遍引导',
            subtitle: '回到第一次点火时的界面',
            onTap: () async {
              final nav = Navigator.of(context);
              await settings.resetOnboarding();
              if (mounted) nav.popUntil((r) => r.isFirst);
            },
          ),
          const SizedBox(height: 26),
          const _SectionHeader('关于'),
          const Text(
            'AI娘篝火营地 · 个人非商业项目\n'
            'v0.7 新增：可切换场景（调色 / 雪 / 樱花 / 雨 / 极光 / 天灯）、角色二创编辑器、'
            '关系网与小秘密、真心话大冒险、用户表情包与角色卡导入导出。\n'
            '立绘 / 头像：ZipZipPipe（胖次狐）AI娘设定图、whale-chan 社区，CC-BY-NC-SA。\n'
            '当前使用的是“单张立绘 + 程序化动作 + 表情 overlay”；Live2D / Rive 需要分层美术，'
            '接口已预留，详见 README 的渲染层说明。\n'
            '所有音频由 App 运行时合成，不含版权素材。',
            style: TextStyle(fontSize: 10.5, height: 1.7, color: AppColors.dim),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'AI娘篝火营地',
              applicationVersion: '0.7.0',
            ),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.emberSoft, padding: EdgeInsets.zero),
            child: const Text('开源许可与第三方组件', style: TextStyle(fontSize: 11.5)),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('v0.7.0 · 场景与人设',
                style: TextStyle(
                    fontSize: 10, color: AppColors.dim.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }

  Future<void> _importPersonas() async {
    var pasted = '';
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('导入角色设定卡', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: TextField(
              autofocus: true,
              onChanged: (v) => pasted = v,
              minLines: 5,
              maxLines: 10,
              style: const TextStyle(fontSize: 11.5),
              decoration: const InputDecoration(
                hintText: '把导出的 JSON 或 SillyTavern 角色卡粘贴到这里…',
                hintStyle: TextStyle(fontSize: 11, color: AppColors.dim),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pasted),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final result = await PersonaStore.instance.importJson(text);
    if (mounted) _toast(result.message);
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Text(body, style: const TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emberSoft)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
          ],
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: 1),
          Text(subtitle,
              style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _Segmented({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: selected == v.$1
                        ? AppColors.ember.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    v.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: selected == v.$1
                          ? AppColors.emberSoft
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterModelTile extends StatelessWidget {
  final Character character;
  final SettingsController settings;

  const _CharacterModelTile({required this.character, required this.settings});

  @override
  Widget build(BuildContext context) {
    final override = settings.characterModels[character.id] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _edit(context, override),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              AvatarDot(character: character, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name,
                        style: const TextStyle(fontSize: 12.5)),
                    Text(
                      override.isEmpty ? '跟随全局模型（${settings.model}）' : override,
                      style:
                          const TextStyle(fontSize: 10, color: AppColors.dim),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: AppColors.dim),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            Text('${character.name} 的模型', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '留空 = 跟随全局',
            helperText: '需要同一个 Base URL 支持这个模型',
            helperStyle: TextStyle(fontSize: 10, color: AppColors.dim),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value != null) {
      await settings.setCharacterModel(character.id, value);
    }
    controller.dispose();
  }
}

class _DataTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DataTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.muted),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 10, color: AppColors.dim)),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 18, color: AppColors.dim),
      onTap: onTap,
    );
  }
}

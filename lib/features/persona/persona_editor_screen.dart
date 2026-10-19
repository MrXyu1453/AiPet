import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/voice_service.dart';
import '../../data/characters.dart';
import '../../data/personas.dart';
import '../../models/models.dart';
import '../chat/widgets.dart';

/// 角色设定编辑器。
///
/// 所有字段都是“增量补充”，保存后会合并进人设并注入提示词；命名/称呼
/// 会同步到舞台、聊天气泡和群聊 @。不会改动立绘资源。
class PersonaEditorScreen extends StatefulWidget {
  final Character character;

  const PersonaEditorScreen({super.key, required this.character});

  @override
  State<PersonaEditorScreen> createState() => _PersonaEditorScreenState();
}

class _PersonaEditorScreenState extends State<PersonaEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _addressAs;
  late final TextEditingController _personality;
  late final TextEditingController _speaking;
  late final TextEditingController _relationship;
  late final TextEditingController _catchphrases;
  late final TextEditingController _likes;
  late final TextEditingController _dislikes;

  late double _pitch;
  late double _rate;
  bool _saving = false;

  Character get _official => kCharacters.firstWhere(
        (c) => c.id == widget.character.id,
        orElse: () => widget.character,
      );

  @override
  void initState() {
    super.initState();
    final base = widget.character;
    final o = PersonaStore.instance.overrideFor(base.id);
    _name = TextEditingController(text: o.name);
    _title = TextEditingController(text: o.title);
    _addressAs = TextEditingController(text: o.addressAs);
    _personality = TextEditingController(text: o.personalityAdd);
    _speaking = TextEditingController(text: o.speakingAdd);
    _relationship = TextEditingController(text: o.relationshipAdd);
    _catchphrases = TextEditingController(text: o.extraCatchphrases.join('\n'));
    _likes = TextEditingController(text: o.extraLikes.join('，'));
    _dislikes = TextEditingController(text: o.extraDislikes.join('，'));
    _pitch = o.ttsPitch ?? base.ttsPitch;
    _rate = o.ttsRate ?? base.ttsRate;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _title,
      _addressAs,
      _personality,
      _speaking,
      _relationship,
      _catchphrases,
      _likes,
      _dislikes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split(RegExp(r'[\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> _tokens(String raw) => raw
      .split(RegExp(r'[,，、\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  PersonaOverride _build() => PersonaOverride(
        name: _name.text.trim(),
        title: _title.text.trim(),
        addressAs: _addressAs.text.trim(),
        personalityAdd: _personality.text.trim(),
        speakingAdd: _speaking.text.trim(),
        relationshipAdd: _relationship.text.trim(),
        extraCatchphrases: _lines(_catchphrases.text),
        extraLikes: _tokens(_likes.text),
        extraDislikes: _tokens(_dislikes.text),
        ttsPitch: (_pitch - _official.ttsPitch).abs() < 0.001 ? null : _pitch,
        ttsRate: (_rate - _official.ttsRate).abs() < 0.001 ? null : _rate,
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    unawaited(HapticFeedback.lightImpact());
    await PersonaStore.instance.save(widget.character.id, _build());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('角色设定已保存，下一句就会生效')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('恢复默认人设？', style: TextStyle(fontSize: 16)),
        content: const Text('会清掉你为这个角色写下的全部补充，不会影响聊天记录和好感。',
            style: TextStyle(fontSize: 12.5, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (ok != true) return;
    await PersonaStore.instance.reset(widget.character.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _previewVoice() {
    final merged = characterById(widget.character.id) ?? widget.character;
    final voice = context.read<VoiceService>();
    voice.speak(
      merged.copyWith(ttsPitch: _pitch, ttsRate: _rate),
      '……主人，你听得到吗？这是我现在的声音。',
    );
  }

  @override
  Widget build(BuildContext context) {
    final merged = characterById(widget.character.id) ?? widget.character;
    final accent = Color(merged.accentColor);
    return Scaffold(
      appBar: AppBar(
        title: Text('${merged.name} · 角色设定'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: _saving ? null : _reset,
            icon: const Icon(Icons.restore_rounded),
          ),
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          Row(
            children: [
              AvatarDot(character: merged, size: 52, ring: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(merged.title,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      '留空 = 沿用官方设定；所有补充都会叠加，不会覆盖原人设。',
                      style: TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color: accent.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('基础'),
          _Field(
            controller: _name,
            label: '名字',
            hint: widget.character.name,
            helper: '留空用「${widget.character.name}」。改了会同步到舞台与聊天气泡。',
          ),
          _Field(
            controller: _title,
            label: '称号',
            hint: widget.character.title,
            maxLines: 2,
          ),
          _Field(
            controller: _addressAs,
            label: '她怎么称呼你',
            hint: widget.character.addressAs.isEmpty
                ? '留空则用设置里的昵称'
                : widget.character.addressAs,
            helper: '比如“鱼片”“队长”“喂”。会写进提示词。',
          ),
          const SizedBox(height: 8),
          const _SectionLabel('人设补充'),
          _Field(
            controller: _personality,
            label: '性格 / 过去 / 小习惯',
            hint: '例：其实怕黑，雨夜会偷偷把椅子挪近火堆；被夸会假装整理头发。',
            maxLines: 4,
          ),
          _Field(
            controller: _speaking,
            label: '说话方式补充',
            hint: '例：紧张时会重复对方最后一个词；偶尔冒出一句方言。',
            maxLines: 3,
          ),
          _Field(
            controller: _relationship,
            label: '关系补充',
            hint: '例：最近开始主动给 Grok 留咖啡，但嘴上说是“顺手”。',
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          const _SectionLabel('喜好与口癖'),
          _Field(
            controller: _catchphrases,
            label: '新增口头禅（每行一个）',
            hint: '例：\n这锅我不背。\n先让我闻闻。',
            maxLines: 4,
          ),
          _Field(
            controller: _likes,
            label: '新增喜欢的东西',
            hint: '用逗号分隔，例：烤棉花糖，旧唱片',
          ),
          _Field(
            controller: _dislikes,
            label: '新增讨厌的东西',
            hint: '用逗号分隔，例：被叫全名，冷掉的汤',
          ),
          const SizedBox(height: 8),
          const _SectionLabel('声音'),
          _VoiceSlider(
            label: '音高 pitch',
            value: _pitch,
            min: 0.7,
            max: 1.5,
            onChanged: (v) => setState(() => _pitch = v),
          ),
          _VoiceSlider(
            label: '语速 rate',
            value: _rate,
            min: 0.3,
            max: 0.7,
            onChanged: (v) => setState(() => _rate = v),
          ),
          OutlinedButton.icon(
            onPressed: _previewVoice,
            icon: const Icon(Icons.volume_up_outlined, size: 17),
            label: const Text('试听这句声音', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('她会这样看自己',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: accent)),
                const SizedBox(height: 6),
                Text(
                  merged.personality,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.55, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存设定'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.emberSoft)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.helper,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, height: 1.45),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.dim),
          helperText: helper,
          helperMaxLines: 2,
          helperStyle: const TextStyle(fontSize: 9.5, color: AppColors.dim),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class _VoiceSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _VoiceSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 16,
            activeColor: AppColors.ember,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 10, color: AppColors.dim)),
        ),
      ],
    );
  }
}

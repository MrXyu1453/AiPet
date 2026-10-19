import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../core/voice_service.dart';
import '../../data/characters.dart';
import '../../data/personas.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../memory/memory_book_screen.dart';
import '../persona/persona_editor_screen.dart';
import '../portrait/character_portrait.dart';
import '../private/private_chat_screen.dart';
import 'gift_sheet.dart';

Future<void> showCharacterProfile(BuildContext context, Character c) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => _ProfileSheet(character: c),
  );
}

class _ProfileSheet extends StatelessWidget {
  final Character character;

  const _ProfileSheet({required this.character});

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatController>();
    final camp = context.read<CampState>();
    final voice = context.watch<VoiceService>();
    return ListenableBuilder(
      listenable: Listenable.merge([chat, camp, PersonaStore.instance]),
      builder: (context, _) {
        final character = characterById(this.character.id) ?? this.character;
        final emotion = camp.emotionFor(character.id);
        final aff = camp.affinityFor(character.id);
        final memories = camp.memoriesFor(character.id, limit: 4);
        final accent = Color(character.accentColor);
        final talking = chat.typingIds.contains(character.id) ||
            voice.speakingId == character.id;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CharacterPortrait(
                      character: character,
                      width: 122,
                      height: 148,
                      mood: emotion.mood,
                      talking: talking,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(character.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(character.title,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (emotion.isNeutral)
                                const _Pill(
                                    text: '心情平静',
                                    emoji: '🙂',
                                    color: AppColors.muted)
                              else
                                _Pill(
                                  text: emotion.mood,
                                  emoji: emotion.emoji,
                                  color: accent,
                                ),
                              const _Pill(
                                  text: '乐队位',
                                  emoji: '♪',
                                  color: AppColors.muted),
                              if (chat.isPrivate)
                                const _Pill(
                                    text: '私聊中',
                                    emoji: '🔒',
                                    color: AppColors.ember),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '听听她的声音',
                      onPressed: () => voice.speak(
                        character,
                        '……主人，你听见火的声音了吗？',
                      ),
                      icon: const Icon(Icons.volume_up_outlined, size: 19),
                      color: accent.withValues(alpha: 0.85),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.dim,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _AffinityCard(character: character, aff: aff, accent: accent),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.pan_tool_alt_outlined,
                        label: '摸摸头',
                        onTap: () {
                          Navigator.pop(context);
                          chat.poke(character.id, zone: PokeZone.head);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cookie_outlined,
                        label: '投喂',
                        onTap: () {
                          final nav = Navigator.of(context);
                          Navigator.pop(context);
                          showGiftSheet(nav.context, target: character);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '单独聊聊',
                        primary: true,
                        onTap: () {
                          final nav = Navigator.of(context);
                          Navigator.pop(context);
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PrivateChatScreen(character: character),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.edit_note_rounded,
                        label: '设定',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PersonaEditorScreen(character: character),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (!emotion.isNeutral && emotion.reason != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '她现在的情绪：${emotion.mood}（${emotion.intensity.toStringAsFixed(2)}）'
                    ' · ${emotion.reason}',
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.dim),
                  ),
                ],
                const SizedBox(height: 22),
                _Section(
                  title: '性格',
                  child: Text(character.personality,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: AppColors.text)),
                ),
                _Section(
                  title: '说话方式',
                  child: Text(character.speakingStyle,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: AppColors.text)),
                ),
                _Section(
                  title: '她怎么看大家',
                  child: Text(character.relationships,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: AppColors.text)),
                ),
                if (character.bonds.isNotEmpty)
                  _Section(
                    title: '关系网',
                    child: _BondGrid(character: character),
                  ),
                _Section(
                  title: '口头禅',
                  child: Text(
                      character.catchphrases.map((e) => '「$e」').join('  '),
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.6, color: AppColors.muted)),
                ),
                if (character.secret.trim().isNotEmpty)
                  _Section(
                    title: '她不会主动说出口的事',
                    child: _SecretCard(secret: character.secret),
                  ),
                _Section(
                  title: '她记得的事',
                  child: memories.isEmpty
                      ? const Text('还没有。多聊几句，或者长按她的消息“记进记忆册”。',
                          style: TextStyle(
                              fontSize: 12, height: 1.5, color: AppColors.dim))
                      : Column(
                          children: [
                            for (final m in memories)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: Icon(Icons.circle,
                                          size: 4, color: AppColors.ember),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(m.text,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color: AppColors.muted)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                if (memories.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MemoryBookScreen(initialCharacter: character.id),
                        ),
                      ),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.emberSoft,
                          padding: EdgeInsets.zero),
                      child:
                          const Text('打开记忆册 →', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PersonaEditorScreen(character: character),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 17),
                    label:
                        const Text('编辑她的角色设定', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AffinityCard extends StatelessWidget {
  final Character character;
  final AffinityState aff;
  final Color accent;

  const _AffinityCard({
    required this.character,
    required this.aff,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(aff.tier,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent)),
              const SizedBox(width: 6),
              Text('Lv.${aff.level}',
                  style: const TextStyle(fontSize: 11, color: AppColors.dim)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${aff.value}/100',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                  Text('今日 +${aff.todayGain}/14',
                      style:
                          const TextStyle(fontSize: 8.5, color: AppColors.dim)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: aff.value / 100,
              minHeight: 6,
              backgroundColor: AppColors.bg,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            aff.value >= 85
                ? '她很少对谁这样。今晚的火光里，她看你的眼神不太一样。'
                : aff.value >= 60
                    ? '已经是能互相拆台的交情了。'
                    : aff.value >= 32
                        ? '她开始记得你说过的话。'
                        : aff.value >= 15
                            ? '比陌生人熟一点，但还是会嘴硬。'
                            : '她还在观察你。',
            style: const TextStyle(
                fontSize: 11, height: 1.4, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.ember : AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            children: [
              Icon(icon,
                  size: 19,
                  color: primary ? const Color(0xFF241606) : AppColors.text),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          primary ? const Color(0xFF241606) : AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emberSoft)),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final String emoji;
  final Color color;

  const _Pill({required this.text, required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        emoji.isEmpty ? text : '$emoji $text',
        style: TextStyle(fontSize: 10.5, color: color),
      ),
    );
  }
}

class _BondGrid extends StatelessWidget {
  final Character character;

  const _BondGrid({required this.character});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final entry in character.bonds.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  _OtherAvatar(id: entry.key),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 68,
                    child: Text(
                      characterById(entry.key)?.name ?? entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, height: 1.35, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OtherAvatar extends StatelessWidget {
  final String id;

  const _OtherAvatar({required this.id});

  @override
  Widget build(BuildContext context) {
    final c = characterById(id);
    if (c == null) return const SizedBox(width: 22, height: 22);
    return ClipOval(
      child: Image.asset(
        c.avatarAsset,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 22,
          height: 22,
          color: Color(c.color),
          alignment: Alignment.center,
          child: Text(c.initial,
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
      ),
    );
  }
}

class _SecretCard extends StatefulWidget {
  final String secret;

  const _SecretCard({required this.secret});

  @override
  State<_SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<_SecretCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_revealed) return;
        HapticFeedback.mediumImpact();
        setState(() => _revealed = true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (_revealed ? AppColors.ember : AppColors.surface3)
                  .withValues(alpha: _revealed ? 0.12 : 1),
              AppColors.surface2,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: (_revealed ? AppColors.ember : AppColors.border)
                .withValues(alpha: _revealed ? 0.4 : 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _revealed
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                  size: 14,
                  color: _revealed ? AppColors.ember : AppColors.dim,
                ),
                const SizedBox(width: 5),
                Text(
                  _revealed ? '偷看到了' : '点一下偷看',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _revealed ? AppColors.emberSoft : AppColors.dim),
                ),
              ],
            ),
            const SizedBox(height: 7),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _revealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const Text(
                '她把这件事藏在最下面那层。关系再近一点，也许会自己说出来。',
                style: TextStyle(
                    fontSize: 11.5, height: 1.5, color: AppColors.dim),
              ),
              secondChild: Text(
                widget.secret,
                style: const TextStyle(
                    fontSize: 12, height: 1.6, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

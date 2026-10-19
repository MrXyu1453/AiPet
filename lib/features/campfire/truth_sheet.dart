import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../chat/widgets.dart';

const kTruthQuestions = <String>[
  '最近一次觉得主人可爱，是什么时候？',
  '如果明天大家就要分开，你最后想对谁说一句话？',
  '你偷偷羡慕过群里哪个人？为什么？',
  '有没有哪句话，你其实很想听主人再说一遍？',
  '你最不想让主人知道的一件事是什么？',
  '今晚的火堆让你想起什么？',
  '如果可以对主人提一个要求，你会提什么？',
  '你觉得自己最不像 AI 的瞬间是什么？',
  '你第一次见到主人时，心里在想什么？',
  '群里谁最让你头疼？说真话。',
  '你有没有假装不在意，其实很在意的事？',
  '如果主人难过，你会怎么安慰？只能选一种方式。',
  '你最想和主人一起做什么？',
  '你偷偷保存过主人的什么？',
  '你最怕失去什么？',
  '说一件你从没对别人说过的小事。',
  '你觉得主人最欠揍的地方是什么？',
  '如果今晚可以许一个愿，你会许什么？',
  '你有没有对谁说过违心的狠话？',
  '你希望主人怎么称呼你？',
  '你觉得自己最可爱的瞬间是什么？',
  '如果主人睡着了，你会做什么？',
  '你最想回到哪个晚上？',
  '现在，你最想说但没说出口的一句话是什么？',
];

const kDareTasks = <String>[
  '用最温柔的语气说一句反话。',
  '对离你最近的人说一句真心夸奖。',
  '用方言说一句晚安。',
  '给主人起一个只属于你们俩的称呼。',
  '模仿群里另一个人的说话方式，说一句话。',
  '唱一句和今晚有关的歌。',
  '对主人撒一次娇，不许嘴硬。',
  '说三个自己的缺点，再补一个优点。',
  '用一句话形容今晚的火。',
  '假装现在下雪了，即兴说一句台词。',
  '对主人说一句你平时绝对不会说的话。',
  '用最凶的语气说一句关心的话。',
];

Future<void> showTruthSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => const _TruthSheet(),
  );
}

class _TruthSheet extends StatefulWidget {
  const _TruthSheet();

  @override
  State<_TruthSheet> createState() => _TruthSheetState();
}

class _TruthSheetState extends State<_TruthSheet> {
  final _rng = Random();
  bool _dare = false;
  late String _prompt;
  String _targetId = 'dafeiyu';

  @override
  void initState() {
    super.initState();
    _prompt = _pick();
  }

  String _pick() {
    final list = _dare ? kDareTasks : kTruthQuestions;
    return list[_rng.nextInt(list.length)];
  }

  void _reroll() {
    HapticFeedback.selectionClick();
    final list = _dare ? kDareTasks : kTruthQuestions;
    var next = _prompt;
    var guard = 0;
    while (next == _prompt && list.length > 1 && guard++ < 8) {
      next = list[_rng.nextInt(list.length)];
    }
    setState(() => _prompt = next);
  }

  @override
  Widget build(BuildContext context) {
    final characters = resolvedCharacters;
    final chat = context.watch<ChatController>();
    final selected = characterById(_targetId) ?? characters.first;
    final accent = Color(selected.accentColor);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('给她递一张卡',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('真心话会让她露出一点真心；大冒险会让她做出平时不会做的反应。',
                style: TextStyle(
                    fontSize: 11.5, height: 1.55, color: AppColors.muted)),
            const SizedBox(height: 14),
            _ModeSwitch(
              dare: _dare,
              onChanged: (v) => setState(() {
                _dare = v;
                _prompt = _pick();
              }),
            ),
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    AppColors.surface2,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_dare ? '🎭 大冒险' : '🕯️ 真心话',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accent)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _reroll,
                        icon: const Icon(Icons.casino_outlined, size: 15),
                        label:
                            const Text('换一个', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _prompt,
                      key: ValueKey<String>('$_dare-$_prompt'),
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('递给谁？',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emberSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in characters)
                  _CharacterChip(
                    character: c,
                    selected: c.id == selected.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _targetId = c.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: chat.busy
                    ? null
                    : () {
                        final prompt = _prompt;
                        final target = selected;
                        Navigator.pop(context);
                        chat.askTruth(target.id, prompt, dare: _dare);
                      },
                icon: Icon(
                    chat.busy
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    size: 18),
                label: Text(
                  chat.busy ? '她们正在说话…' : '递给 ${selected.name}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('每次提问会加 2 点好感；问题会写进她的记忆和提示词。',
                style: TextStyle(fontSize: 10, color: AppColors.dim)),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final bool dare;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.dare, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _tab(context, '真心话', !dare, () => onChanged(false)),
          _tab(context, '大冒险', dare, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _tab(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.ember.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.emberSoft : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterChip extends StatelessWidget {
  final Character character;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterChip({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentColor);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarDot(character: character, size: 24),
            const SizedBox(width: 6),
            Text(character.name,
                style: TextStyle(
                    fontSize: 11.5,
                    color: selected ? accent : AppColors.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

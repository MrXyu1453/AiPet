import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../state/chat_controller.dart';
import '../campfire/rhythm_game.dart';
import '../campfire/truth_sheet.dart';
import '../memory/memory_book_screen.dart';
import '../persona/persona_editor_screen.dart';
import '../profile/gift_sheet.dart';
import '../scenes/scene_sheet.dart';
import 'chat_sheet.dart';

Future<void> showQuickActions(
  BuildContext context, {
  required Future<void> Function() onTakePhoto,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetCtx) {
      final chat = context.read<ChatController>();
      void close() => Navigator.pop(sheetCtx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篝火边的互动',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            const Text('投喂、真心话、演唱会、合影，或者换个场景继续聊。',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                _ActionTile(
                  emoji: '🍙',
                  label: '投喂',
                  hint: '送她喜欢的东西',
                  onTap: () {
                    close();
                    showGiftSheet(context);
                  },
                ),
                _ActionTile(
                  emoji: '🕯️',
                  label: '真心话',
                  hint: '让她说点真心',
                  onTap: () {
                    close();
                    showTruthSheet(context);
                  },
                ),
                _ActionTile(
                  emoji: chat.concert ? '🎤' : '🎶',
                  label: chat.concert ? '散场' : '演唱会',
                  hint: chat.concert ? '结束今晚 LIVE' : '把火堆变舞台',
                  onTap: () {
                    close();
                    chat.toggleConcert();
                  },
                ),
                _ActionTile(
                  emoji: '🥁',
                  label: '节奏挑战',
                  hint: '五轨点按小游戏',
                  onTap: () async {
                    close();
                    final result = await showRhythmGame(context);
                    if (result != null && context.mounted) {
                      await context
                          .read<ChatController>()
                          .announceConcertResult(result.score, result.maxCombo);
                    }
                  },
                ),
                _ActionTile(
                  emoji: '📷',
                  label: '合影',
                  hint: '把这一幕存下来',
                  onTap: () async {
                    close();
                    await onTakePhoto();
                  },
                ),
                _ActionTile(
                  emoji: '🌄',
                  label: '换场景',
                  hint: '雪夜 / 樱庭 / 极光',
                  onTap: () {
                    close();
                    showSceneSheet(context);
                  },
                ),
                _ActionTile(
                  emoji: '✍️',
                  label: '角色设定',
                  hint: '补充人设与声线',
                  onTap: () {
                    close();
                    _showPersonaPicker(context);
                  },
                ),
                _ActionTile(
                  emoji: '📖',
                  label: '记忆册',
                  hint: '她们记住的事',
                  onTap: () {
                    close();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MemoryBookScreen()),
                    );
                  },
                ),
                _ActionTile(
                  emoji: '💬',
                  label: '聊天记录',
                  hint: '回看群聊',
                  onTap: () {
                    close();
                    showChatSheet(context);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showPersonaPicker(BuildContext context) {
  final characters = resolvedCharacters;
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text('想改谁的人设？',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          for (final c in characters)
            ListTile(
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonaEditorScreen(character: c),
                  ),
                );
              },
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Color(c.color).withValues(alpha: 0.6),
                backgroundImage: AssetImage(c.avatarAsset),
              ),
              title: Text(c.name, style: const TextStyle(fontSize: 13.5)),
              subtitle: Text(c.title,
                  style: const TextStyle(fontSize: 10, color: AppColors.dim)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.dim),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 7, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.dim)),
            ],
          ),
        ),
      ),
    );
  }
}

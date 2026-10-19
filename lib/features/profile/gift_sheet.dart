import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../data/events.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../chat/widgets.dart';

Future<void> showGiftSheet(BuildContext context, {Character? target}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => GiftScreen(initialTarget: target)),
  );
}

/// 独立投喂页：全部角色、全部道具、喜好提示一屏可点。
class GiftScreen extends StatefulWidget {
  final Character? initialTarget;

  const GiftScreen({super.key, this.initialTarget});

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  late String _target = widget.initialTarget?.id ?? resolvedCharacters.first.id;

  @override
  Widget build(BuildContext context) {
    final target = characterById(_target)!;
    final chat = context.read<ChatController>();
    return Scaffold(
      appBar: AppBar(title: const Text('投喂 / 送点什么')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          const Text('她们嘴上不一定领情，但好感会涨。',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final c in resolvedCharacters)
                GestureDetector(
                  onTap: () => setState(() => _target = c.id),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _target == c.id
                          ? Color(c.accentColor).withValues(alpha: 0.16)
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _target == c.id
                            ? Color(c.accentColor).withValues(alpha: 0.55)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarDot(character: c, size: 20),
                        const SizedBox(width: 6),
                        Text(c.name,
                            style: TextStyle(
                                fontSize: 12,
                                color: _target == c.id
                                    ? Color(c.accentColor)
                                    : AppColors.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${target.name} 喜欢：${target.likes.join('、')}',
                    style: const TextStyle(
                        fontSize: 11, height: 1.4, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.86,
            children: [
              for (final gift in kGifts)
                _GiftTile(
                  gift: gift,
                  onTap: () {
                    final chatRef = chat;
                    Navigator.pop(context);
                    chatRef.giveGift(target.id, gift);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '小提示：每天好感涨得有上限；送对东西会触发专属反应。',
            style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  final GiftItem gift;
  final VoidCallback? onTap;

  const _GiftTile({required this.gift, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(gift.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 5),
              Text(gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(gift.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 8.5, height: 1.2, color: AppColors.dim)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../state/chat_controller.dart';
import 'chat_panel.dart';

/// 完整的群聊记录页（从营地右上角进入）。
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final camp = context.watch<CampState>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篝火夜话'),
            Text('第 ${camp.nightCount} 夜 · 5 人 · 长按消息可以引用/记忆',
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.normal,
                    color: AppColors.muted)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            color: AppColors.surface,
            onSelected: (value) async {
              if (value == 'export') {
                final path = await chat.exportChat();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('已导出到：$path')));
                }
              } else if (value == 'clear') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('清空聊天记录？'),
                    content: const Text('好感、记忆和情绪都会保留，只清空这一晚的对话。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('清空')),
                    ],
                  ),
                );
                if (ok == true) await chat.clear();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('导出聊天记录')),
              PopupMenuItem(value: 'clear', child: Text('清空聊天记录')),
            ],
          ),
        ],
      ),
      body: ChatPanel(session: chat),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../state/chat_controller.dart';
import 'chat_panel.dart';

Future<void> showChatSheet(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const _ChatSheetPage(),
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}

class _ChatSheetPage extends StatelessWidget {
  const _ChatSheetPage();

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatController>();
    final camp = context.watch<CampState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black45),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, box) {
                final preferred = MediaQuery.sizeOf(context).height * 0.9;
                final height =
                    preferred < box.maxHeight ? preferred : box.maxHeight;
                return Container(
                  height: height,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: AppColors.ember, size: 20),
                              const SizedBox(width: 7),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('篝火夜话',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    '第 ${camp.nightCount} 夜 · 5 人在线'
                                    '${chat.busy ? ' · 正在说话' : ''}',
                                    style: const TextStyle(
                                        fontSize: 10.5, color: AppColors.muted),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: AppColors.dim,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: ChatPanel(session: chat)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

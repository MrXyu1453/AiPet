import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../data/events.dart';
import '../../state/chat_controller.dart';

Future<void> showEventSheet(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const EventScreen()),
  );
}

/// 独立的“今晚的篝火”页面。内容较长，用整页比 bottom sheet 更稳、更好点。
class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late CampEvent _event;
  bool _rerolled = false;

  @override
  void initState() {
    super.initState();
    _event = eventForDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final camp = context.watch<CampState>();
    final chat = context.read<ChatController>();
    final done = !camp.eventAvailableToday;
    return Scaffold(
      appBar: AppBar(
        title: const Text('今晚的篝火'),
        actions: [
          TextButton.icon(
            onPressed: () {
              final idx = kCampEvents.indexOf(_event);
              setState(() {
                _event = kCampEvents[(idx + 1) % kCampEvents.length];
                _rerolled = true;
              });
            },
            icon: const Icon(Icons.casino_outlined, size: 16),
            label: const Text('换一个', style: TextStyle(fontSize: 11.5)),
            style: TextButton.styleFrom(foregroundColor: AppColors.emberSoft),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          Text(
            done ? '今晚已经聊过一个话题了。还可以再点一堆火。' : '随机事件 · 每天换一个',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          if (_rerolled)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('换了一个话题。',
                  style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
            ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.ember.withValues(alpha: 0.16),
                  AppColors.surface2,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.l),
              border:
                  Border.all(color: AppColors.ember.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_event.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                Text(_event.title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_event.description,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.55, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('你怎么做？',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emberSoft)),
          const SizedBox(height: 8),
          for (final choice in _event.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ChoiceButton(
                label: choice.label,
                onTap: () {
                  final chatRef = chat;
                  final event = _event;
                  Navigator.pop(context);
                  chatRef.chooseEvent(event, choice);
                },
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '选择会影响她们的心情和好感；她们会自己接话。',
            style: TextStyle(fontSize: 10.5, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChoiceButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.text)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.dim),
            ],
          ),
        ),
      ),
    );
  }
}

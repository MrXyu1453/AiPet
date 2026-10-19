import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../chat/widgets.dart';

class MemoryBookScreen extends StatefulWidget {
  final String? initialCharacter;

  const MemoryBookScreen({super.key, this.initialCharacter});

  @override
  State<MemoryBookScreen> createState() => _MemoryBookScreenState();
}

class _MemoryBookScreenState extends State<MemoryBookScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialCharacter ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final camp = context.watch<CampState>();
    final all = camp.memories;
    final list = _filter == 'all'
        ? all
        : all
            .where((m) => m.characterId == _filter || m.characterId == 'all')
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆册'),
        actions: [
          IconButton(
            tooltip: '手动记一条',
            onPressed: () => _add(context, camp),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('all', '全部', null),
                for (final c in resolvedCharacters) _chip(c.id, c.name, c),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const _Empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = list[i];
                      final c = characterById(m.characterId);
                      final accent =
                          c == null ? AppColors.ember : Color(c.accentColor);
                      return Container(
                        padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_iconFor(m.kind), size: 16, color: accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.text,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: AppColors.text)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${c?.name ?? '营地'} · ${fmtDate(m.createdAt)} '
                                    '${fmtClock(m.createdAt)}',
                                    style: const TextStyle(
                                        fontSize: 10.5, color: AppColors.dim),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed: () => camp.removeMemory(m.id),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: AppColors.dim,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String id, String label, Character? c) {
    final selected = _filter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.ember.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected
                    ? AppColors.ember.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c != null) ...[
                AvatarDot(character: c, size: 18),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: selected ? AppColors.emberSoft : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(MemoryKind k) => switch (k) {
        MemoryKind.fact => Icons.push_pin_outlined,
        MemoryKind.promise => Icons.handshake_outlined,
        MemoryKind.quote => Icons.format_quote_rounded,
        MemoryKind.event => Icons.local_fire_department_outlined,
      };

  Future<void> _add(BuildContext context, CampState camp) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('记一件事', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '比如：主人怕黑；答应下次带饭团',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('记住'),
          ),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) {
      camp.addMemory(text.trim(),
          characterId: _filter == 'all' ? 'all' : _filter,
          kind: MemoryKind.fact);
    }
    controller.dispose();
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📖', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('还没有记忆',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              '长按聊天里的某句话，选“记进记忆册”；\n或者在这里手动写一条。',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

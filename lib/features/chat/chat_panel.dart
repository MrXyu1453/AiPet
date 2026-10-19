import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/camp_state.dart';
import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../../state/chat_session.dart';
import '../../state/settings_controller.dart';
import '../profile/profile_sheet.dart';
import '../settings/settings_screen.dart';
import 'widgets.dart';

class _Entry {
  final ChatMessage? message;
  final DateTime? date;
  final bool typing;
  final bool showHeader;

  const _Entry.message(this.message, {required this.showHeader, this.date})
      : typing = false;
  const _Entry.date(this.date)
      : message = null,
        typing = false,
        showHeader = false;
  const _Entry.typing()
      : message = null,
        date = null,
        typing = true,
        showHeader = false;
}

class ChatPanel extends StatefulWidget {
  final ChatSession session;
  final bool compact;

  const ChatPanel({super.key, required this.session, this.compact = false});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _scroll = ScrollController();
  ChatMessage? _replyTo;
  bool _pinned = true;
  bool _didInitialJump = false;
  bool _scrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _pinned = pos.pixels >= pos.maxScrollExtent - 90;
  }

  void _onSession() {
    if (!_pinned || !mounted) return;
    _scheduleScroll(animate: true);
  }

  void _scheduleScroll({bool animate = false}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _pinned = true;
    final replyTo = _replyTo;
    setState(() => _replyTo = null);
    widget.session.sendUser(text, replyToId: replyTo?.id);
    _scheduleScroll(animate: true);
  }

  void _suggest(String text) {
    _pinned = true;
    widget.session.sendUser(text);
    _scheduleScroll(animate: true);
  }

  List<_Entry> _entries(List<ChatMessage> messages) {
    final entries = <_Entry>[];
    DateTime? lastDate;
    ChatMessage? prev;
    for (final m in messages) {
      final date = DateTime(m.time.year, m.time.month, m.time.day);
      if (lastDate == null || date != lastDate) {
        entries.add(_Entry.date(date));
        lastDate = date;
        prev = null;
      }
      final sameSender = prev != null &&
          prev.senderId == m.senderId &&
          !m.isSystem &&
          !prev.isSystem &&
          m.time.difference(prev.time).inMinutes < 3;
      entries.add(_Entry.message(
        m,
        showHeader: !sameSender || m.isSystem,
        date: date,
      ));
      prev = m;
    }
    if (widget.session.typingIds.isNotEmpty) entries.add(const _Entry.typing());
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final messages = widget.session.messages;
        final entries = _entries(messages);
        if (!_didInitialJump && entries.isNotEmpty) {
          _didInitialJump = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
        return Column(
          children: [
            _Banner(session: widget.session),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(session: widget.session, onSuggest: _suggest)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(top: 6, bottom: 14),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        if (e.typing) return TypingRow(session: widget.session);
                        if (e.message == null) {
                          return DateDivider(time: e.date!);
                        }
                        final m = e.message!;
                        return MessageTile(
                          message: m,
                          session: widget.session,
                          showHeader: e.showHeader,
                          onLongPress: () => _showActions(m),
                          onRetry: () => widget.session.retry(m),
                          onOpenProfile: () => _openProfile(m.senderId),
                          onOpenSticker: () => _openSticker(m.sticker!),
                        );
                      },
                    ),
            ),
            ChatInputBar(
              session: widget.session,
              onSend: _send,
              onStop: () {
                widget.session.stop();
              },
              onTyping: widget.session.onUserActive,
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              onSendSticker: (asset) {
                _pinned = true;
                widget.session.sendSticker(asset);
                _scheduleScroll(animate: true);
              },
            ),
          ],
        );
      },
    );
  }

  void _openProfile(String senderId) {
    final c = characterById(senderId);
    if (c == null) return;
    showCharacterProfile(context, c);
  }

  void _openSticker(String sticker) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(sticker, fit: BoxFit.contain),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(ChatMessage m) {
    final camp = context.read<CampState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, size: 20),
                title: const Text('复制这句话'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  Navigator.pop(ctx);
                  _toast('已复制');
                },
              ),
            if (!m.isUser && !m.isSystem)
              ListTile(
                leading: const Icon(Icons.reply_rounded, size: 20),
                title: const Text('引用回复'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyTo = m);
                },
              ),
            if (m.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined, size: 20),
                title: const Text('记进记忆册'),
                onTap: () {
                  final who =
                      m.isUser ? '我' : widget.session.characterName(m.senderId);
                  final item = camp.addMemory('$who：${m.text}',
                      characterId: m.isUser ? 'all' : m.senderId,
                      kind: MemoryKind.quote);
                  Navigator.pop(ctx);
                  _toast(item == null ? '这句话已经在记忆册里了' : '已记进记忆册');
                },
              ),
            if (!m.isUser && !m.isSystem)
              ListTile(
                leading: const Icon(Icons.badge_outlined, size: 20),
                title: const Text('查看她的资料'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openProfile(m.senderId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Banner extends StatelessWidget {
  final ChatSession session;

  const _Banner({required this.session});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final demo = settings.demoMode && !settings.configured;
    if (session.canChat && !demo) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: demo ? const Color(0xFF2A2417) : const Color(0xFF2A1A1E),
      child: Row(
        children: [
          Icon(demo ? Icons.science_outlined : Icons.key_off_outlined,
              size: 15, color: demo ? AppColors.emberSoft : AppColors.danger),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              demo
                  ? '试玩模式：用的是本地台词。接上 API 后她们会真的接话、记得你。'
                  : '还没有配置 API Key，她们现在只能看着你。',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: demo ? AppColors.emberSoft : const Color(0xFFE8A0A8)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: settings,
                  child: const SettingsScreen(),
                ),
              ),
            ),
            child: Text(
              demo ? '去配置' : '去设置',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emberSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ChatSession session;
  final ValueChanged<String> onSuggest;

  const _EmptyState({required this.session, required this.onSuggest});

  @override
  Widget build(BuildContext context) {
    final c = session.isPrivate ? characterById(session.characterId!) : null;
    final suggestions = session.isPrivate
        ? <String>[
            '今晚怎么还没睡？',
            '可以跟我说说你的秘密吗？',
            '你今天心情怎么样？',
          ]
        : <String>[
            '今晚谁最会干饭？',
            '让 Grok 讲个冷笑话',
            '你们谁最想被摸头？',
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: [
        if (c != null) ...[
          Center(child: AvatarDot(character: c, size: 76, ring: true)),
          const SizedBox(height: 14),
          Center(
            child: Text(c.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '这里只有你们两个人。说点不会在群里说的话。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ] else ...[
          const Center(
            child: Text('🏕️', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('篝火刚点起来',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('五个人在火边等你开口。\n先挑一句，或者自己说点什么。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted)),
          ),
        ],
        const SizedBox(height: 24),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onSuggest(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 15, color: AppColors.dim),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.text)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppColors.dim),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

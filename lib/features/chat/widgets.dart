import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/characters.dart';
import '../../models/models.dart';
import '../../state/chat_session.dart';

String fmtClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String fmtDate(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff < 7) return '${diff + 1} 天前';
  return '${t.year}/${t.month}/${t.day}';
}

class AvatarDot extends StatelessWidget {
  final Character character;
  final double size;
  final bool ring;

  const AvatarDot({
    super.key,
    required this.character,
    this.size = 40,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentColor);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 2 : 0),
      decoration: ring
          ? BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
            )
          : null,
      child: ClipOval(
        child: ColoredBox(
          color: Color(character.color).withValues(alpha: 0.75),
          child: Image.asset(
            character.avatarAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                character.initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserDot extends StatelessWidget {
  final double size;

  const UserDot({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB861), Color(0xFFE05B6A)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(Icons.local_fire_department_rounded,
          size: size * 0.52, color: const Color(0xFF2A1808)),
    );
  }
}

class MoodBadge extends StatelessWidget {
  final String? mood;
  final Color accent;
  final bool compact;
  final double? intensity;

  const MoodBadge({
    super.key,
    required this.mood,
    required this.accent,
    this.compact = false,
    this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    if (mood == null || mood == kNeutralMood) return const SizedBox.shrink();
    final emoji = moodEmoji(mood);
    if (compact) {
      return Text(emoji, style: const TextStyle(fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$emoji $mood',
        style: TextStyle(fontSize: 10.5, color: accent, height: 1.2),
      ),
    );
  }
}

class MessageTile extends StatelessWidget {
  final ChatMessage message;
  final ChatSession session;
  final bool showHeader;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSticker;

  const MessageTile({
    super.key,
    required this.message,
    required this.session,
    this.showHeader = true,
    this.onLongPress,
    this.onRetry,
    this.onOpenProfile,
    this.onOpenSticker,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _system(context);
    final c = characterById(message.senderId);
    final isMine = message.isUser;
    final accent = c == null ? AppColors.ember : Color(c.accentColor);
    final bubbleColor = isMine
        ? const Color(0xFF3B2A1B)
        : (c == null
            ? AppColors.surface3
            : Color(c.color).withValues(alpha: 0.22));
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    final bubble = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 2, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMine ? '我' : (c?.name ?? '?'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isMine ? AppColors.emberSoft : accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isMine && message.mood != null) ...[
                  const SizedBox(width: 5),
                  MoodBadge(mood: message.mood, accent: accent, compact: true),
                ],
                const SizedBox(width: 6),
                Text(fmtClock(message.time),
                    style: const TextStyle(fontSize: 10, color: AppColors.dim)),
              ],
            ),
          ),
        if (message.replyToId != null)
          _QuoteBlock(
            text: session.quoteFor(message.replyToId) ?? '引用的消息已删除',
            accent: accent,
            isMine: isMine,
          ),
        GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: message.isError ? const Color(0xFF3A1E24) : bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMine ? 16 : 5),
                topRight: Radius.circular(isMine ? 5 : 16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              border: Border.all(
                color: message.isError
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : accent.withValues(alpha: isMine ? 0.22 : 0.3),
              ),
            ),
            child: message.isSticker
                ? GestureDetector(
                    onTap: onOpenSticker,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        message.sticker!,
                        width: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('[表情包加载失败]',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ),
                      ),
                    ),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: message.text),
                        if (message.isStreaming)
                          const TextSpan(
                            text: '▍',
                            style: TextStyle(color: AppColors.ember),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.text,
                    ),
                  ),
          ),
        ),
        if (message.actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              message.actions.map((a) => '· $a').join('  '),
              style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.dim,
                  fontStyle: FontStyle.italic),
            ),
          ),
        if (message.isError && message.retryFor != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('重试', style: TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.emberSoft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showHeader ? 10 : 3,
        bottom: 2,
        left: isMine ? 54 : 10,
        right: isMine ? 10 : 54,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            GestureDetector(
              onTap: onOpenProfile,
              child:
                  AvatarDot(character: c ?? resolvedCharacters.first, size: 34),
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(child: bubble),
          if (isMine) const SizedBox(width: 8),
          if (isMine) const UserDot(size: 30),
        ],
      ),
    );
  }

  Widget _system(BuildContext context) {
    if (message.kind == MessageKind.event) {
      final parts = message.text.split('\n');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.ember.withValues(alpha: 0.14),
                AppColors.surface2,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.ember.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(parts.first,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emberSoft)),
              if (parts.length > 1) ...[
                const SizedBox(height: 4),
                Text(parts.skip(1).join('\n'),
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.45, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                message.isError ? const Color(0xFF2A1A1E) : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: message.isError
                ? Border.all(color: AppColors.danger.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            children: [
              Text(
                message.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: message.isError
                        ? const Color(0xFFE8A0A8)
                        : AppColors.muted),
              ),
              if (message.isError && message.retryFor != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.emberSoft,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('重试', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  final String text;
  final Color accent;
  final bool isMine;

  const _QuoteBlock({
    required this.text,
    required this.accent,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: isMine ? 20 : 0, bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    );
  }
}

class DateDivider extends StatelessWidget {
  final DateTime time;

  const DateDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(fmtDate(time),
                style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class TypingDots extends StatefulWidget {
  final Color color;
  final double size;

  const TypingDots({super.key, this.color = AppColors.muted, this.size = 5});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: widget.size,
                height: widget.size,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: 0.25 +
                        0.75 *
                            (0.5 +
                                    0.5 *
                                        (1.0 -
                                            (_c.value - i / 3.6).abs() * 3.2))
                                .clamp(0.0, 1.0),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TypingRow extends StatelessWidget {
  final ChatSession session;

  const TypingRow({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final ids = session.typingIds.toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    final names = session.isPrivate
        ? '${session.title} 正在输入'
        : '${ids.map(session.characterName).join('、')} 正在输入';
    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 6, 16, 4),
      child: Row(
        children: [
          TypingDots(
              color: session.isPrivate
                  ? Color(characterById(ids.first)?.accentColor ?? 0xFF8B93A7)
                  : AppColors.muted),
          const SizedBox(width: 8),
          Text(names,
              style: const TextStyle(fontSize: 11, color: AppColors.dim)),
        ],
      ),
    );
  }
}

class ChatInputBar extends StatefulWidget {
  final ChatSession session;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback onTyping;
  final ChatMessage? replyTo;
  final VoidCallback onCancelReply;
  final ValueChanged<String>? onSendSticker;

  const ChatInputBar({
    super.key,
    required this.session,
    required this.onSend,
    required this.onStop,
    required this.onTyping,
    required this.replyTo,
    required this.onCancelReply,
    this.onSendSticker,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
    widget.onTyping();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  void _mention(Character c) {
    final text = _controller.text;
    final selection = _controller.selection;
    final insert = '@${c.name} ';
    if (selection.isValid) {
      final start = selection.start.clamp(0, text.length);
      final end = selection.end.clamp(0, text.length);
      _controller.text = text.replaceRange(start, end, insert);
      _controller.selection =
          TextSelection.collapsed(offset: start + insert.length);
    } else {
      _controller.text = '$text$insert';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    _focus.requestFocus();
  }

  Future<void> _pickSticker() async {
    final asset = await showStickerPicker(context);
    if (asset == null) return;
    widget.onSendSticker?.call(asset);
    // 发完表情包把键盘收起来，留出空间看她们的反应。
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                    left: BorderSide(color: AppColors.ember, width: 2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 ${widget.session.characterName(widget.replyTo!.senderId)}：'
                      '${widget.replyTo!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: AppColors.dim,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          if (widget.session.supportsMentions)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in resolvedCharacters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _mention(c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Color(c.accentColor)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarDot(character: c, size: 18),
                              const SizedBox(width: 5),
                              Text(c.name,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onSubmitted: (_) => _send(),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  decoration: InputDecoration(
                    hintText: widget.session.isPrivate
                        ? '只对她说点什么…'
                        : '说点什么，或者 @ 某只娘…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (widget.onSendSticker != null) ...[
                _RoundAction(
                  icon: Icons.emoji_emotions_outlined,
                  color: AppColors.surface3,
                  onTap: _pickSticker,
                  tooltip: '发表情包',
                ),
                const SizedBox(width: 4),
              ],
              // 她还在说话时也允许发送：消息会排在她说完之后，不会被
              // 当成“打断”或让聊天卡住。输入框为空时才只显示停止。
              if (widget.session.busy) ...[
                _RoundAction(
                  icon: Icons.stop_rounded,
                  color: AppColors.danger,
                  onTap: widget.onStop,
                  tooltip: '停止',
                ),
                if (canSend) const SizedBox(width: 4),
              ],
              if (canSend || !widget.session.busy)
                _RoundAction(
                  icon: Icons.arrow_upward_rounded,
                  color: canSend ? AppColors.ember : AppColors.surface3,
                  iconColor: canSend ? const Color(0xFF241606) : AppColors.dim,
                  onTap: canSend ? _send : null,
                  tooltip: '发送',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback? onTap;
  final String tooltip;

  const _RoundAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 22, color: iconColor ?? AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// 用户表情包选择器。返回资源路径；取消返回 null。
Future<String?> showStickerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('发一张表情包',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text('发出去之后，她们会对你发的东西做出反应。',
              style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final c in resolvedCharacters)
                _StickerOption(
                  character: c,
                  onTap: () => Navigator.pop(ctx, c.stickerAsset),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StickerOption extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const _StickerOption({required this.character, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                character.stickerAsset,
                fit: BoxFit.contain,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(character.initial,
                      style: TextStyle(fontSize: 24, color: accent)),
                ),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(character.name,
                    style: TextStyle(fontSize: 8.5, color: accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

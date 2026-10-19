import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/audio_service.dart';
import '../../core/camp_state.dart';
import '../../core/scenes.dart';
import '../../core/theme.dart';
import '../../core/voice_service.dart';
import '../../data/characters.dart';
import '../../data/personas.dart';
import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../campfire/campfire_stage.dart';
import '../campfire/character_visual.dart';
import '../campfire/event_sheet.dart';
import '../campfire/rhythm_game.dart';
import '../profile/profile_sheet.dart';
import '../scenes/scene_sheet.dart';
import '../settings/settings_screen.dart';
import 'chat_sheet.dart';
import 'quick_actions.dart';

class CampfireScreen extends StatefulWidget {
  const CampfireScreen({super.key});

  @override
  State<CampfireScreen> createState() => _CampfireScreenState();
}

class _CampfireScreenState extends State<CampfireScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _period = Duration(milliseconds: 5200);
  static const _styleFile = {'official': 'f0.png', 'chibi': 'chibi.png'};

  late final AnimationController _anim;
  final Map<String, ui.Image> _sprites = {};
  final Map<String, Reaction> _reactions = {};
  final GlobalKey _stageKey = GlobalKey();
  String? _loadedStyle;
  int _loadGen = 0;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _idleFxTimer;
  Timer? _bubbleTimer;
  late final AudioService _audio;
  late final VoiceService _voice;
  ChatController? _chatListener;
  bool _busyLatch = false;
  Timer? _busyHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = context.read<AudioService>();
    _voice = context.read<VoiceService>();
    _anim = AnimationController(vsync: this, duration: _period)..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _idleFxTimer =
        Timer.periodic(const Duration(seconds: 16), (_) => _idleFx());
    // 气泡/字幕的淡入淡出和 9 秒 TTL 依赖时间；主舞台不再每帧重建后，
    // 用 4fps 的轻量刷新维持它们，不把整棵舞台拖回 60fps。
    _bubbleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsController>();
      if (settings.ambienceEnabled) _audio.startAmbience();
      final chat = context.read<ChatController>();
      _chatListener = chat;
      chat.addListener(_onChatTick);
    });
  }

  /// 让“正在说话”胶囊在两次发言之间的短暂空档也保持可见，
  /// 避免它一闪一闪；同时避免每来一条消息都重新弹一次。
  void _onChatTick() {
    final chat = _chatListener;
    if (chat == null || !mounted) return;
    if (chat.busy) {
      _busyHideTimer?.cancel();
      _busyHideTimer = null;
      if (!_busyLatch) setState(() => _busyLatch = true);
    } else if (_busyLatch && _busyHideTimer == null) {
      _busyHideTimer = Timer(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        _busyHideTimer = null;
        if (!(_chatListener?.busy ?? false)) {
          setState(() => _busyLatch = false);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsController>();
    final style = settings.spriteStyle;
    if (style != _loadedStyle) {
      _loadedStyle = style;
      final gen = ++_loadGen;
      for (final c in resolvedCharacters) {
        _loadSprite(c.id, style, gen);
      }
    }
    if (settings.ambienceEnabled) {
      _audio.startAmbience();
    } else {
      _audio.stopAmbience();
    }
  }

  Future<void> _loadSprite(String id, String style, int gen,
      {int attempt = 0}) async {
    try {
      final data =
          await rootBundle.load('assets/sprites/$id/${_styleFile[style]}');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 480,
      );
      final frame = await codec.getNextFrame();
      if (!mounted || gen != _loadGen) {
        frame.image.dispose();
        return;
      }
      final old = _sprites[id];
      setState(() => _sprites[id] = frame.image);
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } catch (e) {
      debugPrint('sprite $id/$style failed: $e');
      if (attempt < 1 && mounted && gen == _loadGen) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted && gen == _loadGen) {
          await _loadSprite(id, style, gen, attempt: attempt + 1);
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audio.stopAmbience();
      _voice.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (context.read<SettingsController>().ambienceEnabled) {
        _audio.startAmbience();
      }
    }
  }

  void _idleFx() {
    if (!mounted) return;
    final chat = context.read<ChatController>();
    if (chat.busy || chat.concert) return;
    final characters = resolvedCharacters;
    final c = characters[DateTime.now().second % characters.length];
    if (DateTime.now().millisecond % 3 == 0) {
      _setReaction(c, ReactionType.note, sfx: false);
    }
  }

  void _setReaction(Character c, ReactionType type, {bool sfx = true}) {
    if (!mounted) return;
    setState(() => _reactions[c.id] = Reaction(type, DateTime.now()));
    if (!sfx) return;
    switch (type) {
      case ReactionType.pat:
      case ReactionType.hug:
        _audio.playSfx(Sfx.heart);
        break;
      case ReactionType.surprise:
        _audio.playSfx(Sfx.sparkle);
        break;
      case ReactionType.angry:
        _audio.playSfx(Sfx.angry);
        break;
      case ReactionType.tail:
      case ReactionType.note:
      case ReactionType.sing:
        _audio.playSfx(Sfx.note);
        break;
      case ReactionType.poke:
      case ReactionType.yawn:
        _audio.playSfx(Sfx.tap);
        break;
    }
  }

  void _poke(Character c, PokeZone zone) {
    final chat = context.read<ChatController>();
    var type = ReactionType.poke;
    switch (zone) {
      case PokeZone.head:
        type = c.id == 'grok' ? ReactionType.angry : ReactionType.pat;
        break;
      case PokeZone.face:
        type = ReactionType.poke;
        break;
      case PokeZone.body:
        type = ReactionType.poke;
        break;
      case PokeZone.tail:
        type = ReactionType.tail;
        break;
    }
    _setReaction(c, type);
    chat.poke(c.id, zone: zone);
  }

  void _surprise(Character c) {
    _setReaction(c, ReactionType.surprise);
    context.read<ChatController>().poke(c.id, zone: PokeZone.body);
  }

  void _hug(Character c) {
    _setReaction(c, ReactionType.hug);
    context.read<ChatController>().poke(c.id, zone: PokeZone.head);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatListener?.removeListener(_onChatTick);
    _busyHideTimer?.cancel();
    _bubbleTimer?.cancel();
    _clockTimer?.cancel();
    _idleFxTimer?.cancel();
    _anim.dispose();
    for (final img in _sprites.values) {
      img.dispose();
    }
    _audio.stopAmbience();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final camp = context.watch<CampState>();
    final settings = context.watch<SettingsController>();
    final voice = context.watch<VoiceService>();
    // 角色设定改名/改称呼后，舞台与名字胶囊要跟着重绘。
    context.watch<PersonaStore>();
    final scene = settings.scene;
    final phase = dayPhaseFor(_now);
    final canChat = settings.configured || settings.demoMode;
    final talking = <String, String>{
      if (voice.speakingId != null) voice.speakingId!: '1',
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _topBar(chat, camp, settings),
          ),
          Expanded(
            // 状态条/提示条一律浮在舞台上方：它们出现或消失时不能改变舞台
            // 的可用高度，否则 LayoutBuilder 会重算所有立绘的尺寸和脚底坐标，
            // 看起来就是整屏“抖一下”。
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: _stageKey,
                    child: ClipRect(
                      child: CampfireStage(
                        clock: _anim,
                        images: _sprites,
                        chat: chat,
                        camp: camp,
                        reactions: _reactions,
                        talking: talking,
                        scene: scene,
                        phase: phase,
                        followTime: settings.followTime,
                        atmosphereEnabled: settings.atmosphereEnabled,
                        onPoke: _poke,
                        onDoubleTap: _surprise,
                        onHug: _hug,
                        onNameplateTap: (c) => showCharacterProfile(context, c),
                        onBubbleTap: (_) => showChatSheet(context),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _StageStatusOverlay(
                    showHint: !canChat,
                    busy: chat.busy || _busyLatch,
                    names: chat.typingIds.map(chat.characterName).join('、'),
                    onStop: chat.stop,
                    onOpenSettings: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: settings,
                          child: const SettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(chat, camp, settings),
        ],
      ),
    );
  }

  Widget _topBar(
      ChatController chat, CampState camp, SettingsController settings) {
    final clock =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0E14), Color(0xFF10151F)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ember.withValues(alpha: 0.12),
              border:
                  Border.all(color: AppColors.ember.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.local_fire_department,
                color: AppColors.ember, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text('AI娘篝火营地',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w700)),
                    ),
                    if (settings.demoMode && !settings.configured) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.ember.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('试玩',
                            style: TextStyle(
                                fontSize: 8.5, color: AppColors.emberSoft)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showSceneSheet(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '第 ${camp.nightCount} 夜 · $clock · ${settings.scene.name}'
                          '${chat.concert ? ' · LIVE' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: settings.scene.id == 'campfire'
                                  ? AppColors.muted
                                  : settings.scene.accent
                                      .withValues(alpha: 0.85)),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more_rounded,
                          size: 12,
                          color: settings.scene.accent.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _topIcon(Icons.forum_outlined, '聊天记录', () => showChatSheet(context)),
          _topIcon(
            Icons.settings_outlined,
            '设置',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: settings,
                  child: const SettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: AppColors.muted,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _bottomBar(
      ChatController chat, CampState camp, SettingsController settings) {
    final eventReady = camp.eventAvailableToday;
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chat.concert)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.ember.withValues(alpha: 0.13),
                    Colors.transparent,
                  ]),
                ),
                child: Row(
                  children: [
                    const Text('🎶 LIVE · 篝火演唱会',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emberSoft)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openRhythm,
                      icon: const Icon(Icons.music_note_rounded, size: 15),
                      label: const Text('节奏挑战', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.emberSoft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: () => showChatSheet(context),
                        borderRadius: BorderRadius.circular(22),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 16, color: AppColors.dim),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('说点什么，或者 @ 某只娘…',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5, color: AppColors.dim)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _barIcon(
                    Icons.casino_outlined,
                    '今晚的话题',
                    () => showEventSheet(context),
                    badge: eventReady,
                  ),
                  _barIcon(
                    Icons.auto_awesome_mosaic_outlined,
                    '互动',
                    () => showQuickActions(context, onTakePhoto: _takePhoto),
                    color: AppColors.emberSoft,
                  ),
                  _barIcon(
                    Icons.landscape_outlined,
                    '换个场景',
                    () => showSceneSheet(context),
                    color: settings.scene.id == 'campfire'
                        ? AppColors.muted
                        : settings.scene.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barIcon(IconData icon, String tooltip, VoidCallback onTap,
      {bool badge = false, Color? color}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 22),
          color: color ?? AppColors.muted,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        if (badge)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.ember,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openRhythm() async {
    final result = await showRhythmGame(context);
    if (result == null || !mounted) return;
    await context
        .read<ChatController>()
        .announceConcertResult(result.score, result.maxCombo);
  }

  Future<void> _takePhoto() async {
    final boundary =
        _stageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      await _audio.playSfx(Sfx.shutter);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final image = await boundary.toImage(pixelRatio: 2.2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null || !mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final folder =
          Directory('${dir.path}${Platform.pathSeparator}aining_export');
      if (!await folder.exists()) await folder.create(recursive: true);
      final now = DateTime.now();
      final file = File(
          '${folder.path}${Platform.pathSeparator}篝火合影_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes.buffer.asUint8List(),
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 10),
                Text('已保存到：${file.path}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('收好'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('合影保存失败：$e')));
    }
  }
}

/// 浮在舞台顶部的状态层。
///
/// 关键点：它只改变自己的高度，永远不参与舞台所在的 Column 布局，所以
/// “正在说话”条出现/消失、以及未配置 Key 的提示条，都不会再把整块舞台
/// 往上顶、导致 5 个立绘重新缩放。
class _StageStatusOverlay extends StatelessWidget {
  final bool showHint;
  final bool busy;
  final String names;
  final VoidCallback onStop;
  final VoidCallback onOpenSettings;

  const _StageStatusOverlay({
    required this.showHint,
    required this.busy,
    required this.names,
    required this.onStop,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey<String>('$showHint-$busy'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHint) _setupHint(),
            if (busy)
              _BusyPill(
                names: names,
                onStop: onStop,
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Color(0xF22A2417),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_off_outlined,
              size: 14, color: AppColors.emberSoft),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('还没有配置 API Key。先试玩，或者去设置接上模型。',
                style: TextStyle(fontSize: 11, color: AppColors.emberSoft)),
          ),
          GestureDetector(
            onTap: onOpenSettings,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text('去设置',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ember)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyPill extends StatelessWidget {
  final String names;
  final VoidCallback onStop;

  const _BusyPill({required this.names, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.fromLTRB(13, 3, 4, 3),
          decoration: BoxDecoration(
            color: const Color(0xEE141823),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.ember.withValues(alpha: 0.32),
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: AppColors.ember),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  names.isEmpty ? '她们正在说话…' : '$names 正在说话…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: onStop,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('停止', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

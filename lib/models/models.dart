import 'dart:math';

/// 角色设定。立绘/头像素材版权归原作者（ZipZipPipe / deepseek-whalechan
/// 社区，CC-BY-NC-SA），本项目为非商业个人项目，保留署名。
class Character {
  final String id;
  final String name;
  final String title;
  final int color;
  final int accentColor;
  final String avatarAsset;
  final String stickerAsset;
  final String instrument;
  final String personality;
  final String speakingStyle;
  final String relationships;

  /// 关系网：对方 id -> 一句话关系。比整段散文更适合做 UI 和提示词钩子。
  final Map<String, String> bonds;
  final List<String> catchphrases;

  /// 她不会主动说出口的事。提示词会用它制造“被戳中”的破绽。
  final String secret;

  /// 她平时怎么称呼用户；空字符串表示用全局昵称。
  final String addressAs;

  /// 投喂偏好：喜欢 / 不喜欢
  final List<String> likes;
  final List<String> dislikes;

  /// 系统 TTS 的声线参数（pitch / rate）
  final double ttsPitch;
  final double ttsRate;

  const Character({
    required this.id,
    required this.name,
    required this.title,
    required this.color,
    required this.accentColor,
    required this.avatarAsset,
    required this.stickerAsset,
    required this.instrument,
    required this.personality,
    required this.speakingStyle,
    required this.relationships,
    required this.catchphrases,
    this.bonds = const {},
    this.secret = '',
    this.addressAs = '',
    this.likes = const [],
    this.dislikes = const [],
    this.ttsPitch = 1.0,
    this.ttsRate = 0.5,
  });

  String get initial => name.substring(0, 1);
  String get handle => '@$name';

  Character copyWith({
    String? id,
    String? name,
    String? title,
    int? color,
    int? accentColor,
    String? avatarAsset,
    String? stickerAsset,
    String? instrument,
    String? personality,
    String? speakingStyle,
    String? relationships,
    Map<String, String>? bonds,
    List<String>? catchphrases,
    String? secret,
    String? addressAs,
    List<String>? likes,
    List<String>? dislikes,
    double? ttsPitch,
    double? ttsRate,
  }) =>
      Character(
        id: id ?? this.id,
        name: name ?? this.name,
        title: title ?? this.title,
        color: color ?? this.color,
        accentColor: accentColor ?? this.accentColor,
        avatarAsset: avatarAsset ?? this.avatarAsset,
        stickerAsset: stickerAsset ?? this.stickerAsset,
        instrument: instrument ?? this.instrument,
        personality: personality ?? this.personality,
        speakingStyle: speakingStyle ?? this.speakingStyle,
        relationships: relationships ?? this.relationships,
        bonds: bonds ?? this.bonds,
        catchphrases: catchphrases ?? this.catchphrases,
        secret: secret ?? this.secret,
        addressAs: addressAs ?? this.addressAs,
        likes: likes ?? this.likes,
        dislikes: dislikes ?? this.dislikes,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        ttsRate: ttsRate ?? this.ttsRate,
      );
}

/// 用户对某个角色做的“二创补充”。全部字段都是增量语义：
/// 空字符串 / 空列表 = 不覆盖，避免一键编辑把原始人设抹掉。
class PersonaOverride {
  final String name;
  final String title;
  final String addressAs;
  final String personalityAdd;
  final String speakingAdd;
  final String relationshipAdd;
  final List<String> extraCatchphrases;
  final List<String> extraLikes;
  final List<String> extraDislikes;
  final double? ttsPitch;
  final double? ttsRate;

  const PersonaOverride({
    this.name = '',
    this.title = '',
    this.addressAs = '',
    this.personalityAdd = '',
    this.speakingAdd = '',
    this.relationshipAdd = '',
    this.extraCatchphrases = const [],
    this.extraLikes = const [],
    this.extraDislikes = const [],
    this.ttsPitch,
    this.ttsRate,
  });

  bool get isEmpty =>
      name.trim().isEmpty &&
      title.trim().isEmpty &&
      addressAs.trim().isEmpty &&
      personalityAdd.trim().isEmpty &&
      speakingAdd.trim().isEmpty &&
      relationshipAdd.trim().isEmpty &&
      extraCatchphrases.isEmpty &&
      extraLikes.isEmpty &&
      extraDislikes.isEmpty &&
      ttsPitch == null &&
      ttsRate == null;

  PersonaOverride copyWith({
    String? name,
    String? title,
    String? addressAs,
    String? personalityAdd,
    String? speakingAdd,
    String? relationshipAdd,
    List<String>? extraCatchphrases,
    List<String>? extraLikes,
    List<String>? extraDislikes,
    double? ttsPitch,
    double? ttsRate,
    bool clearVoice = false,
  }) =>
      PersonaOverride(
        name: name ?? this.name,
        title: title ?? this.title,
        addressAs: addressAs ?? this.addressAs,
        personalityAdd: personalityAdd ?? this.personalityAdd,
        speakingAdd: speakingAdd ?? this.speakingAdd,
        relationshipAdd: relationshipAdd ?? this.relationshipAdd,
        extraCatchphrases: extraCatchphrases ?? this.extraCatchphrases,
        extraLikes: extraLikes ?? this.extraLikes,
        extraDislikes: extraDislikes ?? this.extraDislikes,
        ttsPitch: clearVoice ? null : (ttsPitch ?? this.ttsPitch),
        ttsRate: clearVoice ? null : (ttsRate ?? this.ttsRate),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'addressAs': addressAs,
        'personalityAdd': personalityAdd,
        'speakingAdd': speakingAdd,
        'relationshipAdd': relationshipAdd,
        'extraCatchphrases': extraCatchphrases,
        'extraLikes': extraLikes,
        'extraDislikes': extraDislikes,
        'ttsPitch': ttsPitch,
        'ttsRate': ttsRate,
      };

  factory PersonaOverride.fromJson(Map<String, dynamic> j) => PersonaOverride(
        name: (j['name'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        addressAs: (j['addressAs'] as String?) ?? '',
        personalityAdd: (j['personalityAdd'] as String?) ?? '',
        speakingAdd: (j['speakingAdd'] as String?) ?? '',
        relationshipAdd: (j['relationshipAdd'] as String?) ?? '',
        extraCatchphrases: (j['extraCatchphrases'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        extraLikes:
            (j['extraLikes'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        extraDislikes:
            (j['extraDislikes'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        ttsPitch: (j['ttsPitch'] as num?)?.toDouble(),
        ttsRate: (j['ttsRate'] as num?)?.toDouble(),
      );
}

/// 心情标签 → emoji。集合与提示词保持一致。
const kMoodEmojis = <String, String>{
  '开心': '😊',
  '傲娇': '😤',
  '生气': '😠',
  '困倦': '😪',
  '得意': '😏',
  '害羞': '🙈',
  '无语': '😑',
  '兴奋': '🤩',
  '平静': '🙂',
  '难过': '😢',
};

const kNeutralMood = '平静';

const kMoodPromptList = '开心/傲娇/生气/困倦/得意/害羞/无语/兴奋/平静/难过';

String moodEmoji(String? mood) => kMoodEmojis[mood] ?? '';

/// 点角色的不同部位，触发不同的反应
enum PokeZone { head, face, body, tail }

/// 单条群聊/私聊消息
enum MessageKind { text, sticker, system, event }

class ChatMessage {
  final String id;
  final DateTime time;
  final String senderId; // 'user' / 'system' / 角色 id
  final String text;
  final String? replyToId;
  final String? mood;
  final String? sticker; // 表情包资源路径，非空表示表情包消息
  final List<String> actions; // 从 [动作:xx] 解析出来的表演提示
  final MessageKind kind;
  final bool isStreaming;
  final bool isError;
  final String? retryFor; // 失败时重试的角色 id

  const ChatMessage({
    required this.id,
    required this.time,
    required this.senderId,
    required this.text,
    this.replyToId,
    this.mood,
    this.sticker,
    this.actions = const [],
    this.kind = MessageKind.text,
    this.isStreaming = false,
    this.isError = false,
    this.retryFor,
  });

  ChatMessage copyWith({
    String? id,
    DateTime? time,
    String? senderId,
    String? text,
    String? replyToId,
    String? mood,
    String? sticker,
    List<String>? actions,
    MessageKind? kind,
    bool? isStreaming,
    bool? isError,
    String? retryFor,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        time: time ?? this.time,
        senderId: senderId ?? this.senderId,
        text: text ?? this.text,
        replyToId: replyToId ?? this.replyToId,
        mood: mood ?? this.mood,
        sticker: sticker ?? this.sticker,
        actions: actions ?? this.actions,
        kind: kind ?? this.kind,
        isStreaming: isStreaming ?? this.isStreaming,
        isError: isError ?? this.isError,
        retryFor: retryFor ?? this.retryFor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'senderId': senderId,
        'text': text,
        'replyToId': replyToId,
        'mood': mood,
        'sticker': sticker,
        'actions': actions,
        'kind': kind.name,
        'isError': isError,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        time: DateTime.parse(j['time'] as String),
        senderId: j['senderId'] as String,
        text: (j['text'] as String?) ?? '',
        replyToId: j['replyToId'] as String?,
        mood: j['mood'] as String?,
        sticker: j['sticker'] as String?,
        actions: (j['actions'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        kind: MessageKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () =>
              j['sticker'] != null ? MessageKind.sticker : MessageKind.text,
        ),
        isError: (j['isError'] as bool?) ?? false,
      );

  bool get isUser => senderId == 'user';
  bool get isSystem => senderId == 'system';
  bool get isSticker => sticker != null || kind == MessageKind.sticker;
}

/// 角色当前情绪（会随时间衰减）
class EmotionState {
  final String mood;
  final double intensity;
  final String? reason;
  final DateTime updatedAt;

  const EmotionState({
    required this.mood,
    required this.intensity,
    required this.updatedAt,
    this.reason,
  });

  factory EmotionState.neutral(DateTime now) => EmotionState(
        mood: kNeutralMood,
        intensity: 0,
        updatedAt: now,
      );

  bool get isNeutral => mood == kNeutralMood || intensity <= 0.08;
  String get emoji => moodEmoji(mood);

  EmotionState decayed(DateTime now) {
    if (isNeutral) return this;
    final minutes = now.difference(updatedAt).inSeconds / 60.0;
    if (minutes <= 0) return this;
    final v = intensity * exp(-minutes / 14.0);
    if (v < 0.12) return EmotionState.neutral(now);
    return EmotionState(
      mood: mood,
      intensity: v,
      reason: reason,
      updatedAt: updatedAt,
    );
  }

  EmotionState copyWith({
    String? mood,
    double? intensity,
    String? reason,
    DateTime? updatedAt,
  }) =>
      EmotionState(
        mood: mood ?? this.mood,
        intensity: intensity ?? this.intensity,
        reason: reason ?? this.reason,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'intensity': intensity,
        'reason': reason,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EmotionState.fromJson(Map<String, dynamic> j) => EmotionState(
        mood: (j['mood'] as String?) ?? kNeutralMood,
        intensity: ((j['intensity'] as num?) ?? 0).toDouble(),
        reason: j['reason'] as String?,
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// 好感度（每天有增长上限，避免刷）
class AffinityState {
  final int value;
  final int todayGain;
  final String dayKey; // yyyy-MM-dd
  final DateTime updatedAt;

  const AffinityState({
    required this.value,
    required this.todayGain,
    required this.dayKey,
    required this.updatedAt,
  });

  factory AffinityState.initial(DateTime now) => AffinityState(
        value: 8,
        todayGain: 0,
        dayKey: dayKeyOf(now),
        updatedAt: now,
      );

  static String dayKeyOf(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  String get tier {
    if (value >= 85) return '心意相通';
    if (value >= 60) return '挚友';
    if (value >= 32) return '熟识';
    if (value >= 15) return '认识';
    return '初见';
  }

  int get level => (value / 20).floor() + 1;
  double get progress => (value % 20) / 20.0;

  AffinityState normalized(DateTime now) {
    final key = dayKeyOf(now);
    if (key == dayKey) return this;
    return AffinityState(
      value: value,
      todayGain: 0,
      dayKey: key,
      updatedAt: updatedAt,
    );
  }

  AffinityState gain(int delta, DateTime now, {int dailyCap = 14}) {
    final n = normalized(now);
    if (delta <= 0) return n;
    final room = max(0, dailyCap - n.todayGain);
    final real = min(delta, room);
    if (real <= 0) return n;
    return AffinityState(
      value: min(100, n.value + real),
      todayGain: n.todayGain + real,
      dayKey: n.dayKey,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'todayGain': todayGain,
        'dayKey': dayKey,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AffinityState.fromJson(Map<String, dynamic> j) => AffinityState(
        value: ((j['value'] as num?) ?? 8).toInt(),
        todayGain: ((j['todayGain'] as num?) ?? 0).toInt(),
        dayKey: (j['dayKey'] as String?) ?? '',
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

enum MemoryKind { fact, promise, quote, event }

class MemoryItem {
  final String id;
  final String text;
  final String characterId; // 'all' 表示与所有人相关
  final MemoryKind kind;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.text,
    required this.characterId,
    required this.kind,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'characterId': characterId,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MemoryItem.fromJson(Map<String, dynamic> j) => MemoryItem(
        id: j['id'] as String,
        text: j['text'] as String,
        characterId: (j['characterId'] as String?) ?? 'all',
        kind: MemoryKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => MemoryKind.fact,
        ),
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

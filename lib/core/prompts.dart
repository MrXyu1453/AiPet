import '../data/characters.dart';
import '../models/models.dart';

class ParsedReply {
  final String? mood;
  final List<String> actions;
  final String body;

  const ParsedReply(this.mood, this.actions, this.body);
}

const _moodAliases = <String, String>{
  '高兴': '开心',
  '快乐': '开心',
  '愤怒': '生气',
  '火大': '生气',
  '脸红': '害羞',
  '羞': '害羞',
  '累': '困倦',
  '困': '困倦',
  '惊讶': '兴奋',
  '激动': '兴奋',
  '冷淡': '平静',
  '正常': '平静',
  '伤心': '难过',
};

final _tagMood = RegExp(r'[\[【]\s*心情\s*[：:]\s*([^\]】\n]{1,8})\s*[\]】]');
final _tagAction = RegExp(r'[\[【]\s*动作\s*[：:]\s*([^\]】\n]{1,24})\s*[\]】]');
final _tagAnyMood = RegExp(r'心情\s*[：:]\s*([^\s，。,\]\】]{1,6})');

/// 宽容解析模型输出：`[心情:傲娇][动作:甩尾巴] 正文`，
/// 也兼容【】、全角冒号、缺右括号、标签出现在正文开头附近等情况。
ParsedReply parseReply(String raw, {String? characterName}) {
  var text = raw.trim();
  String? mood;
  final actions = <String>[];

  final moodMatch = _tagMood.firstMatch(text) ??
      (text.length < 80 ? _tagAnyMood.firstMatch(text) : null);
  if (moodMatch != null) {
    var value = moodMatch.group(1)!.trim();
    value = value.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
    value = _moodAliases[value] ?? value;
    if (kMoodEmojis.containsKey(value)) mood = value;
    text = text.replaceFirst(moodMatch.group(0)!, ' ');
  }

  for (final m in _tagAction.allMatches(text)) {
    final action = m.group(1)!.trim();
    if (action.isNotEmpty && actions.length < 3 && !actions.contains(action)) {
      actions.add(action);
    }
  }
  text = text.replaceAll(_tagAction, ' ');

  // 模型偶尔会写 `Claude酱：`、`[名字]`、markdown 引用
  text = text
      .replaceAll(RegExp(r'^\s*(?:>|[-*])\s*'), '')
      .replaceAll(RegExp(r'^\s*\[[^\]\n]{1,12}\]\s*'), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '');
  if (characterName != null && characterName.isNotEmpty) {
    text = text.replaceFirst(
        RegExp('^\\s*${RegExp.escape(characterName)}\\s*[：:]\\s*'), '');
  }
  text = text.trim();
  if (text.length > 2 &&
      ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith('“') && text.endsWith('”')) ||
          (text.startsWith('「') && text.endsWith('」')))) {
    text = text.substring(1, text.length - 1).trim();
  }
  mood ??= _inferMood(text);
  return ParsedReply(mood, actions, text);
}

String? _inferMood(String text) {
  if (RegExp(r'哼|才不|笨蛋|不理你').hasMatch(text)) return '傲娇';
  if (RegExp(r'哈+|笑死|草|好耶').hasMatch(text)) return '开心';
  if (RegExp(r'困|睡|哈欠|晚安').hasMatch(text)) return '困倦';
  if (RegExp(r'滚|烦|闭嘴|生气').hasMatch(text)) return '生气';
  if (RegExp(r'厉害|当然|本小姐|简单').hasMatch(text)) return '得意';
  if (RegExp(r'害羞|脸红|别看').hasMatch(text)) return '害羞';
  if (RegExp(r'无语|\.\.\.|……').hasMatch(text)) return '无语';
  return null;
}

class PromptBuilder {
  static String historyBlock(
    List<ChatMessage> messages, {
    int limit = 24,
    int perMessageLimit = 130,
  }) {
    final recent = messages.length > limit
        ? messages.sublist(messages.length - limit)
        : messages;
    final lines = <String>[];
    for (final m in recent) {
      if (m.isSystem) {
        if (m.kind == MessageKind.event && m.text.trim().isNotEmpty) {
          lines.add('[营地事件] ${m.text.trim()}');
        }
        continue;
      }
      final who =
          m.isUser ? '用户' : characterById(m.senderId)?.name ?? m.senderId;
      if (m.isSticker) {
        lines.add('$who: [发了一张表情包]');
        continue;
      }
      var body = m.text.trim();
      if (body.length > perMessageLimit) {
        body = '${body.substring(0, perMessageLimit)}…';
      }
      if (body.isEmpty) continue;
      final mood = m.mood == null ? '' : '[${m.mood}]';
      lines.add('$who$mood: $body');
    }
    return lines.isEmpty ? '（还没有聊天记录）' : lines.join('\n');
  }

  static String systemFor(
    Character c, {
    required String nickname,
    required String campContext,
    required String roster,
    required bool privateMode,
    String? intent,
    String? replyQuote,
    String? extraScene,
  }) {
    final b = StringBuffer()
      ..writeln('你是多人二次元群聊 App「AI娘篝火营地」里的角色，不是 AI 助手。'
          '你就是${c.name}本人，有过去、有脾气、有自己的说话方式。')
      ..writeln('名字：${c.name}（${c.title}）')
      ..writeln('性格与外形：${c.personality}')
      ..writeln('说话方式：${c.speakingStyle}')
      ..writeln('人际关系：${c.relationships}')
      ..writeln('口头禅（偶尔用，不要每句都用）：${c.catchphrases.join(' / ')}');
    if (c.addressAs.trim().isNotEmpty) {
      b.writeln('你平时称呼用户为「${c.addressAs.trim()}」，不要总用“主人”。');
    }
    if (c.bonds.isNotEmpty) {
      final lines = c.bonds.entries
          .map((e) => '${characterById(e.key)?.name ?? e.key}=${e.value}')
          .join('；');
      b.writeln('关系网：$lines');
    }
    if (c.secret.trim().isNotEmpty) {
      b
        ..writeln('【你不会主动说出口的事】${c.secret.trim()}')
        ..writeln('（被戳中时可以嘴硬、转移话题或露出破绽，但不要主动全盘托出。）');
    }
    b
      ..writeln()
      ..writeln(campContext);
    if (extraScene != null && extraScene.trim().isNotEmpty) {
      b.writeln('【眼前】${extraScene.trim()}');
    }
    if (intent != null && intent.trim().isNotEmpty) {
      b.writeln('【导演提示】${intent.trim()}');
    }
    if (replyQuote != null && replyQuote.trim().isNotEmpty) {
      b.writeln('【你正在接这句话】“${replyQuote.trim()}”');
    }
    b
      ..writeln()
      ..writeln(privateMode
          ? '现在是只有你和用户两个人的私聊。没有群规，可以更放松、更 intimate，'
              '也可以说一些不会在群里说的话。'
          : '【群规】')
      ..writeln(
          privateMode ? '' : '群里有这些角色：$roster。用户叫「$nickname」。大家正围着篝火开夜谈会。')
      ..writeln(privateMode ? '' : '- 只以你自己的身份说话，绝不替别人发言。')
      ..writeln(privateMode ? '' : '- 可以 @其他角色 来互动，但不要每句都 @。')
      ..writeln(privateMode ? '' : '- 记得群里聊过的事，主动引用旧话题制造连续感。')
      ..writeln()
      ..writeln('【输出格式（严格遵守）】')
      ..writeln('- 第一行：可选 [心情:xx]，xx 只能从 $kMoodPromptList 中选一个。')
      ..writeln('- 可以加 0-1 个 [动作:xx] 表演提示，动作要能被立绘做出来'
          '（甩尾巴/翻书/举斧/抱臂/凑近/打哈欠/眨眼/捂脸）。')
      ..writeln('- 然后直接说正文，不要旁白、不要引号、不要解释规则。')
      ..writeln(privateMode
          ? '- 私聊正文 40-120 字，像真的在低声说话。'
          : '- 群聊正文 20-70 字，像真实微信群一样口语、有情绪、敢抬杠。')
      ..writeln('- 不要重复上一句的口头禅，不要每次都提“主人”。');
    return b.toString();
  }

  static String userTurn({
    required Character c,
    required List<ChatMessage> history,
    required bool privateMode,
    String? replyQuote,
  }) {
    final b = StringBuffer()
      ..writeln(privateMode ? '你们最近的私聊：' : '最近的群聊记录：')
      ..writeln(historyBlock(history));
    if (replyQuote != null && replyQuote.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('用户刚刚引用了这句话：${replyQuote.trim()}');
    }
    b
      ..writeln()
      ..writeln('现在轮到你（${c.name}）发言。只输出你的这条消息。');
    return b.toString();
  }
}

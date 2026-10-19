import 'dart:async';

import '../data/characters.dart';
import '../models/models.dart';
import '../state/settings_controller.dart';
import 'api_client.dart';
import 'camp_state.dart';
import 'demo.dart';
import 'prompts.dart';

class ChatReply {
  final String raw;
  final ParsedReply parsed;
  final bool demo;
  final bool fallback;

  const ChatReply({
    required this.raw,
    required this.parsed,
    required this.demo,
    this.fallback = false,
  });
}

/// 负责“让一个角色说一句话”：拼提示词、流式调用、演示模式、解析标签。
class ChatEngine {
  final SettingsController settings;
  final CampState camp;
  final DemoScript demo;

  ChatEngine(this.settings, this.camp, [DemoScript? demo])
      : demo = demo ?? DemoScript();

  Future<ChatReply> generate({
    required Character character,
    required List<ChatMessage> history,
    required bool privateMode,
    String? intent,
    String? replyQuote,
    String? extraScene,
    void Function(String rawSoFar)? onDelta,
    bool Function()? isCancelled,
  }) async {
    if (!settings.configured) {
      if (!settings.demoMode) {
        throw LlmException('还没有配置 API Key，去设置页填一下。',
            kind: LlmErrorKind.notConfigured);
      }
      return _demoReply(character, onDelta, isCancelled);
    }

    final config = settings.configFor(character.id);
    final backgroundScene = settings.scene.note;
    final combinedScene = [
      backgroundScene,
      if (extraScene != null && extraScene.trim().isNotEmpty) extraScene.trim(),
    ].join(' ');
    final system = PromptBuilder.systemFor(
      character,
      nickname: settings.nickname,
      campContext:
          camp.promptContext(character.id, nickname: settings.nickname),
      roster: resolvedCharacters.map((c) => '${c.name}（${c.title}）').join('\n'),
      privateMode: privateMode,
      intent: intent,
      replyQuote: replyQuote,
      extraScene: combinedScene,
    );
    final userTurn = PromptBuilder.userTurn(
      c: character,
      history: history,
      privateMode: privateMode,
      replyQuote: replyQuote,
    );
    final turns = [
      ChatTurn('system', system),
      ChatTurn('user', userTurn),
    ];
    final api = ApiClient(config);
    final maxTokens = privateMode ? 480 : 220;
    var raw = '';

    try {
      await for (final delta in api.streamChat(
        turns,
        temperature: _temperature(character.id),
        maxTokens: maxTokens,
      )) {
        if (isCancelled?.call() == true) {
          throw LlmException('已停止', kind: LlmErrorKind.cancelled);
        }
        raw += delta;
        onDelta?.call(raw);
      }
      if (raw.trim().isEmpty) {
        throw LlmException('她陷入了沉默。', kind: LlmErrorKind.empty);
      }
    } on LlmException catch (e) {
      if (e.kind == LlmErrorKind.cancelled) rethrow;
      if (isCancelled?.call() == true) {
        throw LlmException('已停止', kind: LlmErrorKind.cancelled);
      }
      if (raw.trim().isEmpty) {
        // 服务商可能不支持 stream：退回非流式再试一次。
        try {
          raw = await api.chat(
            turns,
            temperature: _temperature(character.id),
            maxTokens: maxTokens,
          );
          onDelta?.call(raw);
        } catch (_) {
          if (settings.demoMode) {
            return _demoReply(character, onDelta, isCancelled, fallback: true);
          }
          throw e;
        }
      } else {
        // 流到一半断了也要把已经说出口的话留住。以前这里直接 rethrow，
        // 半句话会被整个抹掉，聊几句就像“断线不说话”了。
        return ChatReply(
          raw: raw,
          parsed: parseReply(raw, characterName: character.name),
          demo: false,
          fallback: true,
        );
      }
    } catch (e) {
      // 非 LlmException（例如底层 socket/解析错误）也走同一套恢复：
      // 先试非流式；已经有部分内容就保留。
      if (isCancelled?.call() == true) {
        throw LlmException('已停止', kind: LlmErrorKind.cancelled);
      }
      if (raw.trim().isEmpty) {
        try {
          raw = await api.chat(
            turns,
            temperature: _temperature(character.id),
            maxTokens: maxTokens,
          );
          onDelta?.call(raw);
        } catch (_) {
          if (settings.demoMode) {
            return _demoReply(character, onDelta, isCancelled, fallback: true);
          }
          throw e;
        }
      } else {
        return ChatReply(
          raw: raw,
          parsed: parseReply(raw, characterName: character.name),
          demo: false,
          fallback: true,
        );
      }
    }

    if (isCancelled?.call() == true) {
      throw LlmException('已停止', kind: LlmErrorKind.cancelled);
    }
    return ChatReply(
      raw: raw,
      parsed: parseReply(raw, characterName: character.name),
      demo: false,
    );
  }

  Future<ChatReply> _demoReply(
    Character character,
    void Function(String rawSoFar)? onDelta,
    bool Function()? isCancelled, {
    bool fallback = false,
  }) async {
    final line = demo.next(character.id);
    final prefix = '[心情:${line.mood}]'
        '${line.actions.map((a) => '[动作:$a]').join()} ';
    final full = '$prefix${line.text}';
    if (onDelta != null) {
      for (var i = 1; i <= line.text.length; i += 2) {
        if (isCancelled?.call() == true) {
          throw LlmException('已停止', kind: LlmErrorKind.cancelled);
        }
        onDelta(
            '$prefix${line.text.substring(0, i.clamp(0, line.text.length))}');
        await Future<void>.delayed(const Duration(milliseconds: 22));
      }
    }
    if (isCancelled?.call() == true) {
      throw LlmException('已停止', kind: LlmErrorKind.cancelled);
    }
    return ChatReply(
      raw: full,
      parsed: parseReply(full, characterName: character.name),
      demo: true,
      fallback: fallback,
    );
  }

  double _temperature(String id) => switch (id) {
        'grok' => 1.02,
        'claude' => 0.78,
        'gpt' => 0.84,
        'gemini' => 0.94,
        _ => 0.9,
      };
}

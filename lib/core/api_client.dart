import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ChatTurn {
  final String role;
  final String content;
  const ChatTurn(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  const LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  LlmConfig copyWith({String? baseUrl, String? apiKey, String? model}) =>
      LlmConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );

  bool get ready => apiKey.trim().isNotEmpty;
}

enum LlmErrorKind {
  notConfigured,
  unauthorized,
  rateLimited,
  notFound,
  badRequest,
  server,
  timeout,
  network,
  badFormat,
  empty,
  cancelled,
}

class LlmException implements Exception {
  final String message;
  final LlmErrorKind kind;
  final bool retryable;
  final int? statusCode;

  LlmException(
    this.message, {
    this.kind = LlmErrorKind.server,
    this.retryable = false,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class ApiClient {
  final LlmConfig config;

  ApiClient(this.config);

  /// 共享一个 Client，复用 keep-alive，减少每轮聊天的握手开销。
  static final http.Client _client = http.Client();

  Uri get endpoint => normalizeEndpoint(config.baseUrl);

  /// 允许用户填写：
  /// - `https://api.deepseek.com`
  /// - `https://api.openai.com/v1`
  /// - `https://xxx/v1/chat/completions`
  /// 三种形式都归一化到同一个完整 endpoint。
  static Uri normalizeEndpoint(String raw) {
    var base = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (base.isEmpty) base = 'https://api.deepseek.com';
    if (!base.contains('://')) base = 'https://$base';
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final uri = Uri.tryParse(base);
    if (uri == null) {
      throw LlmException('Base URL 格式不对：$raw', kind: LlmErrorKind.badRequest);
    }

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('/chat/completions')) {
      return uri.replace(path: path);
    }
    if (path.endsWith('/v1')) {
      return uri.replace(path: '$path/chat/completions');
    }
    return uri.replace(path: '$path/v1/chat/completions');
  }

  Map<String, Object?> _body(
    List<ChatTurn> messages, {
    required double temperature,
    required int maxTokens,
    required bool stream,
  }) =>
      {
        'model': config.model.trim(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': stream,
        'frequency_penalty': 0.15,
        'presence_penalty': 0.1,
      };

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.apiKey.trim()}',
        'accept': 'application/json, text/event-stream',
      };

  Future<String> chat(
    List<ChatTurn> messages, {
    double temperature = 0.9,
    int maxTokens = 320,
    Duration timeout = const Duration(seconds: 45),
    int retries = 2,
  }) async {
    if (!config.ready) {
      throw LlmException('还没有配置 API Key，去设置页填一下。',
          kind: LlmErrorKind.notConfigured);
    }
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await _client
            .post(
              endpoint,
              headers: _headers,
              body: jsonEncode(_body(messages,
                  temperature: temperature,
                  maxTokens: maxTokens,
                  stream: false)),
            )
            .timeout(timeout);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw _statusError(res.statusCode, res.body);
        }
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final content = _contentOf(data);
        if (content == null || content.trim().isEmpty) {
          throw LlmException('她陷入了沉默（空回复）。',
              kind: LlmErrorKind.empty, retryable: true);
        }
        return content.trim();
      } on LlmException catch (e) {
        if (!e.retryable || attempt >= retries) rethrow;
      } on TimeoutException {
        if (attempt >= retries) {
          throw LlmException('等太久了，模型没有回应（超时）。',
              kind: LlmErrorKind.timeout, retryable: true);
        }
      } on SocketException catch (e) {
        if (attempt >= retries) {
          throw LlmException('网络连接失败，检查网络或代理。(${e.osError?.message ?? ''})',
              kind: LlmErrorKind.network, retryable: true);
        }
      } on http.ClientException catch (e) {
        if (attempt >= retries) {
          throw LlmException('网络请求失败：${e.message}',
              kind: LlmErrorKind.network, retryable: true);
        }
      } on FormatException {
        throw LlmException('返回内容不是 OpenAI 兼容格式。', kind: LlmErrorKind.badFormat);
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    throw LlmException('请求失败。', kind: LlmErrorKind.server, retryable: true);
  }

  /// 流式输出：逐段 yield 正文 delta。调用方取消 StreamSubscription 即可停止。
  Stream<String> streamChat(
    List<ChatTurn> messages, {
    double temperature = 0.9,
    int maxTokens = 320,
    Duration timeout = const Duration(seconds: 60),
  }) async* {
    if (!config.ready) {
      throw LlmException('还没有配置 API Key，去设置页填一下。',
          kind: LlmErrorKind.notConfigured);
    }
    final request = http.Request('POST', endpoint)
      ..headers.addAll(_headers)
      ..body = jsonEncode(_body(messages,
          temperature: temperature, maxTokens: maxTokens, stream: true));

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw LlmException('连接超时。', kind: LlmErrorKind.timeout, retryable: true);
    } on SocketException {
      throw LlmException('网络连接失败，检查网络或代理。',
          kind: LlmErrorKind.network, retryable: true);
    } on http.ClientException catch (e) {
      throw LlmException('网络请求失败：${e.message}',
          kind: LlmErrorKind.network, retryable: true);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw _statusError(response.statusCode, body);
    }

    var sawData = false;
    // 光有连接超时还不够：有些服务商会在流到一半时挂住不关连接，
    // 这时 await for 会永远等下去，整个聊天队列就卡死了。给“多久没有
    // 新内容”也加一个上限，超时就当作可重试的断流处理。
    final lines = response.stream
        .timeout(const Duration(seconds: 30))
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;
        sawData = true;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final delta = _deltaOf(data);
          if (delta != null && delta.isNotEmpty) yield delta;
        } on FormatException {
          continue;
        }
      }
    } on TimeoutException {
      throw LlmException('流式响应超时（30 秒没有新内容）。',
          kind: LlmErrorKind.timeout, retryable: true);
    } on SocketException {
      throw LlmException('网络连接中断。', kind: LlmErrorKind.network,
          retryable: true);
    } on http.ClientException catch (e) {
      throw LlmException('流式响应中断：${e.message}',
          kind: LlmErrorKind.network, retryable: true);
    }
    if (!sawData) {
      throw LlmException('流式接口没有返回数据，可能该服务商不支持 stream。',
          kind: LlmErrorKind.badFormat);
    }
  }

  static String? _contentOf(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is Map) {
      final c = message['content'];
      if (c is String) return c;
      if (c is List) {
        return c
            .whereType<Map>()
            .map((p) => p['text'])
            .whereType<String>()
            .join();
      }
    }
    final text = first['text'];
    if (text is String) return text;
    return null;
  }

  static String? _deltaOf(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is Map) {
      final c = delta['content'];
      if (c is String) return c;
    }
    final text = first['text'];
    if (text is String) return text;
    return null;
  }

  static LlmException _statusError(int code, String body) {
    final brief = body.length <= 160 ? body : '${body.substring(0, 160)}…';
    switch (code) {
      case 400:
        return LlmException('请求被拒绝（400），检查模型名/参数。$brief',
            kind: LlmErrorKind.badRequest, statusCode: code);
      case 401:
      case 403:
        return LlmException('API Key 无效或没有权限（$code）。',
            kind: LlmErrorKind.unauthorized, statusCode: code);
      case 402:
        return LlmException('额度不足（402），去服务商后台看一下。',
            kind: LlmErrorKind.rateLimited, statusCode: code);
      case 404:
        return LlmException('接口地址不对（404）。Base URL 可能多了或少了 /v1，点“测试连接”检查。',
            kind: LlmErrorKind.notFound, statusCode: code);
      case 429:
        return LlmException('请求太频繁或额度用完了（429），稍后再试。',
            kind: LlmErrorKind.rateLimited, retryable: true, statusCode: code);
      default:
        if (code >= 500) {
          return LlmException('服务端错误（$code），稍后再试。$brief',
              kind: LlmErrorKind.server, retryable: true, statusCode: code);
        }
        return LlmException('接口报错 $code：$brief',
            kind: LlmErrorKind.server, statusCode: code);
    }
  }
}

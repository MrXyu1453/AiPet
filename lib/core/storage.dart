import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// 简易 JSON 存储：临时文件 + rename，避免写到一半崩溃把存档写坏。
class JsonStore {
  final Map<String, Future<void>> _queues = {};

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}aining');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(String name) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<dynamic> read(String name) async {
    try {
      final file = await fileFor(name);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, Object? data) {
    final previous = _queues[name] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        final file = await fileFor(name);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(data), flush: true);
        if (await file.exists()) await file.delete();
        await tmp.rename(file.path);
      } catch (_) {
        // 存储失败不应该打断聊天
      }
    });
    _queues[name] = next;
    return next;
  }

  Future<void> delete(String name) async {
    try {
      final file = await fileFor(name);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<String> exportText(String name, String content) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}aining_export');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}

class ChatStorage {
  final JsonStore store;
  ChatStorage([JsonStore? store]) : store = store ?? JsonStore();

  Future<List<ChatMessage>> load({String channel = 'group'}) async {
    // 旧版本用 group_chat.json 存群聊，做一次无损迁移。
    final raw = await store.read('chat_$channel.json') ??
        (channel == 'group' ? await store.read('group_chat.json') : null);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<void> save(List<ChatMessage> messages,
      {String channel = 'group'}) async {
    final trimmed = messages.length > 400
        ? messages.sublist(messages.length - 400)
        : messages;
    await store.write(
      'chat_$channel.json',
      trimmed.map((m) => m.toJson()).toList(),
    );
  }

  Future<void> clear({String channel = 'group'}) =>
      store.delete('chat_$channel.json');

  Future<String> exportMarkdown(
      List<ChatMessage> messages, Map<String, Character> characters) async {
    final b = StringBuffer();
    b.writeln('# AI娘篝火营地 · 聊天记录');
    b.writeln();
    for (final m in messages) {
      final time = '${m.time.month}/${m.time.day} '
          '${m.time.hour.toString().padLeft(2, '0')}:'
          '${m.time.minute.toString().padLeft(2, '0')}';
      if (m.isSystem) {
        b.writeln('> $time · ${m.text}');
        continue;
      }
      final who = m.isUser ? '我' : characters[m.senderId]?.name ?? m.senderId;
      b.writeln('**$who**（$time）${m.mood == null ? '' : ' [${m.mood}]'}');
      if (m.text.trim().isNotEmpty) b.writeln(m.text.trim());
      if (m.isSticker) b.writeln('[表情包]');
      b.writeln();
    }
    final now = DateTime.now();
    return store.exportText(
      '篝火夜话_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.md',
      b.toString(),
    );
  }
}

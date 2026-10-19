import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/storage.dart';
import '../models/models.dart';
import 'characters.dart';

/// 角色设定的读写与导入导出。
///
/// 设计原则：用户的修改永远是“叠加”在官方人设上的补充，不会覆盖掉原始
/// 性格、关系和口头禅。这样既能让每个人自由二创，又不会因为一次编辑把
/// 角色改得面目全非。
class PersonaStore extends ChangeNotifier {
  PersonaStore._();

  static final PersonaStore instance = PersonaStore._();

  static const _fileName = 'personas.json';

  final JsonStore _store = JsonStore();
  Map<String, PersonaOverride> _overrides = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  Map<String, PersonaOverride> get overrides => Map.unmodifiable(_overrides);

  PersonaOverride overrideFor(String id) =>
      _overrides[id] ?? const PersonaOverride();

  bool hasOverride(String id) {
    final o = _overrides[id];
    return o != null && !o.isEmpty;
  }

  Future<void> load() async {
    final raw = await _store.read(_fileName);
    _overrides = _parseOverrides(raw);
    applyPersonaOverrides(_overrides);
    _loaded = true;
    notifyListeners();
  }

  Map<String, PersonaOverride> _parseOverrides(dynamic raw) {
    final out = <String, PersonaOverride>{};
    if (raw is Map) {
      final source = raw['overrides'] is Map ? raw['overrides'] as Map : raw;
      for (final entry in source.entries) {
        final id = entry.key.toString();
        if (characterById(id) == null) continue;
        final value = entry.value;
        if (value is! Map) continue;
        out[id] = PersonaOverride.fromJson(Map<String, dynamic>.from(value));
      }
    }
    out.removeWhere((_, value) => value.isEmpty);
    return out;
  }

  Future<void> save(String characterId, PersonaOverride override) async {
    if (override.isEmpty) {
      _overrides.remove(characterId);
    } else {
      _overrides[characterId] = override;
    }
    applyPersonaOverrides(_overrides);
    notifyListeners();
    // 落盘不阻塞 UI；JsonStore 内部按文件串行写入。
    unawaited(_persist());
  }

  Future<void> reset(String characterId) async {
    if (_overrides.remove(characterId) == null) return;
    applyPersonaOverrides(_overrides);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> resetAll() async {
    if (_overrides.isEmpty) return;
    _overrides.clear();
    applyPersonaOverrides(_overrides);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() => _store.write(_fileName, {
        'version': 1,
        'overrides': _overrides.map((k, v) => MapEntry(k, v.toJson())),
      });

  /// 导出为同时兼容本项目与 SillyTavern Character Card V2 的 JSON。
  ///
  /// GitHub 上的角色卡生态（character-card-spec-v2）用 name / description /
  /// personality / scenario 等字段描述角色；这里把每张卡额外包一层
  /// `data`，并把自己的二创补充放进 `extensions.aining`。
  String buildCardsJson() {
    final cards = <Map<String, dynamic>>[];
    for (final base in kCharacters) {
      final c = characterById(base.id)!;
      final o = _overrides[base.id] ?? const PersonaOverride();
      cards.add({
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': c.name,
          'description': c.personality,
          'personality': c.speakingStyle,
          'scenario': c.relationships,
          'first_mes': c.catchphrases.isEmpty ? '' : c.catchphrases.first,
          'mes_example': c.catchphrases.map((e) => '{{char}}: $e').join('\n'),
          'creator_notes': '${c.title} · AI娘篝火营地',
          'system_prompt': '',
          'post_history_instructions': '',
          'alternate_greetings': const <String>[],
          'character_book': null,
          'tags': ['AI娘', '篝火营地', ...c.likes.take(3)],
          'creator': 'AI娘篝火营地',
          'character_version': '0.7',
          'extensions': {
            'aining': {
              'character_id': c.id,
              'bonds': c.bonds,
              'secret': c.secret,
              'address_as': c.addressAs,
              'tts_pitch': c.ttsPitch,
              'tts_rate': c.ttsRate,
              'override': o.toJson(),
            },
          },
        },
      });
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'AI娘篝火营地',
      'format': 'chara_card_v2 + aining_overrides',
      'version': 1,
      'overrides': _overrides.map((k, v) => MapEntry(k, v.toJson())),
      'cards': cards,
    });
  }

  Future<String> exportCards() async {
    final now = DateTime.now();
    final name = '角色设定卡_${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.json';
    return _store.exportText(name, buildCardsJson());
  }

  /// 导入 JSON：支持本应用导出格式、纯 overrides 映射，以及 Character Card V2。
  Future<PersonaImportResult> importJson(String text) async {
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      return const PersonaImportResult(0, 0, error: '不是合法的 JSON');
    }
    var imported = 0;
    var skipped = 0;
    final next = Map<String, PersonaOverride>.from(_overrides);

    void takeOverride(String id, Map<String, dynamic> json) {
      if (characterById(id) == null) {
        skipped++;
        return;
      }
      final o = PersonaOverride.fromJson(json);
      if (o.isEmpty) {
        skipped++;
        return;
      }
      next[id] = o;
      imported++;
    }

    void takeCard(Map<String, dynamic> card) {
      final payload = card['data'] is Map
          ? Map<String, dynamic>.from(card['data'] as Map)
          : card;
      final extensions = payload['extensions'];
      final aining = extensions is Map ? extensions['aining'] : null;
      var id = '';
      Map<String, dynamic>? overrideJson;
      if (aining is Map) {
        id = (aining['character_id'] ?? '').toString();
        if (aining['override'] is Map) {
          overrideJson = Map<String, dynamic>.from(aining['override'] as Map);
        }
      }
      if (id.isEmpty) {
        final name = (payload['name'] ?? '').toString();
        for (final c in kCharacters) {
          if (c.name == name || c.id == name) {
            id = c.id;
            break;
          }
        }
      }
      if (id.isEmpty) {
        skipped++;
        return;
      }
      if (overrideJson != null) {
        takeOverride(id, overrideJson);
        return;
      }
      final description = (payload['description'] ?? '').toString().trim();
      final personality = (payload['personality'] ?? '').toString().trim();
      final scenario = (payload['scenario'] ?? '').toString().trim();
      if (description.isEmpty && personality.isEmpty && scenario.isEmpty) {
        skipped++;
        return;
      }
      next[id] = PersonaOverride(
        name: (payload['name'] ?? '').toString().trim(),
        personalityAdd: description,
        speakingAdd: personality,
        relationshipAdd: scenario,
      );
      imported++;
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final overrides = map['overrides'];
      if (overrides is Map) {
        for (final e in overrides.entries) {
          final value = e.value;
          if (value is Map) {
            takeOverride(e.key.toString(), Map<String, dynamic>.from(value));
          } else {
            skipped++;
          }
        }
      }
      final cards = map['cards'];
      final hasOverrides = overrides is Map && overrides.isNotEmpty;
      if (cards is List && !hasOverrides) {
        for (final card in cards) {
          if (card is Map) takeCard(Map<String, dynamic>.from(card));
        }
      }
      if (!hasOverrides && cards is! List) {
        // 纯 {id: override} 映射。
        if (map['spec'] == 'chara_card_v2') {
          takeCard(map);
        } else {
          for (final e in map.entries) {
            final value = e.value;
            if (value is Map) {
              takeOverride(e.key.toString(), Map<String, dynamic>.from(value));
            }
          }
        }
      }
    } else if (data is List) {
      for (final card in data) {
        if (card is Map) takeCard(Map<String, dynamic>.from(card));
      }
    } else {
      return const PersonaImportResult(0, 0, error: 'JSON 结构不认识');
    }

    if (imported > 0) {
      _overrides = next;
      applyPersonaOverrides(_overrides);
      notifyListeners();
      unawaited(_persist());
    }
    return PersonaImportResult(imported, skipped);
  }
}

class PersonaImportResult {
  final int imported;
  final int skipped;
  final String? error;

  const PersonaImportResult(this.imported, this.skipped, {this.error});

  String get message {
    if (error != null) return error!;
    if (imported == 0) return '没有读到可用的角色设定';
    return '已导入 $imported 个角色设定${skipped > 0 ? '，跳过 $skipped 个' : ''}';
  }
}

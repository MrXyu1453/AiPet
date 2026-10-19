import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/scenes.dart';

class LlmPreset {
  final String name;
  final String baseUrl;
  final String model;
  final String hint;

  const LlmPreset(this.name, this.baseUrl, this.model, this.hint);
}

const kLlmPresets = <LlmPreset>[
  LlmPreset(
      'DeepSeek', 'https://api.deepseek.com', 'deepseek-chat', '便宜、中文好，默认'),
  LlmPreset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini', '需要海外网络'),
  LlmPreset('Kimi', 'https://api.moonshot.cn/v1', 'moonshot-v1-8k', '长上下文'),
  LlmPreset('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'qwen-plus', '国内直连'),
  LlmPreset('自定义', '', '', '任何 OpenAI 兼容接口'),
];

class SettingsController extends ChangeNotifier {
  static const _kBaseUrl = 'base_url';
  static const _kApiKey = 'api_key';
  static const _kModel = 'model';
  static const _kPerCharModels = 'per_char_models';
  static const _kSpriteStyle = 'sprite_style';
  static const _kNickname = 'nickname';
  static const _kTts = 'tts_enabled';
  static const _kAmbience = 'ambience_enabled';
  static const _kMotion = 'motion_quality';
  static const _kFontScale = 'font_scale';
  static const _kFollowTime = 'follow_time';
  static const _kDemo = 'demo_mode';
  static const _kOnboarding = 'onboarding_done';
  static const _kScene = 'scene_id';
  static const _kAtmosphere = 'atmosphere_enabled';

  late final SharedPreferences _prefs;
  LlmConfig? _cache;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    // 已有 Key 时不要继续挂着“试玩模式”，否则界面会自相矛盾。
    final key = _prefs.getString(_kApiKey)?.trim() ?? '';
    if (key.isNotEmpty && (_prefs.getBool(_kDemo) ?? false)) {
      await _prefs.setBool(_kDemo, false);
    }
    _cache = null;
    notifyListeners();
  }

  LlmConfig get config => _cache ??= LlmConfig(
        baseUrl: _prefs.getString(_kBaseUrl) ?? kLlmPresets.first.baseUrl,
        apiKey: _prefs.getString(_kApiKey) ?? '',
        model: _prefs.getString(_kModel) ?? kLlmPresets.first.model,
      );

  /// 角色专属模型：为空则用全局模型。这是“让 Grok 由 Grok 来演”的入口。
  LlmConfig configFor(String? characterId) {
    final override = characterModels[characterId]?.trim() ?? '';
    final base = config;
    return override.isEmpty ? base : base.copyWith(model: override);
  }

  Map<String, String> get characterModels {
    final raw = _prefs.getString(_kPerCharModels);
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  String get baseUrl => config.baseUrl;
  String get apiKey => config.apiKey;
  String get model => config.model;
  bool get configured => config.apiKey.trim().isNotEmpty;

  bool get demoMode => _prefs.getBool(_kDemo) ?? false;
  bool get onboardingDone => _prefs.getBool(_kOnboarding) ?? false;
  String get nickname {
    final n = _prefs.getString(_kNickname)?.trim() ?? '';
    return n.isEmpty ? '主人' : n;
  }

  /// 'official'（全身立绘）或 'chibi'（Q版）
  String get spriteStyle => _prefs.getString(_kSpriteStyle) ?? 'official';
  bool get ttsEnabled => _prefs.getBool(_kTts) ?? false;
  bool get ambienceEnabled => _prefs.getBool(_kAmbience) ?? true;
  String get motionQuality => _prefs.getString(_kMotion) ?? 'balanced';
  double get fontScale => _prefs.getDouble(_kFontScale) ?? 1.0;
  bool get followTime => _prefs.getBool(_kFollowTime) ?? true;

  /// 当前场景（背景 + 天气 + 提示词里的“眼前”）。
  SceneStyle get scene => sceneFor(_prefs.getString(_kScene) ?? 'campfire');

  /// 是否绘制雪/花瓣/雨等氛围粒子。低配设备可以关掉。
  bool get atmosphereEnabled => _prefs.getBool(_kAtmosphere) ?? true;

  Future<void> saveConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    await _prefs.setString(_kBaseUrl, baseUrl.trim());
    await _prefs.setString(_kApiKey, apiKey.trim());
    await _prefs.setString(_kModel, model.trim());
    if (apiKey.trim().isNotEmpty) {
      await _prefs.setBool(_kDemo, false);
    }
    _cache = null;
    notifyListeners();
  }

  Future<void> applyPreset(LlmPreset preset) async {
    await saveConnection(
      baseUrl: preset.baseUrl,
      apiKey: apiKey,
      model: preset.model,
    );
  }

  Future<void> setCharacterModel(String characterId, String model) async {
    final map = characterModels;
    if (model.trim().isEmpty) {
      map.remove(characterId);
    } else {
      map[characterId] = model.trim();
    }
    await _prefs.setString(_kPerCharModels, jsonEncode(map));
    notifyListeners();
  }

  Future<void> setNickname(String value) async {
    await _prefs.setString(_kNickname, value.trim());
    notifyListeners();
  }

  Future<void> setDemoMode(bool value) async {
    await _prefs.setBool(_kDemo, value);
    notifyListeners();
  }

  Future<void> setOnboardingDone(bool value) async {
    await _prefs.setBool(_kOnboarding, value);
    notifyListeners();
  }

  Future<void> setSpriteStyle(String value) async {
    await _prefs.setString(
        _kSpriteStyle, value == 'chibi' ? 'chibi' : 'official');
    notifyListeners();
  }

  Future<void> toggleSpriteStyle() =>
      setSpriteStyle(spriteStyle == 'official' ? 'chibi' : 'official');

  Future<void> setTts(bool value) async {
    await _prefs.setBool(_kTts, value);
    notifyListeners();
  }

  Future<void> setAmbience(bool value) async {
    await _prefs.setBool(_kAmbience, value);
    notifyListeners();
  }

  Future<void> setMotionQuality(String value) async {
    await _prefs.setString(_kMotion,
        const {'high', 'balanced', 'low'}.contains(value) ? value : 'balanced');
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    await _prefs.setDouble(_kFontScale, value.clamp(0.9, 1.25));
    notifyListeners();
  }

  Future<void> setFollowTime(bool value) async {
    await _prefs.setBool(_kFollowTime, value);
    notifyListeners();
  }

  Future<void> setScene(String id) async {
    final safe = sceneFor(id).id;
    await _prefs.setString(_kScene, safe);
    notifyListeners();
  }

  Future<void> setAtmosphere(bool value) async {
    await _prefs.setBool(_kAtmosphere, value);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    await _prefs.setBool(_kOnboarding, false);
    notifyListeners();
  }
}

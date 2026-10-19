import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';

import '../state/settings_controller.dart';
import 'audio_synth.dart';

enum Sfx { tap, heart, angry, sparkle, note, kick, snare, pluck, shutter }

/// BGM、篝火环境音、交互音效。所有音频都是运行时合成的，没有版权素材。
class AudioService {
  final SettingsController settings;
  AudioService(this.settings);

  ap.AudioPlayer? _bgm;
  ap.AudioPlayer? _ambience;
  final Map<Sfx, ap.AudioPlayer> _sfx = {};
  bool _ambienceOn = false;
  bool _concertOn = false;

  bool get ambienceOn => _ambienceOn;
  bool get concertOn => _concertOn;

  Future<void> startAmbience() async {
    if (_ambienceOn || !settings.ambienceEnabled) return;
    try {
      final file = await AudioSynth.ensureAmbience();
      final player = ap.AudioPlayer();
      _ambience = player;
      await player.setReleaseMode(ap.ReleaseMode.loop);
      await player.setVolume(_concertOn ? 0.08 : 0.22);
      await player.play(ap.DeviceFileSource(file.path));
      _ambienceOn = true;
    } catch (e) {
      debugPrint('ambience failed: $e');
    }
  }

  Future<void> stopAmbience() async {
    _ambienceOn = false;
    try {
      await _ambience?.stop();
      await _ambience?.dispose();
    } catch (_) {}
    _ambience = null;
  }

  Future<void> startConcertBgm() async {
    if (_concertOn) return;
    _concertOn = true;
    try {
      final file = await AudioSynth.ensureCampfireBgm();
      final player = ap.AudioPlayer();
      _bgm = player;
      await player.setReleaseMode(ap.ReleaseMode.loop);
      await player.setVolume(0.52);
      await player.play(ap.DeviceFileSource(file.path));
      await _ambience?.setVolume(0.08);
    } catch (e) {
      debugPrint('bgm failed: $e');
    }
  }

  Future<void> stopConcertBgm() async {
    _concertOn = false;
    try {
      await _bgm?.stop();
      await _bgm?.dispose();
    } catch (_) {}
    _bgm = null;
    await _ambience?.setVolume(0.22);
  }

  Future<void> setConcert(bool on) => on ? startConcertBgm() : stopConcertBgm();

  Future<void> playSfx(Sfx sfx) async {
    try {
      final file = await AudioSynth.ensureSfx(sfx.name);
      final player = _sfx.putIfAbsent(sfx, () => ap.AudioPlayer());
      await player.stop();
      await player.setVolume(sfx == Sfx.kick || sfx == Sfx.snare ? 0.7 : 0.5);
      await player.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('sfx ${sfx.name} failed: $e');
    }
  }

  Future<void> dispose() async {
    await stopConcertBgm();
    await stopAmbience();
    for (final p in _sfx.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _sfx.clear();
  }
}

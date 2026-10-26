import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/coach_lines.dart';
import '../data/store.dart';

/// Spoken guidance from bundled audio (no internet). Plays only while the
/// microphone is off: every screen that starts listening calls [stop] first,
/// so the coach never leaks into the noise calibration or a phrase.
class Coach {
  Coach._();
  static final _instance = Coach._();
  static AppState? _app;

  /// Off in widget tests, which have no audio plugin.
  static bool enabled = true;

  static Coach of(AppState app) {
    _app = app;
    return _instance;
  }

  AudioPlayer? _player; // created on first use: tests have no audio plugin

  Future<void> say(String id) async {
    if (!enabled || _app?.coachOn != true || !coachLines.containsKey(id)) {
      return;
    }
    try {
      final p = _player ??= AudioPlayer();
      await p.stop();
      await p.play(AssetSource('coach/$id.mp3'));
    } catch (e) {
      debugPrint('coach: $e');
    }
  }

  /// Stops any coach audio right away (before the microphone starts).
  static Future<void> stop() async {
    try {
      await _instance._player?.stop();
    } catch (_) {}
  }
}

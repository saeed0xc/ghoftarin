import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Streams the microphone as 16 kHz mono samples in -1..1.
/// Automatic gain, echo cancellation and noise suppression are turned off,
/// because they would flatten the very loudness rise we measure.
class Mic {
  final _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  int _carry = -1; // odd byte left over from the previous chunk

  Future<bool> ensurePermission() => _rec.hasPermission();

  Future<void> start(void Function(List<double> samples) onSamples) async {
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
    ));
    _carry = -1;
    _sub = stream.listen((bytes) => onSamples(_toSamples(bytes)));
  }

  List<double> _toSamples(Uint8List bytes) {
    final out = <double>[];
    var i = 0;
    if (_carry >= 0 && bytes.isNotEmpty) {
      out.add(_s16(_carry, bytes[0]));
      i = 1;
      _carry = -1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      out.add(_s16(bytes[i], bytes[i + 1]));
    }
    if (i < bytes.length) _carry = bytes[i];
    return out;
  }

  static double _s16(int lo, int hi) {
    var v = (hi << 8) | lo;
    if (v >= 0x8000) v -= 0x10000;
    return v / 32768.0;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _rec.isRecording()) await _rec.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _rec.dispose();
  }
}

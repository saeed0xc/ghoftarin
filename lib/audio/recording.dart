import 'dart:typed_data';

/// Keeps the session audio in memory (16 kHz mono, 16-bit) so the user can
/// listen back right after the session. Nothing is written to disk or sent.
class SessionRecording {
  static const sampleRate = 16000;
  static const maxSeconds = 300; // 5 minutes, ~9.6 MB

  final _chunks = <Int16List>[];
  int _length = 0;

  int get lengthSamples => _length;
  double get seconds => _length / sampleRate;

  void add(List<double> samples) {
    if (_length >= maxSeconds * sampleRate) return;
    final c = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).round();
      c[i] = v > 32767 ? 32767 : (v < -32768 ? -32768 : v);
    }
    _chunks.add(c);
    _length += c.length;
  }

  void clear() {
    _chunks.clear();
    _length = 0;
  }

  /// A WAV file of the whole recording, or of [fromSec, toSec].
  Uint8List toWav({double? fromSec, double? toSec}) {
    final from = ((fromSec ?? 0) * sampleRate).round().clamp(0, _length);
    final to = ((toSec ?? seconds) * sampleRate).round().clamp(from, _length);
    final n = to - from;
    final bytes = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    bytes.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bytes.setUint32(40, n * 2, Endian.little);
    var pos = 0, o = 44;
    for (final c in _chunks) {
      for (var i = 0; i < c.length; i++, pos++) {
        if (pos < from) continue;
        if (pos >= to) break;
        bytes.setInt16(o, c[i], Endian.little);
        o += 2;
      }
      if (pos >= to) break;
    }
    return bytes.buffer.asUint8List();
  }
}

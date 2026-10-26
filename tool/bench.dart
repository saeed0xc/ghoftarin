// ignore_for_file: avoid_print
// Engine throughput: seconds of audio processed per second of CPU.
import 'dart:io';
import 'dart:typed_data';

import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/data/content.dart';

List<double> readWav(String path) {
  final b = File(path).readAsBytesSync();
  final bd = ByteData.sublistView(b);
  var i = 12;
  while (i < b.length - 8) {
    final id = String.fromCharCodes(b.sublist(i, i + 4));
    final size = bd.getUint32(i + 4, Endian.little);
    if (id == 'data') {
      return [
        for (var k = i + 8; k + 1 < i + 8 + size; k += 2)
          bd.getInt16(k, Endian.little) / 32768.0,
      ];
    }
    i += 8 + size;
  }
  throw StateError('no data');
}

void main() {
  final a = readWav('test/fixtures/tts-amir-fan.wav');
  final p = passageById('morning');
  final sw = Stopwatch()..start();
  var n = 0;
  for (var rep = 0; rep < 5; rep++) {
    final e = FluencyEngine(syllables: p.syllables, onPhrase: (_) => n++)
      ..start();
    for (var i = 0; i < a.length; i += 320) {
      e.addSamples(a.sublist(i, i + 320 > a.length ? a.length : i + 320));
    }
  }
  final audioSec = 5 * a.length / 16000;
  final cpu = sw.elapsedMilliseconds / 1000;
  print(
    'audio ${audioSec.toStringAsFixed(1)} s, cpu ${cpu.toStringAsFixed(2)} s, realtime x${(audioSec / cpu).toStringAsFixed(0)}, phrases $n',
  );
}

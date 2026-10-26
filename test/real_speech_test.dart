// Real Persian speech (synthesised with two different TTS voices) with known
// phrase boundaries, in a quiet room and with a loud low-frequency fan.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/data/content.dart';

List<double> readWav(String path) {
  final b = File(path).readAsBytesSync();
  final bd = ByteData.sublistView(b);
  // find "data" chunk
  var i = 12;
  while (i < b.length - 8) {
    final id = String.fromCharCodes(b.sublist(i, i + 4));
    final size = bd.getUint32(i + 4, Endian.little);
    if (id == 'data') {
      final out = <double>[];
      for (var k = i + 8; k + 1 < i + 8 + size; k += 2) {
        out.add(bd.getInt16(k, Endian.little) / 32768.0);
      }
      return out;
    }
    i += 8 + size;
  }
  throw StateError('no data chunk');
}

void main() {
  final p = passageById('morning');
  for (final name in [
    'tts-amir-quiet',
    'tts-amir-fan',
    'tts-haaniye-quiet',
    'tts-haaniye-fan',
  ]) {
    test('finds all 7 phrases and their starts: $name', () {
      final truth = File('test/fixtures/$name.txt')
          .readAsLinesSync()
          .map((l) => l.split(' ').map(double.parse).toList())
          .toList();
      final rs = <PhraseResult>[];
      final e = FluencyEngine(syllables: p.syllables, onPhrase: rs.add)
        ..start();
      final a = readWav('test/fixtures/$name.wav');
      for (var i = 0; i < a.length; i += 1600) {
        e.addSamples(a.sublist(i, i + 1600 > a.length ? a.length : i + 1600));
      }
      expect(rs.length, 7);
      for (var i = 0; i < 7; i++) {
        // quiet room: within 50 ms; fan at 14 dB SNR (speech band): within 200 ms,
        // since the first part of a soft start is genuinely under the noise
        final tol = name.endsWith('quiet') ? 0.05 : 0.2;
        expect(
          rs[i].startSec,
          closeTo(truth[i][0], tol),
          reason: 'start of phrase $i',
        );
        if (i > 0) {
          final truePause = truth[i][0] - truth[i - 1][1];
          expect(
            rs[i].pauseSec,
            closeTo(truePause, tol + 0.1),
            reason: 'pause $i',
          );
        }
      }
      // phrases 2 and 5 were given short pauses (1.0 s and 1.2 s)
      expect(rs.map((r) => r.early).toList(), [
        false,
        false,
        true,
        false,
        false,
        true,
        false,
      ]);
    });
  }

  for (final name in ['tts-amir-loud', 'tts-haaniye-loud']) {
    test('flags a very noisy room: $name', () {
      final e = FluencyEngine(syllables: const [1, 1, 1, 1, 1, 1, 1])..start();
      e.addSamples(readWav('test/fixtures/$name.wav').sublist(0, 16000 * 2));
      expect(e.noisyRoom, true);
    });
  }
  test('a quiet room is not flagged', () {
    final e = FluencyEngine(syllables: const [1])..start();
    e.addSamples(
      readWav('test/fixtures/tts-amir-quiet.wav').sublist(0, 16000 * 2),
    );
    expect(e.noisyRoom, false);
  });
}

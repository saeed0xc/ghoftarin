// The lesson's example clips must be classified the way the lesson says.
import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';

import 'real_speech_test.dart' show readWav;

OnsetClass classify(String path) {
  final rs = <PhraseResult>[];
  final e = FluencyEngine(
    config: const EngineConfig(sampleRate: 22050, calibrationMs: 200),
    syllables: const [3],
    onPhrase: rs.add,
  )..start();
  e.addSamples([...List.filled(22050, 0.0005), ...readWav(path), ...List.filled(22050, 0.0005)]);
  expect(rs.length, 1, reason: path);
  return rs.first.onset;
}

void main() {
  test('soft example is soft, hard example is hard', () {
    expect(classify('assets/audio/onset-soft.wav'), OnsetClass.soft);
    expect(classify('assets/audio/onset-hard.wav'), OnsetClass.hard);
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';

/// Synthetic speech: noise floor, then phrases with a linear loudness ramp.
List<double> synth(List<List<num>> plan, {int sr = 16000, double lead = 2.0}) {
  final rnd = math.Random(7);
  final out = <double>[];
  void silence(double sec) {
    for (var i = 0; i < (sec * sr).round(); i++) {
      out.add((rnd.nextDouble() - 0.5) * 0.004);
    }
  }

  silence(lead);
  for (final p in plan) {
    final pause = p[0].toDouble(), dur = p[1].toDouble(), riseMs = p[2].toDouble();
    silence(pause);
    final n = (dur * sr).round(), rise = riseMs / 1000 * sr;
    for (var k = 0; k < n; k++) {
      final a = math.min(1.0, k / math.max(1.0, rise)) * math.min(1.0, (n - k) / (0.12 * sr));
      final t = k / sr;
      out.add(0.35 * a * (math.sin(2 * math.pi * 150 * t) + 0.5 * math.sin(4 * math.pi * 150 * t)) +
          (rnd.nextDouble() - 0.5) * 0.004);
    }
  }
  silence(1.5);
  return out;
}

void main() {
  test('measures pauses, onsets and rate on synthetic phrases', () {
    // [pause s, duration s, ramp ms]
    final plan = [
      [2.4, 1.4, 260], // soft
      [2.5, 1.4, 40], // hard
      [1.0, 1.2, 220], // early start, soft
      [2.3, 1.5, 120], // medium
    ];
    final results = <PhraseResult>[];
    final e = FluencyEngine(syllables: const [8, 10, 11, 16], onPhrase: results.add)..start();
    final audio = synth(plan);
    // feed in uneven chunks, like a microphone stream
    for (var i = 0; i < audio.length; i += 1777) {
      e.addSamples(audio.sublist(i, math.min(audio.length, i + 1777)));
    }

    expect(results.length, 4);
    expect(e.state, EngineState.done);

    // first pause is measured from the end of the 1.5 s calibration
    expect(results[0].pauseSec, closeTo(2.0 + 2.4 - 1.5, 0.08));
    for (var i = 1; i < 4; i++) {
      // later pauses include the ramp-down tail (~0.1 s) of the previous phrase
      expect(results[i].pauseSec, closeTo(plan[i][0].toDouble(), 0.15), reason: 'pause $i');
    }
    expect(results.map((r) => r.early).toList(), [false, false, true, false]);
    expect(results.map((r) => r.onset).toList(),
        [OnsetClass.soft, OnsetClass.hard, OnsetClass.soft, OnsetClass.medium]);
    // a linear ramp's 10-90% time is 80% of the ramp
    expect(results[0].riseMs, closeTo(0.8 * 260, 30));
    expect(results[1].riseMs, lessThan(60));
    expect(results[0].syllablesPerSec, closeTo(8 / 1.4, 0.6));

    final s = SessionSummary.of(results);
    expect(s.softCount, 2);
    expect(s.pauseOkCount, 3);
  });

  test('ignores a short cough during the pause', () {
    final results = <PhraseResult>[];
    final e = FluencyEngine(syllables: const [8], onPhrase: results.add)..start();
    // cough of 0.12 s, then a real phrase 2.5 s after calibration ends
    final audio = synth([
      [0.5, 0.12, 5],
      [2.0, 1.4, 220],
    ]);
    e.addSamples(audio);
    expect(results.length, 1);
    expect(results[0].onset, OnsetClass.soft);
  });

  test('riseTime of a linear ramp', () {
    final env = List<double>.generate(60, (i) => i < 10 ? 0 : math.min(1.0, (i - 10) / 20));
    // 20 hops of 10 ms ramp -> 10..90% = 16 hops = 160 ms
    expect(riseTime(env, 10, 10, 0), closeTo(160, 12));
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';

import 'real_speech_test.dart' show readWav;

const sr = 16000;
final _rnd = math.Random(11);

void silence(List<double> out, double sec) {
  for (var i = 0; i < (sec * sr).round(); i++) {
    out.add((_rnd.nextDouble() - 0.5) * 0.004);
  }
}

/// Speech-like voicing: pitch and loudness change every ~120 ms (syllables).
void speech(List<double> out, double sec, {double f0 = 140, double ramp = 0.2}) {
  final n = (sec * sr).round();
  var phase = 0.0;
  for (var k = 0; k < n; k++) {
    final t = k / sr;
    final syl = (t / 0.12).floor();
    final f = f0 * (1 + 0.12 * math.sin(syl * 1.7) + 0.04 * math.sin(t * 9));
    phase += 2 * math.pi * f / sr;
    final amp = math.min(1.0, k / (ramp * sr)) * math.min(1.0, (n - k) / (0.08 * sr)) *
        (0.6 + 0.4 * math.sin(2 * math.pi * 4.2 * t).abs());
    out.add(0.3 * amp * (math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase)));
  }
}

/// A held sound: constant pitch and loudness.
void held(List<double> out, double sec, {double f0 = 140}) {
  final n = (sec * sr).round();
  for (var k = 0; k < n; k++) {
    final ph = 2 * math.pi * f0 * k / sr;
    final amp = math.min(1.0, k / (0.15 * sr));
    out.add(0.3 * amp * (math.sin(ph) + 0.5 * math.sin(2 * ph) + 0.25 * math.sin(3 * ph)));
  }
}

PhraseResult runOne(List<double> audio) {
  final rs = <PhraseResult>[];
  final e = FluencyEngine(syllables: const [8], onPhrase: rs.add)..start();
  e.addSamples(audio);
  expect(rs.length, 1);
  return rs.first;
}

void main() {
  test('fluent speech-like phrase: no events', () {
    final a = <double>[];
    silence(a, 2.5);
    speech(a, 1.6);
    silence(a, 1.5);
    final r = runOne(a);
    expect(r.disfluencies.total, 0);
    expect(r.disfluencyReliable, true);
  });

  test('sound repetition: three short bursts before the word', () {
    final a = <double>[];
    silence(a, 2.5);
    for (var i = 0; i < 3; i++) {
      speech(a, 0.12, ramp: 0.02);
      silence(a, 0.15);
    }
    speech(a, 1.4);
    silence(a, 1.5);
    expect(runOne(a).disfluencies.repetitions, 1);
  });

  test('prolongation: a sound held for 0.8 s at the start', () {
    final a = <double>[];
    silence(a, 2.5);
    held(a, 0.8);
    speech(a, 1.4);
    silence(a, 1.5);
    final d = runOne(a).disfluencies;
    expect(d.prolongations, 1);
    expect(d.repetitions, 0);
  });

  test('block: a 0.45 s silence inside the phrase', () {
    final a = <double>[];
    silence(a, 2.5);
    speech(a, 0.6);
    silence(a, 0.45);
    speech(a, 1.0);
    silence(a, 1.5);
    expect(runOne(a).disfluencies.blocks, 1);
  });

  test('phrase-final lengthening is not a prolongation', () {
    final a = <double>[];
    silence(a, 2.5);
    speech(a, 1.2);
    held(a, 0.4);
    silence(a, 1.5);
    expect(runOne(a).disfluencies.prolongations, 0);
  });

  test('real fluent Persian speech: no events in a quiet room; noisy room marked unreliable', () {
    for (final name in ['tts-amir-quiet', 'tts-haaniye-quiet']) {
      final rs = <PhraseResult>[];
      final e = FluencyEngine(syllables: const [10, 11, 9, 14, 14, 11, 10], onPhrase: rs.add)..start();
      e.addSamples(readWav('test/fixtures/$name.wav'));
      expect(rs.fold<int>(0, (s, r) => s + r.disfluencies.total), 0, reason: name);
      expect(rs.every((r) => r.disfluencyReliable), true, reason: name);
    }
    for (final name in ['tts-amir-fan', 'tts-haaniye-fan']) {
      final rs = <PhraseResult>[];
      final e = FluencyEngine(syllables: const [10, 11, 9, 14, 14, 11, 10], onPhrase: rs.add)..start();
      e.addSamples(readWav('test/fixtures/$name.wav'));
      expect(rs.where((r) => !r.disfluencyReliable).length, greaterThanOrEqualTo(5), reason: name);
    }
  });

  test('real Persian speech with an inserted sound repetition and block', () {
    final rs = <PhraseResult>[];
    final e = FluencyEngine(syllables: const [10, 11, 9, 14, 14, 11, 10], onPhrase: rs.add)..start();
    e.addSamples(readWav('test/fixtures/tts-amir-disfluent.wav'));
    expect(rs.length, 7);
    final per = rs.map((r) => '${r.disfluencies.repetitions}/${r.disfluencies.prolongations}/${r.disfluencies.blocks}').toList();
    expect(per, ['0/0/0', '0/0/0', '1/0/0', '0/0/0', '0/0/1', '0/0/0', '0/0/0']);
  });
}

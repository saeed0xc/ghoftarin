// Speech timing engine: pause before speaking, soft onset, speech rate.
//
// Pure Dart, no Flutter imports, so it runs in unit tests with synthetic audio.
// Time comes from the sample count (not the wall clock), so results are exact
// and repeatable.
//
// Definitions (same as the web demo, tuned later with the therapist):
// - pause: from the last voiced frame of the previous phrase (or the end of
//   calibration) to the first voiced frame of the next phrase;
// - onset rise: time for the loudness envelope to go from 10% to 90% of its
//   early peak (first 450 ms of the phrase); longer = softer;
// - rate: known syllable count of the phrase / phrase duration.

import 'dart:math' as math;

enum EngineState { idle, calibrating, pausing, speaking, done }

enum OnsetClass { soft, medium, hard }

class EngineConfig {
  /// Target silence before each phrase, in seconds.
  final double waitTarget;
  final int sampleRate;
  final int windowMs;
  final int hopMs;
  final int calibrationMs;
  final int minOnMs; // voiced this long before a phrase counts as started
  final int endMs; // silence this long ends a phrase
  final int minPhraseMs; // shorter voiced bursts (cough, click) are ignored
  final double softMs; // rise >= softMs  -> soft
  final double hardMs; // rise <  hardMs  -> hard
  final double onFactor; // voiced when rms > noise * onFactor
  final double offFactor; // silent when rms < noise * offFactor

  const EngineConfig({
    this.waitTarget = 2.0,
    this.sampleRate = 16000,
    this.windowMs = 20,
    this.hopMs = 10,
    this.calibrationMs = 1500,
    this.minOnMs = 50,
    this.endMs = 900,
    this.minPhraseMs = 250,
    this.softMs = 150,
    this.hardMs = 90,
    this.onFactor = 3.5,
    this.offFactor = 2.2,
  });

  EngineConfig copyWith({double? waitTarget}) => EngineConfig(
        waitTarget: waitTarget ?? this.waitTarget,
        sampleRate: sampleRate,
        windowMs: windowMs,
        hopMs: hopMs,
        calibrationMs: calibrationMs,
        minOnMs: minOnMs,
        endMs: endMs,
        minPhraseMs: minPhraseMs,
        softMs: softMs,
        hardMs: hardMs,
        onFactor: onFactor,
        offFactor: offFactor,
      );
}

class PhraseResult {
  final int index;
  final double pauseSec;
  final bool early; // pause shorter than the target
  final double riseMs;
  final OnsetClass onset;
  final double durationSec;
  final double? syllablesPerSec;
  final List<double> onsetEnvelope; // for drawing the onset wave

  const PhraseResult({
    required this.index,
    required this.pauseSec,
    required this.early,
    required this.riseMs,
    required this.onset,
    required this.durationSec,
    required this.syllablesPerSec,
    required this.onsetEnvelope,
  });

  Map<String, dynamic> toJson() => {
        'i': index,
        'p': _r(pauseSec, 2),
        'e': early,
        'r': _r(riseMs, 0),
        'o': onset.index,
        'd': _r(durationSec, 2),
        if (syllablesPerSec != null) 's': _r(syllablesPerSec!, 2),
      };

  factory PhraseResult.fromJson(Map<String, dynamic> j) => PhraseResult(
        index: j['i'] as int,
        pauseSec: (j['p'] as num).toDouble(),
        early: j['e'] as bool,
        riseMs: (j['r'] as num).toDouble(),
        onset: OnsetClass.values[j['o'] as int],
        durationSec: (j['d'] as num).toDouble(),
        syllablesPerSec: (j['s'] as num?)?.toDouble(),
        onsetEnvelope: const [],
      );

  static double _r(double v, int d) {
    final f = math.pow(10, d);
    return (v * f).roundToDouble() / f;
  }
}

OnsetClass classifyOnset(double riseMs, EngineConfig c) {
  if (riseMs >= c.softMs) return OnsetClass.soft;
  if (riseMs < c.hardMs) return OnsetClass.hard;
  return OnsetClass.medium;
}

/// 10%→90% rise time (ms) of [env] (one value per hop) starting near [start].
double riseTime(List<double> env, int start, double hopMs, double floor) {
  if (env.isEmpty) return 0;
  final from = math.max(0, start - (60 / hopMs).round());
  final end = math.min(env.length, start + (450 / hopMs).round());
  if (from >= end) return 0;
  var peak = 0.0;
  var peakIdx = from;
  for (var i = from; i < end; i++) {
    if (env[i] > peak) {
      peak = env[i];
      peakIdx = i;
    }
  }
  final span = peak - floor;
  if (span <= 0) return 0;
  var i10 = -1, i90 = -1;
  for (var i = from; i <= peakIdx; i++) {
    final v = env[i] - floor;
    if (i10 < 0 && v >= 0.1 * span) i10 = i;
    if (v >= 0.9 * span) {
      i90 = i;
      break;
    }
  }
  if (i10 < 0 || i90 < 0) return 0;
  // linear interpolation at both crossings for sub-hop precision
  double cross(int i, double level) {
    if (i <= from) return i.toDouble();
    final a = env[i - 1] - floor, b = env[i] - floor;
    if (b == a) return i.toDouble();
    return (i - 1) + (level - a) / (b - a);
  }

  final t10 = cross(i10, 0.1 * span), t90 = cross(i90, 0.9 * span);
  return math.max(0, (t90 - t10) * hopMs);
}

/// Streaming engine. Feed PCM samples (-1..1) with [addSamples]; listen to
/// [onState] and [onPhrase].
class FluencyEngine {
  EngineConfig config;
  final List<int> syllables; // per phrase; empty or 0 = unknown
  final int? phraseTotal; // number of phrases; defaults to syllables.length
  void Function(EngineState state, double pauseElapsedSec)? onState;
  void Function(PhraseResult result)? onPhrase;
  void Function(double level)? onLevel; // 0..1 meter, every hop

  FluencyEngine({
    this.config = const EngineConfig(),
    this.syllables = const [],
    this.phraseTotal,
    this.onState,
    this.onPhrase,
    this.onLevel,
  }) {
    _win = config.sampleRate * config.windowMs ~/ 1000;
    _hop = config.sampleRate * config.hopMs ~/ 1000;
    _ring = List<double>.filled(_win, 0);
  }

  late final int _win;
  late final int _hop;
  late final List<double> _ring;
  int _ringPos = 0;
  int _filled = 0;
  int _sinceHop = 0;
  int _hopIndex = 0; // number of hops processed

  EngineState state = EngineState.idle;
  double noise = 0.002;
  final List<double> _calib = [];
  int _lastVoiceHop = 0;
  int _candHop = -1;
  int _onsetHop = 0;
  int _voicedEndHop = 0;
  final List<double> _env = []; // envelope around the current onset
  int _envStartHop = 0;
  int phraseIndex = 0;
  final List<PhraseResult> results = [];

  double get _hopMs => config.hopMs.toDouble();
  double _hopsToSec(int h) => h * _hopMs / 1000;

  void start() {
    state = EngineState.calibrating;
    _calib.clear();
    results.clear();
    phraseIndex = 0;
    _hopIndex = 0;
    _filled = 0;
    _sinceHop = 0;
    onState?.call(state, 0);
  }

  void stop() {
    state = EngineState.idle;
  }

  /// Drops the last phrase (e.g. it was split by a long block, or the user
  /// wants to read it again) and waits for that phrase again.
  PhraseResult? undoLast() {
    if (results.isEmpty) return null;
    final r = results.removeLast();
    phraseIndex = r.index;
    if (state == EngineState.done || state == EngineState.pausing) _enterPause();
    return r;
  }

  /// Total phrases expected; when reached the engine moves to [EngineState.done].
  int get phraseCount => phraseTotal ?? (syllables.isEmpty ? 1 << 30 : syllables.length);

  void addSamples(List<double> samples) {
    for (final s in samples) {
      _ring[_ringPos] = s;
      _ringPos = (_ringPos + 1) % _win;
      if (_filled < _win) _filled++;
      _sinceHop++;
      if (_sinceHop >= _hop && _filled == _win) {
        _sinceHop = 0;
        _processHop(_rms());
      }
    }
  }

  double _rms() {
    var sum = 0.0;
    for (final v in _ring) {
      sum += v * v;
    }
    return math.sqrt(sum / _win);
  }

  void _processHop(double v) {
    final h = _hopIndex++;
    onLevel?.call(math.min(1.0, v / math.max(noise * 30, 0.05)));
    switch (state) {
      case EngineState.idle:
      case EngineState.done:
        return;
      case EngineState.calibrating:
        _calib.add(v);
        if (_calib.length * _hopMs >= config.calibrationMs) {
          final sorted = [..._calib]..sort();
          noise = math.max(sorted[sorted.length ~/ 2], 0.002);
          _lastVoiceHop = h;
          _enterPause();
        }
        return;
      case EngineState.pausing:
        final on = v > math.max(noise * config.onFactor, 0.006);
        final off = v < math.max(noise * config.offFactor, 0.004);
        if (off) {
          // slow, bounded tracking of the room noise while silent
          noise = noise * 0.995 + math.min(v, noise * 1.5) * 0.005;
        }
        _pushEnv(v, h);
        onState?.call(state, _hopsToSec(h - _lastVoiceHop));
        if (on) {
          if (_candHop < 0) _candHop = h;
          if ((h - _candHop + 1) * _hopMs >= config.minOnMs) _beginSpeech(h);
        } else {
          _candHop = -1;
        }
        return;
      case EngineState.speaking:
        final off = v < math.max(noise * config.offFactor, 0.004);
        if (h - _onsetHop < (500 / _hopMs)) _env.add(v);
        if (!off) {
          _voicedEndHop = h;
        } else if ((h - _voicedEndHop) * _hopMs > config.endMs) {
          _endPhrase();
        }
        return;
    }
  }

  // keep ~100 ms of envelope before an onset
  void _pushEnv(double v, int h) {
    _env.add(v);
    final keep = (100 / _hopMs).round();
    if (_env.length > keep) {
      _env.removeAt(0);
    }
    _envStartHop = h - _env.length + 1;
  }

  void _enterPause() {
    state = EngineState.pausing;
    _candHop = -1;
    _env.clear();
    onState?.call(state, 0);
  }

  void _beginSpeech(int h) {
    _onsetHop = _candHop;
    _voicedEndHop = h;
    state = EngineState.speaking;
    onState?.call(state, _hopsToSec(_onsetHop - _lastVoiceHop));
  }

  void _endPhrase() {
    final durHops = _voicedEndHop - _onsetHop + 1;
    if (durHops * _hopMs < config.minPhraseMs) {
      // a cough or click: ignore it, keep the pause clock from before
      state = EngineState.pausing;
      _candHop = -1;
      onState?.call(state, _hopsToSec(_hopIndex - _lastVoiceHop));
      return;
    }
    final pause = _hopsToSec(_onsetHop - _lastVoiceHop);
    final rise = riseTime(_env, _onsetHop - _envStartHop, _hopMs, noise);
    final dur = _hopsToSec(durHops);
    final syl = phraseIndex < syllables.length && syllables[phraseIndex] > 0 ? syllables[phraseIndex] : null;
    final r = PhraseResult(
      index: phraseIndex,
      pauseSec: pause,
      early: pause < config.waitTarget,
      riseMs: rise,
      onset: classifyOnset(rise, config),
      durationSec: dur,
      syllablesPerSec: syl == null ? null : syl / dur,
      onsetEnvelope: List<double>.unmodifiable(_env),
    );
    results.add(r);
    onPhrase?.call(r);
    _lastVoiceHop = _voicedEndHop;
    phraseIndex++;
    if (phraseIndex >= phraseCount) {
      state = EngineState.done;
      onState?.call(state, 0);
    } else {
      _enterPause();
    }
  }
}

/// Summary over a set of phrases (a session or an assessment).
class SessionSummary {
  final int phrases;
  final int softCount;
  final int pauseOkCount;
  final double medianPause;
  final double? meanRate;

  const SessionSummary(
      {required this.phrases,
      required this.softCount,
      required this.pauseOkCount,
      required this.medianPause,
      required this.meanRate});

  double get softRatio => phrases == 0 ? 0 : softCount / phrases;
  double get pauseRatio => phrases == 0 ? 0 : pauseOkCount / phrases;

  factory SessionSummary.of(List<PhraseResult> rs) {
    if (rs.isEmpty) {
      return const SessionSummary(
          phrases: 0, softCount: 0, pauseOkCount: 0, medianPause: 0, meanRate: null);
    }
    final pauses = rs.map((r) => r.pauseSec).toList()..sort();
    final rates = rs.map((r) => r.syllablesPerSec).whereType<double>().toList();
    return SessionSummary(
      phrases: rs.length,
      softCount: rs.where((r) => r.onset == OnsetClass.soft).length,
      pauseOkCount: rs.where((r) => !r.early).length,
      medianPause: pauses[pauses.length ~/ 2],
      meanRate: rates.isEmpty ? null : rates.reduce((a, b) => a + b) / rates.length,
    );
  }
}

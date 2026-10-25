// Acoustic signs of possible disfluencies inside one phrase, from the 10 ms
// hop track of the engine. These are heuristics based on how the events look
// in the signal; they are an experimental, objective estimate to show next to
// the user's self-rating, NOT a diagnosis or a %SS count.
//
// - repetition: two or more very short voiced bursts (≤ 250 ms) separated by
//   short silences, before the word continues ("پ-پ-پدر", "من-من-من");
// - prolongation: one sound held steady (same pitch and loudness) for
//   ≥ 450 ms, not at the end of the phrase (phrase-final lengthening is
//   normal);
// - block: a silence of ≥ 300 ms inside the phrase.

class HopInfo {
  final bool on; // above the room-noise threshold
  final bool periodic; // voiced
  final int lag; // pitch period in samples (0 = none)
  final double energy;
  const HopInfo(this.on, this.periodic, this.lag, this.energy);
}

class DisfluencyCounts {
  final int repetitions;
  final int prolongations;
  final int blocks;
  const DisfluencyCounts(this.repetitions, this.prolongations, this.blocks);
  int get total => repetitions + prolongations + blocks;
  static const zero = DisfluencyCounts(0, 0, 0);
  DisfluencyCounts operator +(DisfluencyCounts o) => DisfluencyCounts(
    repetitions + o.repetitions,
    prolongations + o.prolongations,
    blocks + o.blocks,
  );
}

DisfluencyCounts detectDisfluencies(List<HopInfo> hops, {double hopMs = 10}) {
  if (hops.isEmpty) return DisfluencyCounts.zero;
  int ms(double x) => (x / hopMs).round();

  // voiced segments, bridging gaps shorter than 80 ms (stop-consonant closures)
  final segs = <List<int>>[];
  int? start;
  var lastOn = -1;
  for (var i = 0; i < hops.length; i++) {
    if (hops[i].on) {
      if (start == null) {
        start = i;
      } else if (i - lastOn - 1 >= ms(80)) {
        segs.add([start, lastOn]);
        start = i;
      }
      lastOn = i;
    }
  }
  if (start != null) segs.add([start, lastOn]);

  // blocks: long silences inside the phrase
  var blocks = 0;
  for (var k = 1; k < segs.length; k++) {
    if (segs[k][0] - segs[k - 1][1] - 1 >= ms(300)) blocks++;
  }

  // repetitions: runs of ≥ 2 short bursts with short gaps, followed by more speech
  var reps = 0;
  var k = 0;
  while (k < segs.length - 1) {
    var run = 0;
    var j = k;
    while (j < segs.length - 1) {
      final len = segs[j][1] - segs[j][0] + 1;
      final gap = segs[j + 1][0] - segs[j][1] - 1;
      if (len <= ms(250) && gap <= ms(250)) {
        run++;
        j++;
      } else {
        break;
      }
    }
    if (run >= 2) {
      // similar burst lengths: repeated sound or syllable
      final lens = [
        for (var q = k; q < k + run; q++) segs[q][1] - segs[q][0] + 1,
      ];
      final mx = lens.reduce((a, b) => a > b ? a : b),
          mn = lens.reduce((a, b) => a < b ? a : b);
      if (mx <= 2.5 * mn) reps++;
      k = j;
    } else {
      k++;
    }
  }

  // prolongations: steady pitch and loudness for ≥ 450 ms, not phrase-final
  var prol = 0;
  final lastAllowed = hops.length - ms(500);
  var runStart = -1;
  var refLag = 0;
  var refEnergy = 0.0;
  void close(int end) {
    if (runStart >= 0 && end - runStart >= ms(450) && runStart < lastAllowed) {
      prol++;
    }
    runStart = -1;
  }

  for (var i = 0; i < hops.length; i++) {
    final h = hops[i];
    final ok = h.periodic && h.lag > 0 && h.energy > 0;
    if (ok &&
        runStart >= 0 &&
        (h.lag - refLag).abs() <= (refLag * 0.06).ceil() &&
        (h.energy / refEnergy - 1).abs() <= 0.3) {
      continue; // still the same steady sound
    }
    close(i);
    if (ok) {
      runStart = i;
      refLag = h.lag;
      refEnergy = h.energy;
    }
  }
  close(hops.length);

  return DisfluencyCounts(reps, prol, blocks);
}

/// Daily word lessons: the core of the first two weeks. Every day brings a
/// new set of words, ordered from easy starts to hard ones, each said
/// stretched (prolonged speech) and with a soft start.
library;

import '../audio/engine.dart';
import 'word_bank.dart';

class BankWord {
  final String text;
  final int syllables;

  /// How the word starts: 0 = vowel or h (easiest soft start),
  /// 1 = continuant (s, sh, f, z, m, n, l, r, v, y, kh, gh),
  /// 2 = plosive or affricate (p, b, t, d, k, g, q, j, ch).
  final int start;
  const BankWord(this.text, this.syllables, this.start);
}

/// Number of word days in unit 1.
const wordDays = 14;
const wordsPerLesson = 14;

class _DayRule {
  final String title;
  final Set<int> starts;
  final int minSyl, maxSyl;
  final bool phrases;
  const _DayRule(
    this.title,
    this.starts,
    this.minSyl,
    this.maxSyl, {
    this.phrases = false,
  });
}

/// Two days per step, easy to hard.
const _rules = <_DayRule>[
  _DayRule('شروع با صدای باز', {0}, 1, 2),
  _DayRule('صداهای کشیدنی', {1}, 1, 2),
  _DayRule('کلمه‌های دوهجایی', {0, 1}, 2, 3),
  _DayRule('صداهای انفجاری کوتاه', {2}, 1, 2),
  _DayRule('صداهای انفجاری بلندتر', {2}, 2, 3),
  _DayRule('کلمه‌های بلند', {0, 1, 2}, 3, 6),
  _DayRule('عبارت‌های کوتاه', {0, 1, 2}, 1, 9, phrases: true),
];

/// A stable shuffle, so every user gets the same order and no word repeats
/// until the bank is used up.
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

List<BankWord> _ordered(Iterable<BankWord> ws) =>
    ws.toList()..sort((a, b) => _hash(a.text).compareTo(_hash(b.text)));

String wordDayTitle(int day) =>
    day < wordDays ? _rules[day ~/ 2].title : 'گرم کردن با کلمه';

/// The 14 word days, built once: each day takes the first unused words of
/// its step, so no word repeats across the two weeks.
final List<List<BankWord>> _days = () {
  final used = <String>{};
  final days = <List<BankWord>>[];
  for (var d = 0; d < wordDays; d++) {
    final r = _rules[d ~/ 2];
    final pool = _ordered(
      (r.phrases ? phraseBank : wordBank).where(
        (w) =>
            r.starts.contains(w.start) &&
            w.syllables >= r.minSyl &&
            w.syllables <= r.maxSyl &&
            !used.contains(w.text),
      ),
    ).take(wordsPerLesson).toList();
    used.addAll(pool.map((w) => w.text));
    days.add(pool);
  }
  return days;
}();

/// The words for word-day [day] (0-based). Days 0–13 follow the easy-to-hard
/// steps without repeating a word; later days are short warm-ups that walk
/// through the whole bank.
List<BankWord> wordsForDay(int day, {int count = wordsPerLesson}) {
  if (day < wordDays) return _days[day].take(count).toList();
  final pool = _ordered(wordBank.where((w) => w.syllables <= 3));
  final start = ((day - wordDays) * count) % pool.length;
  return [for (var i = 0; i < count; i++) pool[(start + i) % pool.length]];
}

/// Prolonged speech: each syllable drawn out to at least ~0.45 s (normal
/// speech is about 0.2 s per syllable), and a single word at least 0.6 s.
const stretchSecPerSyllable = 0.45;

bool isStretched(PhraseResult r, int syllables) =>
    r.durationSec >= (syllables * stretchSecPerSyllable).clamp(0.6, 99);

bool isSoft(PhraseResult r) => r.onset == OnsetClass.soft;

/// 1–3 stars for a lesson from the share of items said soft and stretched
/// (first tries only).
int starsFor(double goodShare) =>
    goodShare >= 0.9 ? 3 : (goodShare >= 0.7 ? 2 : 1);

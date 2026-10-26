import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/data/content.dart';
import 'package:goftarin/data/guide.dart';
import 'package:goftarin/data/words.dart';
import 'package:goftarin/fa.dart';

void main() {
  test('every passage has one syllable count per phrase', () {
    for (final p in passages) {
      expect(p.syllables.length, p.phrases.length, reason: p.id);
    }
  });

  test('jalali date conversion', () {
    expect(toJalali(2026, 10, 25), [1405, 8, 3]);
    expect(toJalali(2025, 3, 21), [1404, 1, 1]);
    expect(toJalali(2024, 3, 20), [1403, 1, 1]);
    expect(faDate(DateTime(2026, 10, 25)), 'یکشنبه ۳ آبان');
  });

  test('persian digits', () {
    expect(faNum(2.06, 1), '۲٫۱');
    expect(faPercent(0.78), '۷۸٪');
  });

  test('confidence score', () {
    expect(confidenceScore([5, 1, 1, 1, 5]), 100);
    expect(confidenceScore([1, 5, 5, 5, 1]), 0);
  });

  test('word ladder interleaves the chosen sounds', () {
    final p = ladderStep(['p', 'a'], 0);
    expect(p.phrases.take(4).toList(), ['پدر', 'آب', 'پنجره', 'امروز']);
    expect(p.phrases.length, 8);
    expect(p.syllables.every((s) => s == 0), true);
    expect(ladderStep(['sh'], 2).phrases.length, 2);
    for (final g in soundGroups) {
      for (final w in [...g.words, ...g.phrases, ...g.sentences]) {
        expect(w.trim().isNotEmpty, true);
      }
    }
  });

  test('guide pages have unique ids', () {
    final ids = guidePages.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in [
      'pause',
      'soft',
      'contact',
      'continuous',
      'therapist',
      'parents',
    ]) {
      expect(ids.contains(id), true, reason: id);
    }
  });

  test('hand-counted syllables are plausible for every passage', () {
    for (final p in [...passages, slowPassage]) {
      expect(p.syllables.length, p.phrases.length, reason: p.id);
      for (var i = 0; i < p.phrases.length; i++) {
        final letters = p.phrases[i]
            .replaceAll(RegExp(r'[\s\u200c.،؛:!؟?«»]'), '')
            .length;
        final perSyl = letters / p.syllables[i];
        expect(
          perSyl,
          inInclusiveRange(1.3, 3.6),
          reason: '${p.id} #$i: ${p.phrases[i]}',
        );
      }
    }
  });

  test('daily reading rotates through at least five texts for adults', () {
    final seen = {
      for (var d = 0; d < 14; d++)
        passageForDay(DateTime(2026, 10, 1 + d), child: false).id,
    };
    expect(seen.length, greaterThanOrEqualTo(5));
    expect(seen.contains('pishi'), isFalse);
  });
}

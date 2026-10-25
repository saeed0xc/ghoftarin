import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/data/content.dart';
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
}

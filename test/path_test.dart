import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/data/partner_scenes.dart';
import 'package:goftarin/data/path.dart';
import 'package:goftarin/data/story.dart';
import 'package:goftarin/data/store.dart';
import 'package:goftarin/data/word_bank.dart';
import 'package:goftarin/data/word_lessons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

PhraseResult said(double dur, {bool soft = true}) => PhraseResult(
  index: 0,
  pauseSec: 1.5,
  early: false,
  riseMs: soft ? 180 : 50,
  onset: soft ? OnsetClass.soft : OnsetClass.hard,
  durationSec: dur,
  syllablesPerSec: null,
  onsetEnvelope: const [],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the word bank is large and has no duplicates', () {
    final texts = wordBank.map((w) => w.text).toList();
    expect(texts.length, greaterThan(1000));
    expect(texts.toSet().length, texts.length);
  });

  test('two weeks of word days: new words every day, easy to hard', () {
    final seen = <String>{};
    for (var d = 0; d < wordDays; d++) {
      final ws = wordsForDay(d);
      expect(ws.length, wordsPerLesson, reason: 'day $d');
      for (final w in ws) {
        expect(seen.add(w.text), isTrue, reason: '${w.text} repeats on day $d');
      }
    }
    // the first days start with a vowel or h; plosives come later
    expect(wordsForDay(0).every((w) => w.start == 0), isTrue);
    expect(wordsForDay(6).every((w) => w.start == 2), isTrue);
    // later warm-ups keep changing
    expect(
      wordsForDay(20, count: 8).first.text,
      isNot(wordsForDay(21, count: 8).first.text),
    );
  });

  test('stretched means about half a second per syllable', () {
    expect(isStretched(said(0.5), 1), isFalse);
    expect(isStretched(said(0.7), 1), isTrue);
    expect(isStretched(said(1.0), 3), isFalse);
    expect(isStretched(said(1.4), 3), isTrue);
    expect(starsFor(0.95), 3);
    expect(starsFor(0.75), 2);
    expect(starsFor(0.3), 1);
  });

  test('the path: words for two weeks, then book, then the partner', () {
    expect(nodeAt(0, lessonsDone: false).parts.map((p) => p.kind), [
      PartKind.lessons,
      PartKind.words,
    ]);
    expect(nodeAt(13).parts.map((p) => p.kind), [PartKind.words]);
    expect(nodeAt(14).parts.map((p) => p.kind), [
      PartKind.words,
      PartKind.book,
    ]);
    expect(nodeAt(21).parts.map((p) => p.kind), [
      PartKind.book,
      PartKind.partner,
    ]);
    // every day the next half page of the story
    expect(bookPassage(nodeAt(15).parts.last.index).id, 'kafe-2');
    expect(bookPassage(nodeAt(22).parts.first.index).id, 'kafe-9');
    // after the story, other texts keep coming
    expect(bookPassage(storyEpisodes.length).id, isNot(startsWith('kafe')));
    // partner scenes go from easy to hard
    expect(partnerScene(0).level, 1);
    expect(partnerScene(partnerScenes.length - 1).level, 3);
  });

  test('a weak unit is reviewed before the next one opens', () async {
    final app = AppState();
    for (var i = 0; i < 14; i++) {
      await app.completeNode(i, i < 8 ? 1 : 3); // only 6 of 14 with 2+ stars
    }
    var cur = currentNode(app.pathStars);
    expect(cur.review, isTrue);
    expect(app.pathStars[cur.index], 1);
    // reviews raise the weak nodes until two thirds have 2+ stars
    while (currentNode(app.pathStars).review) {
      cur = currentNode(app.pathStars);
      await app.completeNode(cur.index, 2, review: true);
    }
    expect(currentNode(app.pathStars).index, 14);
    expect(app.pathStars.where((s) => s >= 2).length, greaterThanOrEqualTo(10));
  });

  test('a good unit goes straight on', () async {
    final app = AppState();
    for (var i = 0; i < 14; i++) {
      await app.completeNode(i, 2);
    }
    final cur = currentNode(app.pathStars);
    expect(cur.review, isFalse);
    expect(cur.index, 14);
    expect(app.totalStars, 28);
  });

  test('path stars survive a backup round trip', () async {
    final app = AppState();
    await app.completeNode(0, 3);
    final other = AppState();
    expect(await other.importBackup(app.exportBackup()), isTrue);
    expect(other.pathStars, [3]);
  });

  test('every partner line has its audio file', () {
    for (final s in partnerScenes) {
      expect(s.turns.length, greaterThanOrEqualTo(4), reason: s.id);
      for (var i = 0; i < s.turns.length; i++) {
        expect(
          File('assets/${s.audio(i)}').existsSync(),
          isTrue,
          reason: s.audio(i),
        );
      }
    }
  });

  test(
    'story episodes are about half a page and syllable counts are plausible',
    () {
      expect(storyEpisodes.length, greaterThanOrEqualTo(30));
      for (final e in storyEpisodes) {
        final words = e.phrases.join(' ').split(RegExp(r'\s+')).length;
        expect(words, inInclusiveRange(60, 160), reason: e.id);
        for (var i = 0; i < e.phrases.length; i++) {
          final letters = e.phrases[i]
              .replaceAll(RegExp(r'[\s‌.،؛:!؟?«»]'), '')
              .length;
          expect(
            letters / e.syllables[i],
            inInclusiveRange(1.3, 3.6),
            reason: '${e.id} #$i',
          );
        }
      }
    },
  );
}

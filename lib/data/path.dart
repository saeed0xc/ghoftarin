/// The learning path: one node per day, unlocked step by step.
///
/// Unit 1 (14 nodes): stretched, soft words — a new set every day.
/// Unit 2 (7 nodes): a short word warm-up, then the next half page of the
///   daily story.
/// Unit 3 (endless): the next half page, then a conversation-partner scene —
///   the main exercise from here on.
///
/// To leave a unit, at least two thirds of its nodes need 2 or more stars;
/// otherwise the next node is a review of the weakest one.
library;

import 'content.dart';
import 'partner.dart';
import 'partner_scenes.dart';
import 'story.dart';
import 'word_lessons.dart';

enum PartKind { lessons, words, book, partner }

class Part {
  final PartKind kind;
  final int index; // word day, story episode or scene index
  const Part(this.kind, this.index);
}

class UnitInfo {
  final int n;
  final String title;
  final String sub;
  final int first; // first node index
  final int? last; // last node index (inclusive); null = endless
  const UnitInfo(this.n, this.title, this.sub, this.first, this.last);
  bool contains(int node) => node >= first && (last == null || node <= last!);
  int get length => last == null ? 0 : last! - first + 1;
}

const units = <UnitInfo>[
  UnitInfo(
    1,
    'کلمه‌های نرم و کشیده',
    'هر روز کلمه‌های تازه؛ کشیده و با شروع نرم',
    0,
    13,
  ),
  UnitInfo(
    2,
    'کتاب روزانه',
    'گرم کردن با کلمه، بعد نیم صفحه‌ی تازه از داستان',
    14,
    20,
  ),
  UnitInfo(3, 'هم‌صحبت', 'نیم صفحه داستان و یک گفت‌وگوی واقعی', 21, null),
];

UnitInfo unitOf(int node) => units.firstWhere((u) => u.contains(node));

/// A reading passage for a book part: the story in order, then the other
/// texts once the story is finished.
Passage bookPassage(int episode) {
  if (episode < storyEpisodes.length) return storyEpisodes[episode];
  final rest = passages.where((p) => p.audience != 'child').toList();
  return rest[(episode - storyEpisodes.length) % rest.length];
}

Scene partnerScene(int i) => scenesByLevel[i % partnerScenes.length];

class PathNode {
  final int index;
  final List<Part> parts;
  final bool review;
  const PathNode(this.index, this.parts, {this.review = false});

  PartKind get mainKind => parts.last.kind;

  String get title => switch (parts.last.kind) {
    PartKind.lessons || PartKind.words => wordDayTitle(parts.last.index),
    PartKind.book => bookPassage(parts.last.index).title,
    PartKind.partner => partnerScene(parts.last.index).title,
  };

  int get minutes => parts.fold(
    0,
    (m, p) =>
        m +
        switch (p.kind) {
          PartKind.lessons => 4,
          PartKind.words => p.index < wordDays ? 4 : 2,
          PartKind.book => 4,
          PartKind.partner => 4,
        },
  );
}

/// The content of node [i] (0-based).
PathNode nodeAt(int i, {bool lessonsDone = true}) {
  if (i < 14) {
    return PathNode(i, [
      if (i == 0 && !lessonsDone) const Part(PartKind.lessons, 0),
      Part(PartKind.words, i),
    ]);
  }
  if (i < 21) {
    return PathNode(i, [Part(PartKind.words, i), Part(PartKind.book, i - 14)]);
  }
  return PathNode(i, [
    Part(PartKind.book, i - 14),
    Part(PartKind.partner, i - 21),
  ]);
}

/// Whether the unit holding node [unitLast] was passed well enough to go on.
bool unitPassed(List<int> stars, UnitInfo u) {
  if (u.last == null) return true;
  final got = [
    for (var i = u.first; i <= u.last! && i < stars.length; i++) stars[i],
  ];
  if (got.length < u.length) return false;
  return got.where((s) => s >= 2).length * 3 >= u.length * 2;
}

/// The node the user should do next: the next new one, or a review of the
/// weakest node when a unit was finished with too few stars.
PathNode currentNode(List<int> stars, {bool lessonsDone = true}) {
  final next = stars.length;
  for (final u in units) {
    if (u.last != null && next == u.last! + 1 && !unitPassed(stars, u)) {
      var worst = u.first;
      for (var i = u.first; i <= u.last!; i++) {
        if (stars[i] < stars[worst]) worst = i;
      }
      final n = nodeAt(worst, lessonsDone: true);
      return PathNode(worst, n.parts, review: true);
    }
  }
  return nodeAt(next, lessonsDone: lessonsDone);
}

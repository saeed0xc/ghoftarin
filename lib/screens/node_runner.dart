import 'package:flutter/material.dart';

import '../data/path.dart';
import '../data/store.dart';
import '../data/word_lessons.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'lessons.dart';
import 'partner_screen.dart';
import 'practice.dart';
import 'word_lesson.dart';

/// Runs every part of a path node in order, then saves its stars and shows
/// the celebration. Leaving any part early leaves the node unfinished.
Future<void> runNode(BuildContext context, AppState app, PathNode node) async {
  final scores = <double>[];
  for (final part in node.parts) {
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    switch (part.kind) {
      case PartKind.lessons:
        await nav.push(
          MaterialPageRoute(
            builder: (_) => LessonsScreen(app: app, startPracticeAfter: false),
          ),
        );
        if (!app.lessonsDone) return;
      case PartKind.words:
        final s = await nav.push<double>(
          MaterialPageRoute(
            builder: (_) => WordLessonScreen(
              app: app,
              day: part.index,
              count: part.index < wordDays ? wordsPerLesson : 8,
            ),
          ),
        );
        if (s == null) return;
        scores.add(s);
      case PartKind.book:
        final before = app.sessions.length;
        await nav.push(
          MaterialPageRoute(
            builder: (_) =>
                PracticeScreen(app: app, passage: bookPassage(part.index)),
          ),
        );
        if (app.sessions.length == before) return;
        final m = app.sessions.last.summary;
        scores.add(m.phrases == 0 ? 0 : (m.softRatio + m.pauseRatio) / 2);
      case PartKind.partner:
        final s = await nav.push<double>(
          MaterialPageRoute(
            builder: (_) =>
                PartnerScreen(app: app, scene: partnerScene(part.index)),
          ),
        );
        if (s == null) return;
        scores.add(s);
    }
  }
  final avg = scores.isEmpty
      ? 1.0
      : scores.reduce((a, b) => a + b) / scores.length;
  final stars = starsFor(avg);
  await app.completeNode(node.index, stars, review: node.review);
  if (!context.mounted) return;
  Coach.of(app).say('day_done');
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) => _Celebrate(app: app, node: node, stars: stars),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Celebrate extends StatelessWidget {
  final AppState app;
  final PathNode node;
  final int stars;
  const _Celebrate({
    required this.app,
    required this.node,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            StarRow(stars: stars, size: 72),
            const SizedBox(height: 20),
            Text(
              node.review
                  ? 'مرور انجام شد!'
                  : 'درس ${faNum(node.index + 1)} کامل شد!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: C.goldDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              node.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: C.muted),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.local_fire_department,
                    color: C.warm,
                    value: faNum(app.streak),
                    label: 'روز پشت سر هم',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    icon: Icons.star_rounded,
                    color: C.gold,
                    value: faNum(app.totalStars),
                    label: 'همه‌ی ستاره‌ها',
                  ),
                ),
              ],
            ),
            const Spacer(),
            ChunkyButton(
              label: 'ادامه',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 13, color: C.muted)),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/program.dart';
import '../data/store.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import 'lessons.dart';
import 'monologue.dart';
import 'practice.dart';
import 'situations.dart';
import 'words.dart';

/// Pause used in the slow practice round: clearly longer than the daily
/// target, so the technique can be exaggerated.
double slowWait(AppState app) => (app.waitTarget + 0.8).clamp(2.6, 3.0);

Widget screenFor(AppState app, PlanStep step) => switch (step.kind) {
  StepKind.lessons => LessonsScreen(app: app, startPracticeAfter: false),
  StepKind.slow => PracticeScreen(
    app: app,
    passage: slowPassage,
    overrideWait: slowWait(app),
  ),
  StepKind.read => PracticeScreen(
    app: app,
    passage: passageForDay(DateTime.now(), child: app.forChild),
  ),
  StepKind.words => WordsScreen(app: app),
  StepKind.talk => MonologueScreen(app: app, minutes: app.stage >= 4 ? 3 : 1),
  StepKind.situation => SituationsScreen(app: app),
};

/// Runs one step of today's plan, then: moves the user up a stage when its
/// criteria are met, or offers the next step.
Future<void> runStep(BuildContext context, AppState app, PlanStep step) async {
  if (step.kind == StepKind.situation) Coach.of(app).say('situation_intro');
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screenFor(app, step)));
  if (!context.mounted) return;
  final plan = todayPlan(app);
  final nowDone = step.kind == StepKind.lessons
      ? app.lessonsDone
      : plan.any((s) => s.kind == step.kind && s.done);
  final newStage = await maybeAdvance(app);
  if (!context.mounted) return;
  if (newStage != null) {
    Coach.of(app).say('stage_$newStage');
    await showStageUp(context, newStage);
    return;
  }
  if (!nowDone) return; // the user left early: no nagging
  final next = plan.where((s) => !s.done).firstOrNull;
  if (next == null) {
    Coach.of(app).say('day_done');
    return;
  }
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'این قدم انجام شد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'قدم بعد: ${next.title}${next.minutes > 0 ? ' · حدود ${faNum(next.minutes)} دقیقه' : ''}',
            style: const TextStyle(fontSize: 15, height: 1.8, color: C.muted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ادامه'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('بعداً'),
          ),
        ],
      ),
    ),
  );
  if (go == true && context.mounted) await runStep(context, app, next);
}

Future<void> showStageUp(BuildContext context, int stage) {
  final s = stageInfo(stage);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.emoji_events_outlined, color: C.warm, size: 40),
      title: Text(
        'مرحله‌ی ${faNum(stage)}: ${s.name}',
        textAlign: TextAlign.center,
      ),
      content: Text(
        'معیارهای مرحله‌ی قبل را با اندازه‌گیری خود اپ رد کردی.\n${s.goal}.',
        textAlign: TextAlign.center,
        style: const TextStyle(height: 1.8),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('بزن بریم'),
        ),
      ],
    ),
  );
}

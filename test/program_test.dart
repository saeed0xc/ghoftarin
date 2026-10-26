import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/data/program.dart';
import 'package:goftarin/data/situations.dart';
import 'package:goftarin/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PhraseResult phrase(int i, {required bool soft, required bool paused}) =>
    PhraseResult(
      index: i,
      pauseSec: paused ? 2.2 : 0.4,
      early: !paused,
      riseMs: soft ? 180 : 60,
      onset: soft ? OnsetClass.soft : OnsetClass.hard,
      durationSec: 1.5,
      syllablesPerSec: 4,
      onsetEnvelope: const [],
    );

SessionRecord session(
  DateTime d,
  String kind, {
  double soft = 1,
  double pause = 1,
  int n = 8,
}) => SessionRecord(
  date: d,
  passageId: 'x',
  waitTarget: 2.0,
  kind: kind,
  results: [
    for (var i = 0; i < n; i++)
      phrase(i, soft: i < (soft * n).round(), paused: i < (pause * n).round()),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final day0 = DateTime(2026, 10, 1, 20);
  DateTime day(int n) => day0.add(Duration(days: n));

  test('a new user starts with the lessons, then slow practice and words', () {
    final app = AppState();
    final plan = todayPlan(app, now: day(0));
    expect(plan.map((s) => s.kind), [
      StepKind.lessons,
      StepKind.slow,
      StepKind.words,
    ]);
    expect(planMinutes(plan), 10);
  });

  test(
    'stage 1 completes after lessons and three good slow days, not two',
    () async {
      final app = AppState()..lessonsDone = true;
      app.sessions.add(session(day(0), Kind.slow));
      app.sessions.add(
        session(day(0).add(const Duration(hours: 1)), Kind.slow),
      ); // same day
      app.sessions.add(session(day(1), Kind.words));
      expect(stageComplete(app), isFalse);
      app.sessions.add(
        session(day(2), Kind.slow, soft: 0.5),
      ); // not good enough
      expect(stageComplete(app), isFalse);
      app.sessions.add(session(day(3), Kind.slow));
      expect(stageComplete(app), isTrue);
      expect(await maybeAdvance(app), 2);
      expect(app.stage, 2);
      // criteria restart in the new stage
      expect(criteria(app).first.have, 0);
    },
  );

  test('sessions with too few phrases never count as meeting the bar', () {
    expect(meetsBar(session(day(0), Kind.slow, n: 3)), isFalse);
    expect(meetsBar(session(day(0), Kind.slow, n: 5)), isTrue);
  });

  test(
    'stage 2 needs five days, three good readings in a row and a shorter pause',
    () {
      final app = AppState()
        ..lessonsDone = true
        ..stage = 2
        ..stageSince = day(0);
      for (var i = 0; i < 5; i++) {
        app.sessions.add(session(day(i), Kind.read));
      }
      expect(stageComplete(app), isFalse, reason: 'pause target still 2.0');
      app.waitTarget = 1.6;
      expect(stageComplete(app), isTrue);
      app.sessions.add(session(day(6), Kind.read, soft: 0.4));
      expect(
        stageComplete(app),
        isFalse,
        reason: 'the last three must all be good',
      );
    },
  );

  test('two poor sessions in a row put a slow round first in the plan', () {
    final app = AppState()
      ..lessonsDone = true
      ..stage = 3
      ..stageSince = day(0);
    app.sessions.add(session(day(1), Kind.read, soft: 0.3));
    expect(todayPlan(app, now: day(2)).first.kind, StepKind.read);
    app.sessions.add(session(day(1), Kind.talk, pause: 0.2));
    final plan = todayPlan(app, now: day(2));
    expect(plan.map((s) => s.kind), [
      StepKind.slow,
      StepKind.read,
      StepKind.talk,
      StepKind.situation,
    ]);
  });

  test('done steps are marked for today only', () {
    final app = AppState()
      ..lessonsDone = true
      ..stage = 2;
    app.sessions.add(session(day(1), Kind.read));
    expect(
      todayPlan(
        app,
        now: day(1),
      ).firstWhere((s) => s.kind == StepKind.read).done,
      isTrue,
    );
    expect(
      todayPlan(
        app,
        now: day(2),
      ).firstWhere((s) => s.kind == StepKind.read).done,
      isFalse,
    );
  });

  test('stage 3 counts real situations done, not avoided ones', () {
    final app = AppState()
      ..lessonsDone = true
      ..stage = 3
      ..stageSince = day(0);
    for (var i = 0; i < 3; i++) {
      app.sessions.add(session(day(i), Kind.talk, pause: 0));
      app.situationLogs.add(
        SituationLog(
          date: day(i),
          situationId: 'greet',
          anxietyBefore: 5,
          anxietyAfter: 3,
          severity: 3,
          avoided: i == 2,
        ),
      );
    }
    expect(criteria(app).map((c) => c.have), [3, 2]);
    expect(stageComplete(app), isFalse);
  });

  test('only reading sessions move the pause target', () async {
    final app = AppState();
    for (var i = 0; i < 3; i++) {
      await app.addSession(session(day(i), Kind.talk));
    }
    expect(app.waitTarget, 2.0);
    for (var i = 0; i < 3; i++) {
      await app.addSession(session(day(i), Kind.read));
    }
    expect(app.waitTarget, 1.8);
  });

  test('backup round-trips and a broken backup changes nothing', () async {
    final app = AppState()
      ..stage = 3
      ..lessonsDone = true;
    app.sessions.add(session(day(0), Kind.talk));
    final text = 'پشتیبان گفتارین\n${app.exportBackup()}';
    final other = AppState();
    expect(await other.importBackup(text), isTrue);
    expect(other.stage, 3);
    expect(other.sessions.single.kind, Kind.talk);
    expect(
      await other.importBackup(
        '{"app":"goftarin","data":{"sessions":[{"bad":1}]}}',
      ),
      isFalse,
    );
    expect(other.sessions.length, 1);
    expect(await other.importBackup('hello'), isFalse);
  });
}

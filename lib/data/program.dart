/// The self-guided program: four stages, each with a daily plan and
/// measured criteria for moving on. Modelled on the structure of
/// self-administered fluency programs (learn the technique, practise it to a
/// criterion, carry it into real speaking, then keep it), with the rule from
/// Camperdown that a poor day sends you back to slow practice first.
library;

import '../fa.dart';
import 'situations.dart';
import 'store.dart';

enum StepKind { lessons, slow, read, words, talk, situation }

class PlanStep {
  final StepKind kind;
  final String title;
  final String sub;
  final int minutes; // 0 = during the day, not timed
  final bool done;
  const PlanStep(this.kind, this.title, this.sub, this.minutes, this.done);
}

class StageInfo {
  final int n;
  final String name;
  final String goal;
  const StageInfo(this.n, this.name, this.goal);
}

const stages = <StageInfo>[
  StageInfo(1, 'پایه', 'یاد گرفتن مکث و شروع نرم با تمرین آهسته'),
  StageInfo(
    2,
    'تمرین روزانه',
    'نرم و آرام خواندن، با مکثی که کم‌کم طبیعی می‌شود',
  ),
  StageInfo(3, 'انتقال', 'بردن همین روش به صحبت آزاد و موقعیت‌های واقعی'),
  StageInfo(4, 'نگهداری', 'نگه داشتن روانی با تمرین کوتاه و منظم'),
];

StageInfo stageInfo(int n) => stages[(n - 1).clamp(0, 3)];

/// One measurable condition for leaving a stage.
class Criterion {
  final String label;
  final int have;
  final int need;
  const Criterion(this.label, this.have, this.need);
  bool get met => have >= need;
  double get progress => need == 0 ? 1 : (have / need).clamp(0.0, 1.0);
}

/// Thresholds. A session "meets the bar" when its starts were soft and its
/// pauses long enough in most phrases.
const softBar = 0.8, pauseBar = 0.8, talkSoftBar = 0.7;
const minPhrases = 5;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool meetsBar(
  SessionRecord s, {
  double soft = softBar,
  double pause = pauseBar,
}) {
  final m = s.summary;
  return m.phrases >= minPhrases &&
      m.softRatio >= soft &&
      m.pauseRatio >= pause;
}

Iterable<SessionRecord> _inStage(AppState app) {
  final since = app.stageSince;
  return since == null
      ? app.sessions
      : app.sessions.where((s) => !s.date.isBefore(since));
}

int _days(Iterable<SessionRecord> ss) =>
    ss.map((s) => _day(s.date)).toSet().length;

/// The criteria for leaving the user's current stage. Stage 4 has none.
List<Criterion> criteria(AppState app) {
  final ss = _inStage(app).toList();
  switch (app.stage) {
    case 1:
      return [
        Criterion('آموزش کوتاه', app.lessonsDone ? 1 : 0, 1),
        Criterion(
          'روزهای تمرین آهسته‌ی موفق',
          _days(
            ss.where(
              (s) =>
                  (s.kind == Kind.slow || s.kind == Kind.words) && meetsBar(s),
            ),
          ),
          3,
        ),
      ];
    case 2:
      final reads = ss.where((s) => s.kind == Kind.read).toList();
      final last3 = reads.length < 3 ? reads : reads.sublist(reads.length - 3);
      return [
        Criterion('روزهای تمرین در این مرحله', _days(ss), 5),
        Criterion(
          'سه خواندن آخر، هر کدام ۸۰٪ نرم و با مکث کافی',
          last3.where(meetsBar).length,
          3,
        ),
        // the pause target shrinks by itself after good sessions: 2.0 → 1.6
        Criterion(
          'مکث طبیعی‌تر (هدف ۱٫۶ ثانیه یا کمتر)',
          app.waitTarget <= 1.6 + 1e-9 ? 1 : 0,
          1,
        ),
      ];
    case 3:
      final since = app.stageSince;
      final logs = app.situationLogs.where(
        (l) => !l.avoided && (since == null || !l.date.isBefore(since)),
      );
      return [
        Criterion(
          'روزهای صحبت آزاد با ۷۰٪ شروع نرم',
          _days(
            ss.where(
              (s) =>
                  s.kind == Kind.talk &&
                  meetsBar(s, soft: talkSoftBar, pause: 0),
            ),
          ),
          3,
        ),
        Criterion('موقعیت‌های واقعی انجام‌شده', logs.length, 3),
      ];
    default:
      return const [];
  }
}

bool stageComplete(AppState app) {
  final c = criteria(app);
  return c.isNotEmpty && c.every((x) => x.met);
}

/// Camperdown's rule: when real speaking goes poorly, go back to slow,
/// exaggerated practice before trying again. True when both of the last two
/// sessions (of any kind except slow) fell well short.
bool needsSlowDay(AppState app) {
  final recent = app.sessions
      .where((s) => s.kind != Kind.slow && s.summary.phrases >= minPhrases)
      .toList();
  if (recent.length < 2) return false;
  final last2 = recent.sublist(recent.length - 2);
  return last2.every((s) {
    final m = s.summary;
    return m.softRatio < 0.5 || m.pauseRatio < 0.5;
  });
}

bool _doneToday(AppState app, String kind, DateTime now) =>
    app.sessions.any((s) => s.kind == kind && _day(s.date) == _day(now));

/// Today's plan for the user's stage, in the order to do it.
List<PlanStep> todayPlan(AppState app, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final steps = <PlanStep>[];
  final slowDone = _doneToday(app, Kind.slow, t);

  void slow(String sub) =>
      steps.add(PlanStep(StepKind.slow, 'تمرین آهسته', sub, 3, slowDone));
  void read() => steps.add(
    PlanStep(
      StepKind.read,
      'خواندن کتاب',
      'مکث پیش از هر عبارت، شروع نرم · و خودارزیابی امروز',
      4,
      _doneToday(app, Kind.read, t),
    ),
  );
  void words() => steps.add(
    PlanStep(
      StepKind.words,
      'تمرین کلمه',
      app.wordGroups.isEmpty
          ? 'صداهایی که برایت سخت‌ترند'
          : 'پله‌ی بعدی نردبان کلمه‌ها',
      3,
      _doneToday(app, Kind.words, t),
    ),
  );
  void talk(int min) => steps.add(
    PlanStep(
      StepKind.talk,
      'صحبت آزاد',
      '${faNum(min)} دقیقه درباره‌ی یک موضوع، با شروع نرم',
      min + 1,
      _doneToday(app, Kind.talk, t),
    ),
  );
  void situation() {
    final s = nextSituation(app.situationLogs, t);
    steps.add(
      PlanStep(
        StepKind.situation,
        'یک موقعیت واقعی',
        s.title,
        0,
        app.situationLogs.any((l) => _day(l.date) == _day(t)),
      ),
    );
  }

  if (!app.lessonsDone) {
    steps.add(
      const PlanStep(
        StepKind.lessons,
        'آموزش کوتاه',
        'مکث و نفس، شروع نرم',
        4,
        false,
      ),
    );
  }
  final struggling = app.stage >= 2 && needsSlowDay(app);
  switch (app.stage) {
    case 1:
      slow('عبارت‌های کوتاه، با مکث بلند و شروع خیلی نرم');
      words();
    case 2:
      if (struggling) slow('دیروز سخت بود؛ اول یک دور آهسته');
      read();
      words();
    case 3:
      if (struggling) slow('دیروز سخت بود؛ اول یک دور آهسته');
      read();
      talk(1);
      situation();
    default:
      if (struggling) slow('دیروز سخت بود؛ اول یک دور آهسته');
      read();
      talk(3);
      if (t.weekday.isEven) situation();
  }
  return steps;
}

int planMinutes(List<PlanStep> plan) =>
    plan.where((s) => !s.done).fold(0, (a, s) => a + s.minutes);

/// Moves to the next stage when the current one is complete.
/// Returns the new stage number, or null when nothing changed.
Future<int?> maybeAdvance(AppState app) async {
  if (app.stage >= 4 || !stageComplete(app)) return null;
  app.stage++;
  app.stageSince = DateTime.now();
  await app.save();
  return app.stage;
}

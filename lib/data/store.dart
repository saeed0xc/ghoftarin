import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/engine.dart';
import 'situations.dart';

/// What kind of practice a session was. Only `read` sessions move the
/// adaptive pause target; the program counts all kinds.
abstract final class Kind {
  static const read = 'read'; // book reading at the current pause target
  static const slow = 'slow'; // slow practice round with a long pause
  static const words = 'words'; // word ladder
  static const talk = 'talk'; // free speech (monologue)
}

class SessionRecord {
  final DateTime date;
  final String passageId;
  final String kind;
  final double waitTarget;
  final List<PhraseResult> results;
  int? selfRating; // 0..9, severity rating of the day (0 = no stuttering)
  double? ssPercent; // %SS counted by a listener for this session

  SessionRecord({
    required this.date,
    required this.passageId,
    required this.waitTarget,
    required this.results,
    this.selfRating,
    this.kind = Kind.read,
  });

  SessionSummary get summary => SessionSummary.of(results);

  Map<String, dynamic> toJson() => {
    'd': date.toIso8601String(),
    'p': passageId,
    if (kind != Kind.read) 'k': kind,
    'w': waitTarget,
    'r': results.map((e) => e.toJson()).toList(),
    if (selfRating != null) 's': selfRating,
    if (ssPercent != null) 'ss': ssPercent,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    date: DateTime.parse(j['d'] as String),
    passageId: j['p'] as String,
    waitTarget: (j['w'] as num).toDouble(),
    results: (j['r'] as List)
        .map((e) => PhraseResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    selfRating: j['s'] as int?,
    kind: j['k'] as String? ?? Kind.read,
  )..ssPercent = (j['ss'] as num?)?.toDouble();
}

class Assessment {
  final DateTime date;
  final List<PhraseResult> results;
  final int confidence; // 0..100
  final int selfRating; // 0..9
  double? ssPercent; // %SS counted by a listener (the clinical standard)
  String? ssRater; // self | parent | therapist

  Assessment({
    required this.date,
    required this.results,
    required this.confidence,
    required this.selfRating,
    this.ssPercent,
    this.ssRater,
  });

  SessionSummary get summary => SessionSummary.of(results);

  Map<String, dynamic> toJson() => {
    'd': date.toIso8601String(),
    'r': results.map((e) => e.toJson()).toList(),
    'c': confidence,
    's': selfRating,
    if (ssPercent != null) 'ss': ssPercent,
    if (ssRater != null) 'sr': ssRater,
  };

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    date: DateTime.parse(j['d'] as String),
    results: (j['r'] as List)
        .map((e) => PhraseResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    confidence: j['c'] as int,
    selfRating: j['s'] as int,
    ssPercent: (j['ss'] as num?)?.toDouble(),
    ssRater: j['sr'] as String?,
  );
}

/// All app state, saved locally on the phone.
class AppState extends ChangeNotifier {
  static const _k = 'goftarin.v1';
  SharedPreferences? _prefs;

  bool onboarded = false;
  bool forChild = false;
  double waitTarget = 2.0;
  bool reminderOn = true;
  int reminderHour = 20;
  int reminderMinute = 0;
  Assessment? assessment;
  final List<SessionRecord> sessions = [];

  // safety screen
  String ageGroup = 'adult'; // under7 | 7to12 | teen | adult
  bool withTherapist = false;
  bool suddenOnset = false;

  // real-life situations
  final List<SituationLog> situationLogs = [];

  /// The short technique lessons have been completed (shown before the
  /// first practice session, so no technique is named before it is taught).
  bool lessonsDone = false;

  // word practice
  List<String> wordGroups = [];
  int wordStep = 0; // ladder step 0..2

  // self-guided program
  int stage = 1; // 1..4
  DateTime? stageSince;
  bool coachOn = true; // spoken guidance

  bool get needsTherapistNudge => !withTherapist;

  static const minWait = 0.8, maxWait = 3.0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_k);
    if (raw == null) return;
    try {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('store: could not read saved data: $e');
    }
  }

  void _fromJson(Map<String, dynamic> j) {
    {
      onboarded = j['onboarded'] as bool? ?? false;
      forChild = j['child'] as bool? ?? false;
      waitTarget = (j['wait'] as num?)?.toDouble() ?? 2.0;
      reminderOn = j['remOn'] as bool? ?? true;
      reminderHour = j['remH'] as int? ?? 20;
      reminderMinute = j['remM'] as int? ?? 0;
      ageGroup = j['age'] as String? ?? 'adult';
      withTherapist = j['slp'] as bool? ?? false;
      suddenOnset = j['sudden'] as bool? ?? false;
      wordGroups = ((j['wg'] as List?) ?? []).cast<String>();
      wordStep = j['ws'] as int? ?? 0;
      lessonsDone = j['lessons'] as bool? ?? false;
      stage = (j['stage'] as int? ?? 1).clamp(1, 4);
      final since = j['stageSince'] as String?;
      stageSince = since == null ? null : DateTime.tryParse(since);
      coachOn = j['coach'] as bool? ?? true;
      situationLogs
        ..clear()
        ..addAll(
          ((j['sit'] as List?) ?? []).map(
            (e) => SituationLog.fromJson(e as Map<String, dynamic>),
          ),
        );
      final a = j['assess'];
      assessment = a == null
          ? null
          : Assessment.fromJson(a as Map<String, dynamic>);
      sessions
        ..clear()
        ..addAll(
          ((j['sessions'] as List?) ?? []).map(
            (e) => SessionRecord.fromJson(e as Map<String, dynamic>),
          ),
        );
    }
  }

  Map<String, dynamic> _toJson() => {
    'onboarded': onboarded,
    'child': forChild,
    'wait': waitTarget,
    'remOn': reminderOn,
    'remH': reminderHour,
    'remM': reminderMinute,
    'age': ageGroup,
    'slp': withTherapist,
    'sudden': suddenOnset,
    'wg': wordGroups,
    'ws': wordStep,
    'lessons': lessonsDone,
    'stage': stage,
    if (stageSince != null) 'stageSince': stageSince!.toIso8601String(),
    'coach': coachOn,
    'sit': situationLogs.map((e) => e.toJson()).toList(),
    if (assessment != null) 'assess': assessment!.toJson(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  Future<void> save() async {
    notifyListeners();
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_toJson()));
  }

  /// Backup as text the user can keep (share to Telegram, notes, email).
  String exportBackup() =>
      jsonEncode({'app': 'goftarin', 'v': 1, 'data': _toJson()});

  /// Restores a backup made by [exportBackup]. Returns false and changes
  /// nothing when the text is not a valid backup.
  Future<bool> importBackup(String text) async {
    try {
      final start = text.indexOf('{'), end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return false;
      final j =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      if (j['app'] != 'goftarin') return false;
      final data = j['data'] as Map<String, dynamic>;
      // parse into a scratch state first so a broken backup changes nothing
      AppState()._fromJson(data);
      _fromJson(data);
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> reset() async {
    onboarded = false;
    forChild = false;
    waitTarget = 2.0;
    ageGroup = 'adult';
    withTherapist = false;
    suddenOnset = false;
    wordGroups = [];
    wordStep = 0;
    lessonsDone = false;
    stage = 1;
    stageSince = null;
    coachOn = true;
    situationLogs.clear();
    assessment = null;
    sessions.clear();
    await save();
  }

  /// Adds a finished session and adapts the pause target: after three sessions
  /// in a row with at least 80% of phrases paused long enough, the target
  /// drops by 0.2 s (never below 0.8 s), so the pause slowly becomes natural.
  Future<void> addSession(SessionRecord s) async {
    sessions.add(s);
    if (s.kind != Kind.read) {
      await save();
      return;
    }
    final last = sessions.reversed
        .where((x) => x.kind == Kind.read)
        .take(3)
        .toList();
    if (last.length == 3 &&
        last.every(
          (x) => x.waitTarget == waitTarget && x.summary.pauseRatio >= 0.8,
        ) &&
        waitTarget > minWait) {
      waitTarget = double.parse(
        (waitTarget - 0.2).clamp(minWait, maxWait).toStringAsFixed(1),
      );
    }
    await save();
  }

  // ---- derived values for the home and progress screens ----

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get practicedToday =>
      sessions.any((s) => _day(s.date) == _day(DateTime.now()));

  SessionRecord? get todaySession {
    final today = _day(DateTime.now());
    for (final s in sessions.reversed) {
      if (_day(s.date) == today) return s;
    }
    return null;
  }

  /// Consecutive days with at least one session, ending today or yesterday.
  int get streak {
    final days = sessions.map((s) => _day(s.date)).toSet();
    var d = _day(DateTime.now());
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  List<SessionRecord> sessionsBetween(DateTime from, DateTime to) => sessions
      .where((s) => !s.date.isBefore(from) && s.date.isBefore(to))
      .toList();

  /// Pause and soft-onset ratios for a window of days ending now.
  ({double pause, double soft, int phrases}) ratios(
    int daysBack, {
    int offsetDays = 0,
  }) {
    final end = DateTime.now().subtract(Duration(days: offsetDays));
    final rs = sessionsBetween(
      end.subtract(Duration(days: daysBack)),
      end,
    ).expand((s) => s.results).toList();
    final sum = SessionSummary.of(rs);
    return (pause: sum.pauseRatio, soft: sum.softRatio, phrases: sum.phrases);
  }

  int practiceDays(int daysBack) {
    final from = _day(DateTime.now()).subtract(Duration(days: daysBack - 1));
    return sessions
        .where((s) => !s.date.isBefore(from))
        .map((s) => _day(s.date))
        .toSet()
        .length;
  }
}

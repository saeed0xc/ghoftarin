import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/audio/recording.dart';
import 'package:goftarin/data/feedback.dart';
import 'package:goftarin/data/situations.dart';
import 'package:goftarin/data/store.dart';
import 'package:goftarin/services/report.dart';

PhraseResult r(int i, {double pause = 2.2, double rise = 170}) => PhraseResult(
  index: i,
  pauseSec: pause,
  early: pause < 2.0,
  riseMs: rise,
  onset: classifyOnset(rise, const EngineConfig()),
  durationSec: 2,
  syllablesPerSec: 4,
  onsetEnvelope: const [],
);

void main() {
  test('situations climb from easy to hard', () {
    final now = DateTime(2026, 10, 25, 12);
    expect(nextSituation([], now).id, 'greet');
    // greet done with high anxiety 3 days ago -> repeat it before moving on
    final logs = [
      SituationLog(
        date: now.subtract(const Duration(days: 3)),
        situationId: 'greet',
        anxietyBefore: 7,
        anxietyAfter: 5,
        severity: 4,
      ),
    ];
    expect(nextSituation(logs, now).id, 'greet');
    // greet now feels manageable -> next new one
    logs.add(
      SituationLog(
        date: now.subtract(const Duration(days: 3)),
        situationId: 'greet',
        anxietyBefore: 2,
        anxietyAfter: 1,
        severity: 2,
      ),
    );
    logs.add(
      SituationLog(
        date: now.subtract(const Duration(days: 3)),
        situationId: 'greet',
        anxietyBefore: 1,
        anxietyAfter: 1,
        severity: 1,
      ),
    );
    expect(
      nextSituation(logs, now).id,
      'greet',
      reason: 'average of last 3 is still above 3',
    );
    logs.add(
      SituationLog(
        date: now.subtract(const Duration(days: 3)),
        situationId: 'greet',
        anxietyBefore: 1,
        anxietyAfter: 1,
        severity: 1,
      ),
    );
    expect(nextSituation(logs, now).id, 'friend');
  });

  test('feedback is specific and suggests a slow round after a hard trial', () {
    final good = SessionSummary.of([for (var i = 0; i < 7; i++) r(i)]);
    expect(sessionFeedback(good, seed: 0).suggestSlowRound, false);
    final rushed = SessionSummary.of([
      for (var i = 0; i < 7; i++) r(i, pause: 0.8),
    ]);
    final f = sessionFeedback(rushed, seed: 1);
    expect(f.suggestSlowRound, true);
    expect(f.tip, contains('دایره'));
    final hard = SessionSummary.of([
      for (var i = 0; i < 7; i++) r(i, rise: 40),
    ]);
    expect(sessionFeedback(hard, seed: 2).tip, contains('هوا'));
  });

  test('recording builds a valid WAV and cuts phrases', () {
    final rec = SessionRecording()..add(List.filled(16000 * 3, 0.5));
    final all = rec.toWav();
    final bd = ByteData.sublistView(all);
    expect(String.fromCharCodes(all.sublist(0, 4)), 'RIFF');
    expect(bd.getUint32(40, Endian.little), 16000 * 3 * 2);
    final part = rec.toWav(fromSec: 1, toSec: 1.5);
    expect(ByteData.sublistView(part).getUint32(40, Endian.little), 8000 * 2);
    expect(rec.toWav(fromSec: -1, toSec: 99).length, all.length);
  });

  test('therapist report contains the key figures', () {
    final app = AppState()..waitTarget = 1.8;
    app.sessions.add(
      SessionRecord(
        date: DateTime.now(),
        passageId: 'morning',
        waitTarget: 1.8,
        results: [for (var i = 0; i < 7; i++) r(i)],
        selfRating: 3,
      ),
    );
    app.situationLogs.add(
      SituationLog(
        date: DateTime.now(),
        situationId: 'shop',
        anxietyBefore: 6,
        anxietyAfter: 3,
        severity: 2,
      ),
    );
    final t = buildTherapistReport(app);
    expect(t, contains('۱٫۸'));
    expect(t, contains('۱۰۰٪'));
    expect(t, contains('سفارش دادن'));
    expect(t, contains('لیدکامب'));
  });
}

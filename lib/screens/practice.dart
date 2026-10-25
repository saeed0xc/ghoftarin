import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../audio/recording.dart';
import '../data/content.dart';
import '../data/feedback.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/playback.dart';
import '../widgets/self_rating.dart';
import '../widgets/visuals.dart';
import 'session_view.dart';
import 'ss_counter.dart';

/// A practice session: guided reading → summary + daily self-rating → saved.
class PracticeScreen extends StatefulWidget {
  final AppState app;
  final Passage passage;

  /// A slower "practice round" (longer pause), suggested after a hard trial.
  final double? overrideWait;
  const PracticeScreen({
    super.key,
    required this.app,
    required this.passage,
    this.overrideWait,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<PhraseResult>? _results;
  int? _rating;
  late final double _wait = widget.overrideWait ?? widget.app.waitTarget;
  final _recording = SessionRecording();
  SsResult? _ss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _results == null
          ? SessionView(
              passage: widget.passage,
              waitTarget: _wait,
              guided: true,
              onClose: () => Navigator.of(context).pop(),
              onFinished: (r) => setState(() => _results = r),
              recording: _recording,
            )
          : _summary(),
    );
  }

  Widget _summary() {
    final rs = _results!;
    final s = SessionSummary.of(rs);
    final needRating = widget.app.todaySession?.selfRating == null;
    final fb = sessionFeedback(s, seed: widget.app.sessions.length);
    final slowRound = widget.overrideWait != null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(
            slowRound
                ? '${widget.passage.title} · دور تمرینی آرام'
                : widget.passage.title,
            style: const TextStyle(fontSize: 13, color: C.muted),
          ),
          Text(
            fb.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            fb.tip,
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              color: Color(0xFF33454B),
            ),
          ),
          if (fb.suggestSlowRound && !slowRound) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PracticeScreen(
                    app: widget.app,
                    passage: widget.passage,
                    overrideWait: (widget.app.waitTarget + 0.5)
                        .clamp(1.0, 3.0)
                        .toDouble(),
                  ),
                ),
              ),
              icon: const Icon(Icons.slow_motion_video),
              label: Text(
                'دور تمرینی آرام‌تر (مکث ${faNum((widget.app.waitTarget + 0.5).clamp(1.0, 3.0), 1)} ثانیه)',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'مکث کافی',
                  value: '${faNum(s.pauseOkCount)} از ${faNum(s.phrases)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'شروع نرم',
                  value: '${faNum(s.softCount)} از ${faNum(s.phrases)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'میانه‌ی مکث',
                  value: '${faNum(s.medianPause, 1)} ث',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'سرعت',
                  value: s.meanRate == null ? '—' : faNum(s.meanRate!, 1),
                  note: 'هجا در ثانیه',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [for (final r in rs) _phraseRow(r)]),
          ),
          const SizedBox(height: 12),
          PlaybackPanel(
            recording: _recording,
            results: rs,
            phrases: widget.passage.phrases,
          ),
          const SizedBox(height: 8),
          _objectiveCard(s),
          if (needRating) ...[
            const SizedBox(height: 12),
            AppCard(
              child: SelfRating(
                value: _rating,
                forChild: widget.app.forChild,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: needRating && _rating == null ? null : _save,
            child: const Text('ذخیره و پایان'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بدون ذخیره خارج شو'),
          ),
        ],
      ),
    );
  }

  Widget _phraseRow(PhraseResult r) {
    final (label, fg, bg) = switch (r.onset) {
      OnsetClass.soft => ('نرم', C.softDark, C.softBg),
      OnsetClass.medium => ('متوسط', C.brandDark, C.brandTint),
      OnsetClass.hard => ('ناگهانی', C.warmDark, C.warmBg),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              faNum(r.index + 1),
              style: const TextStyle(color: C.muted),
            ),
          ),
          Expanded(
            child: Text(
              widget.passage.phrases[r.index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          r.early
              ? Chip2('${faNum(r.pauseSec, 1)} ث', fg: C.warn, bg: C.warnBg)
              : Chip2('${faNum(r.pauseSec, 1)} ث', fg: C.muted, bg: C.bg),
          const SizedBox(width: 6),
          Chip2(label, fg: fg, bg: bg),
        ],
      ),
    );
  }

  Widget _objectiveCard(SessionSummary s) {
    final syl = _results!.fold<int>(
      0,
      (a, r) =>
          a +
          (r.index < widget.passage.syllables.length
              ? widget.passage.syllables[r.index]
              : 0),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اندازه‌گیری لکنت',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            s.eventsPer100Syllables == null
                ? 'نشانه‌های احتمالی ناروانی: محیط برای اندازه‌گیری پرسروصدا بود.'
                : 'نشانه‌های احتمالی ناروانی (آزمایشی): ${faNum(s.eventsPer100Syllables!, 1)} در هر ۱۰۰ هجا',
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
          if (_ss != null)
            Text(
              'درصد هجاهای لکنت‌دار (شمارش ${raterNames[_ss!.rater]}): ${faNum(_ss!.percent, 1)}٪',
              style: const TextStyle(
                fontSize: 13,
                height: 1.8,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (syl > 0 && _recording.lengthSamples > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () async {
                  final r = await Navigator.of(context).push<SsResult>(
                    MaterialPageRoute(
                      builder: (_) => SsCounterScreen(
                        recording: _recording,
                        totalSyllables: syl,
                        forChild: widget.app.forChild,
                      ),
                    ),
                  );
                  if (r != null && mounted) setState(() => _ss = r);
                },
                icon: const Icon(Icons.touch_app_outlined),
                label: const Text('شمارش درصد هجاهای لکنت‌دار (اختیاری)'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final rec = SessionRecord(
      date: DateTime.now(),
      passageId: widget.passage.id,
      waitTarget: _wait,
      results: _results!,
      selfRating: _rating,
    )..ssPercent = _ss?.percent;
    final before = widget.app.waitTarget;
    await widget.app.addSession(rec);
    if (!mounted) return;
    if (widget.app.waitTarget < before) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'عالی! سه جلسه پشت سر هم مکث‌ها درست بود. زمان مکث از این به بعد ${faNum(widget.app.waitTarget, 1)} ثانیه است.',
            style: const TextStyle(fontFamily: kUiFont),
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }
}

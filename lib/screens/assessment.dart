import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../audio/recording.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/self_rating.dart';
import '../widgets/visuals.dart';
import 'session_view.dart';
import 'ss_counter.dart';

/// First-use assessment: natural reading → confidence questions → self-rating → result.
class AssessmentFlow extends StatefulWidget {
  final AppState app;
  const AssessmentFlow({super.key, required this.app});

  @override
  State<AssessmentFlow> createState() => _AssessmentFlowState();
}

class _AssessmentFlowState extends State<AssessmentFlow> {
  int _step = 0; // 0 reading, 1 questions, 2 rating, 3 result
  List<PhraseResult> _results = const [];
  final List<int?> _answers = List.filled(confidenceQuestions.length, null);
  int? _rating;
  Assessment? _saved;
  final _recording = SessionRecording();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_step) {
        0 => SessionView(
          passage: passageById(assessmentPassageId),
          waitTarget: widget.app.waitTarget,
          guided: false,
          onClose: () => Navigator.of(context).pop(),
          onFinished: (r) => setState(() {
            _results = r;
            _step = 1;
          }),
          recording: _recording,
        ),
        1 => _questions(),
        2 => _ratingStep(),
        _ => _result(),
      },
    );
  }

  Widget _header(String title, String sub, int filled) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsetsDirectional.only(end: i < 2 ? 6 : 0),
              height: 6,
              decoration: BoxDecoration(
                color: i < filled ? C.brand : C.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 18),
      Text(sub, style: const TextStyle(fontSize: 13, color: C.muted)),
      Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _questions() {
    final complete = !_answers.contains(null);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _header('چقدر با صحبت کردن راحتی؟', 'مرحله‌ی ۲ از ۳ · پرسش‌نامه', 2),
          for (var i = 0; i < confidenceQuestions.length; i++) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    confidenceQuestions[i].text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var a = 1; a <= 5; a++)
                        ChoiceChip(
                          label: Text(answerLabels[a - 1]),
                          selected: _answers[i] == a,
                          onSelected: (_) => setState(() => _answers[i] = a),
                          selectedColor: C.brandSoft,
                          side: const BorderSide(color: C.line),
                          showCheckmark: false,
                          labelStyle: const TextStyle(
                            fontFamily: kUiFont,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: complete ? () => setState(() => _step = 2) : null,
            child: const Text('ادامه'),
          ),
        ],
      ),
    );
  }

  Widget _ratingStep() => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _header('شدت لکنت از نگاه خودت', 'مرحله‌ی ۳ از ۳ · خودارزیابی', 3),
        AppCard(
          child: SelfRating(
            value: _rating,
            forChild: widget.app.forChild,
            onChanged: (v) => setState(() => _rating = v),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _rating == null ? null : _save,
          child: const Text('دیدن نتیجه'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    final a = Assessment(
      date: DateTime.now(),
      results: _results,
      confidence: confidenceScore(_answers.cast<int>()),
      selfRating: _rating!,
    );
    widget.app.assessment = a;
    await widget.app.save();
    setState(() {
      _saved = a;
      _step = 3;
    });
  }

  Widget _result() {
    final a = _saved!;
    final s = a.summary;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'خواندن متن · پرسش‌نامه · خودارزیابی',
            style: TextStyle(fontSize: 13, color: C.muted),
          ),
          const Text(
            'نتیجه‌ی ارزیابی اولیه',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Text(
            'اندازه‌گیری از روی صدای تو',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const Text(
            'عینی؛ از ضبط خواندن، روی همین گوشی',
            style: TextStyle(fontSize: 12, color: C.muted),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _row(
                  'مکث پیش از شروع (میانه)',
                  '${faNum(s.medianPause, 1)} ثانیه',
                ),
                _row(
                  'شروع نرم',
                  '${faNum(s.softCount)} از ${faNum(s.phrases)} عبارت',
                ),
                _row(
                  'سرعت خواندن',
                  s.meanRate == null
                      ? '—'
                      : '${faNum(s.meanRate!, 1)} هجا در ثانیه',
                ),
                _row(
                  'نشانه‌های احتمالی ناروانی (آزمایشی)',
                  s.eventsPer100Syllables == null
                      ? 'محیط پرسروصدا بود'
                      : '${faNum(s.eventsPer100Syllables!, 1)} در هر ۱۰۰ هجا',
                ),
                if (s.eventsPer100Syllables != null && s.events.total > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'تکرار: ${faNum(s.events.repetitions)} · کشیدن صدا: ${faNum(s.events.prolongations)} · مکث درون عبارت: ${faNum(s.events.blocks)}',
                      style: const TextStyle(fontSize: 12, color: C.muted),
                    ),
                  ),
                _ssRow(a),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'از نگاه خودت',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const Text(
            'خوداظهاری؛ احساس تو از صحبت کردن هم بخشی از وضعیت است',
            style: TextStyle(fontSize: 12, color: C.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _score(
                  '${faNum(a.selfRating)} از ۹',
                  'شدت لکنت',
                  a.selfRating / 9,
                  C.brand,
                  C.brandSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _score(
                  faNum(a.confidence),
                  'راحتی در صحبت (از ۱۰۰)',
                  a.confidence / 100,
                  C.warm,
                  const Color(0xFFF3E3D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: C.brandTint,
            border: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برنامه‌ی شروع',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'اول یک آموزش کوتاه ۳ دقیقه‌ای: دو مهارت «مکث و نفس» و «شروع نرم» را یاد می‌گیری و امتحان می‌کنی. بعد هر روز یک صفحه کتاب با همین دو مهارت. اپ کم‌کم زمان مکث را کوتاه‌تر می‌کند تا طبیعی شود.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: Color(0xFF33454B),
                  ),
                ),
              ],
            ),
          ),
          if (s.phrases < 5) ...[
            const SizedBox(height: 12),
            const AppCard(
              color: C.warmBg,
              border: false,
              child: Text(
                'چند عبارت درست تشخیص داده نشد؛ احتمالاً محیط پرسروصدا بود یا بین عبارت‌ها مکث کوتاه بود. می‌توانی بعداً از تنظیمات ارزیابی را تکرار کنی.',
                style: TextStyle(fontSize: 13, height: 1.8),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final first = !widget.app.onboarded;
              widget.app.onboarded = true;
              await widget.app.save();
              if (first && widget.app.reminderOn) {
                Reminders.schedule(
                  widget.app.reminderHour,
                  widget.app.reminderMinute,
                ).catchError((Object e) => debugPrint('reminder: $e'));
              }
              if (!mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('شروع مسیر'),
          ),
        ],
      ),
    );
  }

  int get _readSyllables {
    final p = passageById(assessmentPassageId);
    return _results.fold<int>(
      0,
      (a, r) => a + (r.index < p.syllables.length ? p.syllables[r.index] : 0),
    );
  }

  Widget _ssRow(Assessment a) {
    if (a.ssPercent != null) {
      return _row(
        'درصد هجاهای لکنت‌دار (شمارش ${raterNames[a.ssRater] ?? ''})',
        '${faNum(a.ssPercent!, 1)}٪',
        last: true,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'درصد هجاهای لکنت‌دار: معیار استاندارد گفتاردرمانی؛ با گوش دادن به ضبط شمرده می‌شود.',
              style: TextStyle(fontSize: 12, height: 1.7, color: C.muted),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(72, 44)),
            onPressed: _recording.lengthSamples == 0 || _readSyllables == 0
                ? null
                : () async {
                    final r = await Navigator.of(context).push<SsResult>(
                      MaterialPageRoute(
                        builder: (_) => SsCounterScreen(
                          recording: _recording,
                          totalSyllables: _readSyllables,
                          forChild: widget.app.forChild,
                        ),
                      ),
                    );
                    if (r == null) return;
                    a.ssPercent = r.percent;
                    a.ssRater = r.rater;
                    await widget.app.save();
                    if (mounted) setState(() {});
                  },
            child: const Text('شمارش'),
          ),
        ],
      ),
    );
  }

  Widget _score(
    String value,
    String label,
    double p,
    Color color,
    Color track,
  ) => AppCard(
    child: Column(
      children: [
        BreathRing(
          progress: p,
          label: value,
          color: color,
          track: track,
          size: 108,
          stroke: 10,
          fontSize: 18,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _row(String l, String v, {bool last = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFE9EDEA))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(fontSize: 14)),
        Text(
          v,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

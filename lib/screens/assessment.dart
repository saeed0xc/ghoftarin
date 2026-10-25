import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/self_rating.dart';
import '../widgets/visuals.dart';
import 'session_view.dart';

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
          Row(
            children: [
              Expanded(
                child: _score(
                  '${faNum(a.selfRating)} از ۹',
                  'شدت لکنت (خودارزیابی)',
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
                  last: true,
                ),
              ],
            ),
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
                  'هر روز یک صفحه کتاب با مکث ${faNum(widget.app.waitTarget, 1)} ثانیه‌ای پیش از هر عبارت و شروع نرم. وقتی سه جلسه پشت سر هم مکث‌ها درست بود، زمان مکث کم‌کم کوتاه‌تر می‌شود تا طبیعی شود.',
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
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('شروع برنامه'),
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

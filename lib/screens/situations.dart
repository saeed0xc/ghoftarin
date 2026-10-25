import 'package:flutter/material.dart';

import '../data/situations.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/self_rating.dart';
import 'guide.dart';

/// Real-life practice: pick a situation, rate anxiety before, do it, then rate
/// stuttering and anxiety after. Gradual exposure instead of avoidance.
class SituationsScreen extends StatelessWidget {
  final AppState app;
  const SituationsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final next = nextSituation(app.situationLogs, DateTime.now());
        return Scaffold(
          appBar: AppBar(
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'موقعیت‌های واقعی',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: const [GuideLink(pageId: 'situations', label: 'چرا؟')],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const Text(
                'تکنیک‌ها را قدم به قدم به صحبت روزمره ببر. از موقعیت‌های آسان‌تر شروع کن.',
                style: TextStyle(fontSize: 13, height: 1.8, color: C.muted),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: C.brandTint,
                border: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'پیشنهاد امروز',
                      style: TextStyle(fontSize: 12, color: C.brandDark),
                    ),
                    Text(
                      next.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next.tip,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.8,
                        color: Color(0xFF33454B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => _open(context, next),
                      child: const Text('امروز انجامش می‌دهم'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'همه‌ی موقعیت‌ها',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final s in situations) ...[
                _row(context, s),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Situation s) {
    final logs = app.situationLogs
        .where((l) => l.situationId == s.id && !l.avoided)
        .toList();
    String sub;
    if (logs.isEmpty) {
      sub = 'هنوز امتحان نشده';
    } else {
      final first = logs.first.anxietyBefore, last = logs.last.anxietyBefore;
      sub =
          '${faNum(logs.length)} بار · اضطراب از ${faNum(first)} به ${faNum(last)} (از ۱۰)';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _open(context, s),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: C.muted),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Situation s) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SituationLogScreen(app: app, situation: s),
    ),
  );
}

class SituationLogScreen extends StatefulWidget {
  final AppState app;
  final Situation situation;
  const SituationLogScreen({
    super.key,
    required this.app,
    required this.situation,
  });

  @override
  State<SituationLogScreen> createState() => _SituationLogScreenState();
}

class _SituationLogScreenState extends State<SituationLogScreen> {
  int _step = 0; // 0 before, 1 after
  double _before = 5;
  double _after = 5;
  int? _severity;

  @override
  Widget build(BuildContext context) {
    final s = widget.situation;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            s.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            s.tip,
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              color: Color(0xFF33454B),
            ),
          ),
          const SizedBox(height: 16),
          if (_step == 0) ...[
            AppCard(
              child: _anxiety(
                'الان، پیش از انجامش، چقدر مضطربی؟',
                _before,
                (v) => setState(() => _before = v),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('رفتم و انجامش دادم'),
            ),
            TextButton(
              onPressed: () => _save(avoided: true),
              child: const Text('امروز نتوانستم (اشکالی ندارد، ثبت می‌شود)'),
            ),
          ] else ...[
            AppCard(
              child: SelfRating(
                value: _severity,
                forChild: widget.app.forChild,
                onChanged: (v) => setState(() => _severity = v),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: _anxiety(
                'بعد از انجامش، اضطرابت چقدر بود؟',
                _after,
                (v) => setState(() => _after = v),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _severity == null ? null : () => _save(),
              child: const Text('ثبت'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _anxiety(String q, double v, ValueChanged<double> on) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        q,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: v,
              min: 0,
              max: 10,
              divisions: 10,
              label: faNum(v.round()),
              semanticFormatterCallback: (x) =>
                  'اضطراب ${faNum(x.round())} از ۱۰',
              onChanged: on,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              faNum(v.round()),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('آرام', style: TextStyle(fontSize: 12, color: C.muted)),
          Text('خیلی مضطرب', style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    ],
  );

  Future<void> _save({bool avoided = false}) async {
    final app = widget.app;
    app.situationLogs.add(
      SituationLog(
        date: DateTime.now(),
        situationId: widget.situation.id,
        anxietyBefore: _before.round(),
        anxietyAfter: avoided ? _before.round() : _after.round(),
        severity: _severity ?? 0,
        avoided: avoided,
      ),
    );
    await app.save();
    if (!mounted) return;
    final drop = _before.round() - _after.round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          avoided
              ? 'ثبت شد. دفعه‌ی بعد می‌توانی یک موقعیت آسان‌تر انتخاب کنی.'
              : drop > 0
              ? 'آفرین! اضطرابت ${faNum(drop)} درجه کمتر از پیش‌بینی بود.'
              : 'آفرین که انجامش دادی. تکرار، اضطراب را کم‌کم پایین می‌آورد.',
          style: const TextStyle(fontFamily: kUiFont),
        ),
      ),
    );
    Navigator.of(context).pop();
  }
}

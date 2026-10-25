import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import 'assessment.dart';
import 'guide.dart';

/// Short screening before the first assessment. It does not diagnose; it
/// points people to a professional when the app alone is not appropriate.
class SafetyScreen extends StatefulWidget {
  final AppState app;
  const SafetyScreen({super.key, required this.app});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  String? _age;
  bool? _therapist;
  bool? _sudden;

  bool get _complete =>
      _age != null &&
      _therapist != null &&
      (_age == 'under7' || _sudden != null);

  @override
  void initState() {
    super.initState();
    if (widget.app.forChild) _age = null;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.app.forChild;
    final warnings = <Widget>[
      if (_age == 'under7')
        _warn(
          'برای کودکان زیر ۷ سال، مؤثرترین روش شناخته‌شده (برنامه‌ی لیدکامب) را والدین با آموزش و نظارت گفتاردرمانگر انجام می‌دهند. گفتارین را فقط کنار این برنامه استفاده کنید.',
        ),
      if (_sudden == true)
        _warn(
          'لکنتی که در بزرگسالی و ناگهانی شروع شده، یا بعد از بیماری، ضربه به سر یا داروی جدید، باید اول توسط پزشک بررسی شود. لطفاً پیش از تمرین با پزشک مشورت کنید.',
          strong: true,
        ),
      if (_therapist == false && _age != 'under7' && _sudden != true)
        _info(
          'گفتارین ابزار تمرین است. پیشنهاد می‌کنیم دست‌کم یک بار با گفتاردرمانگر ارزیابی شوی تا برنامه‌ی دقیق‌تری داشته باشی.',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'پیش از شروع',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'سه پرسش کوتاه، تا مطمئن شویم گفتارین برایت مناسب است.',
              style: TextStyle(fontSize: 13, color: C.muted),
            ),
            const SizedBox(height: 16),
            _question(
              child ? 'سن فرزندتان' : 'سن تو',
              [
                ('under7', 'زیر ۷ سال'),
                ('7to12', '۷ تا ۱۲'),
                ('teen', '۱۳ تا ۱۷'),
                ('adult', '۱۸ به بالا'),
              ],
              _age,
              (v) => setState(() => _age = v),
            ),
            const SizedBox(height: 12),
            _question(
              child
                  ? 'آیا فرزندتان الان با گفتاردرمانگر کار می‌کند؟'
                  : 'آیا الان با گفتاردرمانگر کار می‌کنی؟',
              [(true, 'بله'), (false, 'نه')],
              _therapist,
              (v) => setState(() => _therapist = v),
            ),
            if (_age != 'under7') ...[
              const SizedBox(height: 12),
              _question(
                'آیا لکنت در بزرگسالی و ناگهانی شروع شده، یا بعد از بیماری، ضربه به سر یا داروی جدید؟',
                [(true, 'بله'), (false, 'نه، از کودکی بوده')],
                _sudden,
                (v) => setState(() => _sudden = v),
              ),
            ],
            const SizedBox(height: 16),
            ...warnings.expand((w) => [w, const SizedBox(height: 10)]),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GuidePageScreen(pageId: 'therapist'),
                ),
              ),
              child: const Text('کی سراغ گفتاردرمانگر برویم؟'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: !_complete
                  ? null
                  : () async {
                      final app = widget.app;
                      app.ageGroup = _age!;
                      app.withTherapist = _therapist!;
                      app.suddenOnset = _sudden ?? false;
                      if (_age == 'under7') app.forChild = true;
                      await app.save();
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssessmentFlow(app: app),
                        ),
                      );
                    },
              child: Text(_sudden == true ? 'متوجه شدم، ادامه' : 'ادامه'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _question<T>(
    String q,
    List<(T, String)> options,
    T? value,
    ValueChanged<T> onPick,
  ) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q,
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (v, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == v,
                onSelected: (_) => onPick(v),
                selectedColor: C.brandSoft,
                side: const BorderSide(color: C.line),
                showCheckmark: false,
                labelStyle: const TextStyle(fontFamily: kUiFont, fontSize: 14),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _warn(String text, {bool strong = false}) => AppCard(
    color: strong ? C.warnBg : C.warmBg,
    border: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: strong ? C.warn : C.warmDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.8)),
        ),
      ],
    ),
  );

  Widget _info(String text) => AppCard(
    color: C.brandTint,
    border: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: C.brandDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.8)),
        ),
      ],
    ),
  );
}

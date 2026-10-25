import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'practice.dart';
import 'session_view.dart';

const _pausePassage = Passage(
  id: 'lesson-pause',
  title: 'آموزش: مکث و نفس',
  source: 'آموزش ۱',
  audience: 'all',
  phrases: ['سلام.', 'صبح بخیر.', 'امروز روز خوبی است.'],
  syllables: [2, 3, 7],
  separator: '  ·  ',
);

const _softPassage = Passage(
  id: 'lesson-soft',
  title: 'آموزش: شروع نرم',
  source: 'آموزش ۲',
  audience: 'all',
  phrases: ['آب', 'امروز', 'اسم من'],
  syllables: [1, 2, 3],
  separator: '  ·  ',
);

/// Two short lessons before the first practice: each technique is explained,
/// demonstrated and tried once, so nothing is asked of the user before it
/// has been taught.
class LessonsScreen extends StatefulWidget {
  final AppState app;

  /// Open the first practice session when the lessons end.
  final bool startPracticeAfter;
  const LessonsScreen({
    super.key,
    required this.app,
    this.startPracticeAfter = true,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  int _step = 0; // 0 intro, 1 pause, 2 soft onset, 3 done
  List<PhraseResult>? _pauseTry;
  List<PhraseResult>? _softTry;
  AudioPlayer? _playerOrNull; // created on first use
  AudioPlayer get _player => _playerOrNull ??= AudioPlayer();
  String? _playing;

  @override
  void dispose() {
    _playerOrNull?.dispose();
    super.dispose();
  }

  Future<List<PhraseResult>?> _try(Passage p) {
    return Navigator.of(context).push<List<PhraseResult>>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          body: SessionView(
            passage: p,
            waitTarget: widget.app.waitTarget,
            guided: true,
            onClose: () => Navigator.of(ctx).pop(),
            onFinished: (r) => Navigator.of(ctx).pop(r),
          ),
        ),
      ),
    );
  }

  Future<void> _play(String name) async {
    await _player.stop();
    if (_playing == name) {
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = name);
    await _player.play(AssetSource('audio/onset-$name.wav'));
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  Future<void> _finish() async {
    widget.app.lessonsDone = true;
    await widget.app.save();
    if (!mounted) return;
    if (widget.startPracticeAfter) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            app: widget.app,
            passage: passageForDay(DateTime.now(), child: widget.app.forChild),
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _step == 0 || _step == 3
              ? 'آموزش کوتاه'
              : 'آموزش ${faNum(_step)} از ۲',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: switch (_step) {
          0 => _intro(),
          1 => _pauseLesson(),
          2 => _softLesson(),
          _ => _done(),
        },
      ),
    );
  }

  List<Widget> _intro() => [
    const Text(
      'پیش از اولین تمرین',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 8),
    const Text(
      'دو مهارت ساده را یاد می‌گیری و هرکدام را یک بار امتحان می‌کنی. حدود ۳ دقیقه طول می‌کشد. هیچ نمره‌ای در کار نیست؛ فقط آشنا می‌شوی.',
      style: TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF33454B)),
    ),
    const SizedBox(height: 16),
    _item(Icons.air, 'مکث و نفس', 'پیش از هر جمله، یک نفس آرام.'),
    const SizedBox(height: 10),
    _item(
      Icons.graphic_eq,
      'شروع نرم',
      'صدای اول را آهسته شروع کن و بگذار کم‌کم بلند شود.',
    ),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => setState(() => _step = 1),
      child: const Text('شروع آموزش'),
    ),
  ];

  Widget _item(IconData icon, String title, String sub) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: C.brandTint,
          child: Icon(icon, color: C.brandDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(sub, style: const TextStyle(fontSize: 13, color: C.muted)),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _pauseLesson() {
    final r = _pauseTry;
    final ok = r == null ? 0 : r.where((x) => !x.early).length;
    return [
      const Text(
        'مکث و نفس',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'وقتی برای شروع حرف عجله داریم، عضلات صدا سفت می‌شوند و گیر کردن راحت‌تر پیش می‌آید. یک مکث کوتاه و یک نفس آرام پیش از هر جمله، به صدا فرصت می‌دهد آماده شود.',
        style: TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF33454B)),
      ),
      const SizedBox(height: 16),
      const AppCard(child: Center(child: _DemoOrb())),
      const SizedBox(height: 12),
      const AppCard(
        color: C.brandTint,
        border: false,
        child: Text(
          'در تمرین، یک دایره همراه نفست آرام بزرگ می‌شود. وقتی پر شد و سبز شد، هر وقت آماده بودی شروع کن. عددی و شمارشی در کار نیست؛ عجله‌ای نیست.',
          style: TextStyle(fontSize: 14, height: 1.9),
        ),
      ),
      const SizedBox(height: 16),
      if (r == null)
        FilledButton(
          onPressed: () async {
            final res = await _try(_pausePassage);
            if (res != null && mounted) setState(() => _pauseTry = res);
          },
          child: const Text('امتحان کن: سه جمله‌ی کوتاه'),
        )
      else ...[
        AppCard(
          child: Text(
            ok == r.length
                ? 'عالی! پیش از هر سه جمله به اندازه‌ی کافی مکث کردی.'
                : 'پیش از ${faNum(ok)} جمله از ${faNum(r.length)} مکث کافی بود. با تمرین راحت‌تر می‌شود.',
            style: const TextStyle(fontSize: 15, height: 1.8),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('آموزش بعد: شروع نرم'),
        ),
        TextButton(
          onPressed: () => setState(() => _pauseTry = null),
          child: const Text('یک بار دیگر'),
        ),
      ],
    ];
  }

  List<Widget> _softLesson() {
    final r = _softTry;
    final soft = r == null
        ? 0
        : r.where((x) => x.onset == OnsetClass.soft).length;
    return [
      const Text(
        'شروع نرم',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'گیر کردن بیشتر روی صدای اول کلمه پیش می‌آید. اگر صدای اول را با فشار و ناگهانی شروع کنیم، تارهای صوتی محکم به هم می‌خورند. در شروع نرم، صدا با کمی هوا و خیلی آهسته شروع می‌شود و در هجای اول به اندازه‌ی معمول می‌رسد.',
        style: TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF33454B)),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'گوش کن و فرق را بشنو: «امروز»',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _play('hard'),
                    icon: Icon(
                      _playing == 'hard'
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: const Text('ناگهانی'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _play('soft'),
                    icon: Icon(
                      _playing == 'soft'
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: const Text('نرم'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'نمونه‌ها با صدای مصنوعی ساخته شده‌اند.',
              style: TextStyle(fontSize: 11, color: C.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'چطور',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              '۱. کمی هوا را آرام بیرون بده، مثل یک «هـ» خیلی آهسته.',
              style: TextStyle(fontSize: 14, height: 1.9),
            ),
            Text(
              '۲. صدای اول را با همین هوا، خیلی آهسته شروع کن.',
              style: TextStyle(fontSize: 14, height: 1.9),
            ),
            Text(
              '۳. بگذار صدا در هجای اول کم‌کم بلند شود؛ بقیه‌ی کلمه عادی.',
              style: TextStyle(fontSize: 14, height: 1.9),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (r == null)
        FilledButton(
          onPressed: () async {
            final res = await _try(_softPassage);
            if (res != null && mounted) setState(() => _softTry = res);
          },
          child: const Text('امتحان کن: «آب»، «امروز»، «اسم من»'),
        )
      else ...[
        AppCard(
          child: Text(
            soft == r.length
                ? 'عالی! هر سه شروع نرم بود.'
                : soft > 0
                ? '${faNum(soft)} شروع از ${faNum(r.length)} نرم بود. آهسته‌تر و با هوای بیشتر شروع کن.'
                : 'شروع‌ها هنوز کمی ناگهانی بود. دوباره به نمونه‌ی «نرم» گوش کن و آهسته‌تر شروع کن.',
            style: const TextStyle(fontSize: 15, height: 1.8),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _step = 3),
          child: const Text('ادامه'),
        ),
        TextButton(
          onPressed: () => setState(() => _softTry = null),
          child: const Text('یک بار دیگر'),
        ),
      ],
    ];
  }

  List<Widget> _done() => [
    const Text(
      'آماده‌ای',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 8),
    const Text(
      'در هر جلسه یک صفحه کتاب را عبارت به عبارت می‌خوانی: پیش از هر عبارت مکث و نفس، بعد شروع نرم. بعد از هر جلسه می‌توانی به خودت گوش کنی. راهنمای کامل همیشه از علامت ؟ در صفحه‌ی خانه در دسترس است.',
      style: TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF33454B)),
    ),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: _finish,
      child: Text(widget.startPracticeAfter ? 'شروع اولین جلسه' : 'تمام'),
    ),
  ];
}

/// Looping demonstration of the breath orb (about 4 s per breath).
class _DemoOrb extends StatefulWidget {
  const _DemoOrb();

  @override
  State<_DemoOrb> createState() => _DemoOrbState();
}

class _DemoOrbState extends State<_DemoOrb> {
  Timer? _t;
  double _p = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _p = _p >= 1.6 ? 0 : _p + 0.05);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      BreathOrb(
        progress: _p,
        mode: _p >= 1 ? OrbMode.ready : OrbMode.waiting,
        size: 140,
      ),
      const SizedBox(height: 8),
      Text(
        _p >= 1 ? 'هر وقت آماده‌ای' : 'یک نفس آرام…',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _p >= 1 ? C.softDark : C.ink,
        ),
      ),
    ],
  );
}

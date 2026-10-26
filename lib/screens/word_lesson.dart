import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/engine.dart';
import '../audio/mic.dart';
import '../data/store.dart';
import '../data/word_lessons.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/visuals.dart';

/// One word lesson, Duolingo style: one big word at a time, said stretched
/// and with a soft start. Words that were not yet soft and stretched come
/// back once at the end. Pops with the lesson score (0..1), or null when the
/// user left early.
class WordLessonScreen extends StatefulWidget {
  final AppState app;
  final int day; // word day (0-based)
  final int count;
  const WordLessonScreen({
    super.key,
    required this.app,
    required this.day,
    this.count = wordsPerLesson,
  });

  @override
  State<WordLessonScreen> createState() => _WordLessonScreenState();
}

enum _S { intro, noMic, calibrating, listening, interrupted, done }

class _Item {
  final BankWord w;
  final bool retry;
  PhraseResult? result;
  _Item(this.w, {this.retry = false});
  bool get soft => result != null && isSoft(result!);
  bool get stretched => result != null && isStretched(result!, w.syllables);
  bool get good => soft && stretched;
}

class _WordLessonScreenState extends State<WordLessonScreen>
    with WidgetsBindingObserver {
  Mic? _micOrNull;
  Mic get _mic => _micOrNull ??= Mic();
  FluencyEngine? _engine;
  _S _s = _S.intro;
  late final List<_Item> _queue = [
    for (final w in wordsForDay(widget.day, count: widget.count)) _Item(w),
  ];
  int _pos = 0;
  double _pause = 0;
  bool _speaking = false;
  _Item? _feedback; // shown briefly after each word
  final List<PhraseResult> _all = [];

  double get _wait => widget.app.waitTarget.clamp(0.8, 1.5);
  int get _firstCount => _queue.where((i) => !i.retry).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Coach.of(widget.app).say('words_intro');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _micOrNull?.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) &&
        (_s == _S.calibrating || _s == _S.listening)) {
      _mic.stop();
      _engine?.stop();
      WakelockPlus.disable().catchError((_) {});
      setState(() => _s = _S.interrupted);
    }
  }

  Future<void> _start({bool resume = false}) async {
    await Coach.stop();
    if (!await _mic.ensurePermission()) {
      setState(() => _s = _S.noMic);
      return;
    }
    if (resume && _engine != null) {
      _engine!.resume();
    } else {
      _engine = FluencyEngine(
        config: EngineConfig(waitTarget: _wait),
        syllables: const [],
        onPhrase: _onPhrase,
        onState: _onState,
      )..start();
    }
    setState(() => _s = _S.calibrating);
    WakelockPlus.enable().catchError((_) {});
    await _mic.start((x) => _engine!.addSamples(x));
  }

  void _onState(EngineState st, double e) {
    if (!mounted) return;
    if (st == EngineState.pausing) {
      if (_s == _S.calibrating) setState(() => _s = _S.listening);
      if (_speaking || (e - _pause).abs() >= 0.05 || e < _pause) {
        if (!_speaking && _pause < _wait && e >= _wait) {
          HapticFeedback.lightImpact();
        }
        setState(() {
          _speaking = false;
          _pause = e;
        });
      }
    } else if (st == EngineState.speaking) {
      setState(() {
        _speaking = true;
        _feedback = null;
      });
    }
  }

  void _onPhrase(PhraseResult r) {
    if (!mounted || _pos >= _queue.length) return;
    final item = _queue[_pos]..result = r;
    _all.add(r);
    // a word not yet soft and stretched comes back once at the end
    if (!item.good && !item.retry) _queue.add(_Item(item.w, retry: true));
    setState(() {
      _feedback = item;
      _pos++;
    });
    if (item.good) HapticFeedback.selectionClick();
    if (_pos >= _queue.length) _finish();
  }

  void _redo() {
    if (_pos == 0 || _engine == null) return;
    _engine!.undoLast();
    final last = _queue[_pos - 1];
    if (!last.good &&
        !last.retry &&
        _queue.last.retry &&
        _queue.last.w == last.w) {
      _queue.removeLast();
    }
    _all.removeLast();
    setState(() {
      _pos--;
      last.result = null;
      _feedback = null;
    });
  }

  double get _score {
    final first = _queue.where((i) => !i.retry).toList();
    if (first.isEmpty) return 0;
    return first.where((i) => i.good).length / first.length;
  }

  Future<void> _finish() async {
    await _mic.stop();
    _engine?.stop();
    WakelockPlus.disable().catchError((_) {});
    await widget.app.addSession(
      SessionRecord(
        date: DateTime.now(),
        passageId: 'wordday-${widget.day}',
        waitTarget: _wait,
        results: List.of(_all),
        kind: Kind.words,
      )..score = _score,
    );
    Coach.of(widget.app).say(_score >= 0.7 ? 'session_good' : 'session_ok');
    if (mounted) setState(() => _s = _S.done);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _queue.isEmpty ? 0.0 : _pos / _queue.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(_s == _S.done ? _score : null),
                    icon: const Icon(
                      Icons.close,
                      color: C.lockedDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: LessonProgress(value: progress)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_s) {
    _S.intro => _intro(),
    _S.noMic => _message(
      'برای تمرین، اجازه‌ی میکروفون لازم است. صدا فقط روی همین گوشی تحلیل می‌شود.',
      'دوباره امتحان کن',
      _start,
    ),
    _S.interrupted => _message(
      'تمرین متوقف شد. از همین کلمه ادامه می‌دهیم.',
      'ادامه',
      () => _start(resume: true),
    ),
    _S.calibrating => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BreathOrb(progress: 0, mode: OrbMode.idle, size: 140),
          SizedBox(height: 16),
          Text(
            'چند لحظه سکوت…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
    _S.listening => _listening(),
    _S.done => _done(),
  };

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.day < wordDays
            ? 'روز ${faNum(widget.day + 1)}: ${wordDayTitle(widget.day)}'
            : 'گرم کردن با کلمه',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      const _Tip(
        icon: Icons.timelapse,
        color: C.blue,
        title: 'کشیده بگو',
        text: 'هر هجا را آرام و کشیده بگو، مثل یک آواز آهسته: «آاا‌ب»، «اِمـروووز». نزدیک به نیم ثانیه برای هر هجا.',
      ),
      const SizedBox(height: 12),
      const _Tip(
        icon: Icons.air,
        color: C.brand,
        title: 'نرم شروع کن',
        text: 'صدای اول را با کمی هوا و آهسته شروع کن و بگذار کم‌کم بلند شود.',
      ),
      const SizedBox(height: 12),
      const _Tip(
        icon: Icons.self_improvement,
        color: C.gold,
        title: 'بین کلمه‌ها مکث کن',
        text: 'وقتی دایره سبز شد، کلمه‌ی بعد را بگو. عجله‌ای نیست.',
      ),
      const Spacer(),
      ChunkyButton(label: 'شروع', onPressed: _start),
    ],
  );

  Widget _listening() {
    final item = _pos < _queue.length ? _queue[_pos] : null;
    final p = _pause / _wait;
    final mode = _speaking
        ? OrbMode.speaking
        : (p >= 1 ? OrbMode.ready : OrbMode.waiting);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item?.retry == true
              ? 'یک بار دیگر، کشیده و نرم'
              : 'این کلمه را کشیده و نرم بگو',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: C.line, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                item?.w.text ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kBookFont,
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              if (item != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < item.w.syllables; i++)
                      Container(
                        width: 28,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: C.blue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              if (item != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${faNum(item.w.syllables)} هجا',
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: BreathOrb(progress: p, mode: mode, size: 110),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            switch (mode) {
              OrbMode.speaking => 'کشیده… آرام…',
              OrbMode.ready => 'حالا بگو',
              _ => 'یک نفس آرام…',
            },
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: mode == OrbMode.ready ? C.softDark : C.muted,
            ),
          ),
        ),
        const Spacer(),
        if (_feedback != null) _feedbackBanner(_feedback!),
        if (_feedback == null && _pos > 0)
          TextButton.icon(
            onPressed: _redo,
            icon: const Icon(Icons.replay),
            label: const Text('کلمه‌ی قبل را دوباره بگویم'),
          ),
      ],
    );
  }

  Widget _feedbackBanner(_Item it) {
    final good = it.good;
    final msg = good
        ? 'عالی! کشیده و نرم بود'
        : (!it.stretched && !it.soft
              ? 'کشیده‌تر و نرم‌تر'
              : (!it.stretched
                    ? 'کمی کشیده‌تر؛ هر هجا آهسته‌تر'
                    : 'شروع را نرم‌تر کن؛ اول کمی هوا'));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: good ? C.softBg : C.warmBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle : Icons.info,
            color: good ? C.softDark : C.warmDark,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: good ? C.softDark : C.warmDark,
                  ),
                ),
                Text(
                  '«${it.w.text}» · ${faNum(it.result!.durationSec, 1)} ثانیه',
                  style: TextStyle(
                    fontSize: 13,
                    color: good ? C.softDark : C.warmDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _done() {
    final first = _queue.where((i) => !i.retry).toList();
    final good = first.where((i) => i.good).length;
    final stars = starsFor(_score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        StarRow(stars: stars),
        const SizedBox(height: 12),
        Text(
          stars == 3
              ? 'فوق‌العاده!'
              : (stars == 2 ? 'آفرین!' : 'شروع خوبی بود'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: C.goldDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${faNum(good)} از ${faNum(_firstCount)} کلمه در بار اول کشیده و نرم بود',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: C.muted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final i in first)
                    Chip2(
                      i.w.text,
                      fg: i.good ? C.softDark : C.warmDark,
                      bg: i.good ? C.softBg : C.warmBg,
                    ),
                ],
              ),
            ],
          ),
        ),
        ChunkyButton(
          label: 'ادامه',
          onPressed: () => Navigator.of(context).pop(_score),
        ),
      ],
    );
  }

  Widget _message(String text, String button, VoidCallback onTap) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, height: 1.8),
      ),
      const SizedBox(height: 16),
      ChunkyButton(label: button, onPressed: onTap),
    ],
  );
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  const _Tip({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: C.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

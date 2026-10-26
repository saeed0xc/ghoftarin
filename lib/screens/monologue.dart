import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/engine.dart';
import '../audio/mic.dart';
import '../audio/recording.dart';
import '../data/store.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/playback.dart';
import '../widgets/visuals.dart';

/// Free speaking about a topic for 1 or 3 minutes (like the monologue stages
/// of the Camperdown Program): the step from reading to spontaneous speech.
class MonologueScreen extends StatefulWidget {
  final AppState app;

  /// Preset length from the daily plan; the user can still change it.
  final int? minutes;
  const MonologueScreen({super.key, required this.app, this.minutes});

  @override
  State<MonologueScreen> createState() => _MonologueScreenState();
}

const monologueTopics = [
  'روز معمولی‌ات را از صبح تا شب تعریف کن.',
  'از غذای مورد علاقه‌ات بگو و اینکه چطور درست می‌شود.',
  'سفری را که دوست داشتی تعریف کن.',
  'از یک فیلم یا کتابی که اخیراً دیدی یا خواندی بگو.',
  'محله‌ای را که در آن زندگی می‌کنی توصیف کن.',
  'از کاری که در آن خوبی بگو و چطور یادش گرفتی.',
  'برنامه‌ات برای آخر هفته‌ی بعد چیست؟',
  'از یک دوست قدیمی و یک خاطره با او بگو.',
];

enum _M { setup, calibrating, running, done }

class _MonologueScreenState extends State<MonologueScreen>
    with WidgetsBindingObserver {
  Mic? _micOrNull; // created on start, so opening the screen does not touch the microphone
  Mic get _mic => _micOrNull ??= Mic();
  final _rec = SessionRecording();
  late FluencyEngine _engine;
  _M _m = _M.setup;
  late int _minutes = widget.minutes ?? 1;
  int _topic = math.Random().nextInt(monologueTopics.length);
  double _pause = 0;
  bool _speaking = false;
  int _left = 0;
  Timer? _timer;
  final List<PhraseResult> _results = [];

  double get _wait => widget.app.waitTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Coach.of(widget.app).say('talk_intro');
  }

  /// A phone call or leaving the app ends the talk early and keeps what was
  /// said, rather than timing silence.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _micOrNull?.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _start() async {
    await Coach.stop();
    if (!await _mic.ensurePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اجازه‌ی میکروفون لازم است.')),
        );
      }
      return;
    }
    _results.clear();
    _rec.clear();
    _engine = FluencyEngine(
      config: EngineConfig(waitTarget: _wait),
      onPhrase: (r) => setState(() => _results.add(r)),
      onState: (s, e) {
        if (!mounted) return;
        if (s == EngineState.pausing && _m == _M.calibrating) {
          _left = _minutes * 60;
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted) return;
            setState(() => _left--);
            if (_left <= 0) _finish();
          });
          setState(() => _m = _M.running);
        }
        if (s == EngineState.pausing) {
          if (_speaking || (e - _pause).abs() >= 0.05 || e < _pause) {
            if (!_speaking && _pause < _wait && e >= _wait) {
              HapticFeedback.lightImpact();
            }
            setState(() {
              _speaking = false;
              _pause = e;
            });
          }
        } else if (s == EngineState.speaking) {
          setState(() {
            _speaking = true;
            _pause = e;
          });
        }
      },
    )..start();
    setState(() => _m = _M.calibrating);
    WakelockPlus.enable().catchError((_) {});
    await _mic.start((x) {
      _rec.add(x);
      _engine.addSamples(x);
    });
  }

  Future<void> _finish() async {
    if (_m == _M.done || _m == _M.setup) return;
    _m = _M.done; // guards against the timer and the button both finishing
    _timer?.cancel();
    await _mic.stop();
    WakelockPlus.disable().catchError((_) {});
    if (_results.isNotEmpty) {
      await widget.app.addSession(
        SessionRecord(
          date: DateTime.now(),
          passageId: 'talk',
          waitTarget: _wait,
          results: List.of(_results),
          kind: Kind.talk,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'صحبت آزاد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: switch (_m) {
            _M.setup => _setup(),
            _M.calibrating => [
              _topicCard(),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'چند لحظه سکوت…',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
            _M.running => _running(),
            _M.done => _done(),
          },
        ),
      ),
    );
  }

  Widget _topicCard() => AppCard(
    color: C.paper,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('موضوع', style: TextStyle(fontSize: 12, color: C.muted)),
        const SizedBox(height: 4),
        Text(
          monologueTopics[_topic],
          style: const TextStyle(
            fontFamily: kBookFont,
            fontSize: 20,
            height: 1.9,
          ),
        ),
      ],
    ),
  );

  List<Widget> _setup() => [
    const Text(
      'از خواندن به صحبت روزمره: درباره‌ی یک موضوع آزادانه حرف بزن و همان مکث و شروع نرم را به کار ببر.',
      style: TextStyle(fontSize: 13, height: 1.8, color: C.muted),
    ),
    const SizedBox(height: 12),
    _topicCard(),
    TextButton.icon(
      onPressed: () =>
          setState(() => _topic = (_topic + 1) % monologueTopics.length),
      icon: const Icon(Icons.shuffle),
      label: const Text('موضوع دیگر'),
    ),
    const SizedBox(height: 8),
    SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('۱ دقیقه')),
        ButtonSegment(value: 3, label: Text('۳ دقیقه')),
      ],
      selected: {_minutes},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _minutes = s.first),
    ),
    const SizedBox(height: 16),
    FilledButton(onPressed: _start, child: const Text('شروع')),
  ];

  List<Widget> _running() {
    final p = _pause / _wait;
    final mode = _speaking
        ? OrbMode.speaking
        : (p >= 1 ? OrbMode.ready : OrbMode.waiting);
    final total = _minutes * 60;
    return [
      _topicCard(),
      const SizedBox(height: 16),
      Center(
        child: BreathOrb(progress: p, mode: mode),
      ),
      const SizedBox(height: 10),
      Center(
        child: Text(
          switch (mode) {
            OrbMode.speaking => 'ادامه بده…',
            OrbMode.ready => 'هر وقت آماده‌ای، جمله‌ی بعد',
            _ => 'یک نفس آرام…',
          },
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: mode == OrbMode.ready ? C.softDark : C.ink,
          ),
        ),
      ),
      const SizedBox(height: 16),
      // calm time bar instead of a ticking countdown
      Semantics(
        label: 'زمان صحبت',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (1 - _left / total).clamp(0.0, 1.0),
            minHeight: 4,
            color: C.brandSoft,
            backgroundColor: C.line.withValues(alpha: 0.5),
          ),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: _finish, child: const Text('پایان')),
    ];
  }

  List<Widget> _done() {
    final s = SessionSummary.of(_results);
    return [
      const Text(
        'صحبت آزاد تمام شد',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatTile(label: 'جمله‌ها', value: faNum(s.phrases)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(label: 'مکث کافی', value: faPercent(s.pauseRatio)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(label: 'شروع نرم', value: faPercent(s.softRatio)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      PlaybackPanel(
        recording: _rec,
        results: _results,
        phrases: [
          for (var i = 0; i < _results.length; i++) 'جمله‌ی ${faNum(i + 1)}',
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'در صحبت آزاد، مکث‌ها طبیعی‌تر و کوتاه‌ترند؛ مهم این است که شروع جمله‌ها نرم بماند.',
        style: TextStyle(fontSize: 13, height: 1.8, color: C.muted),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _m = _M.setup),
        child: const Text('یک دور دیگر'),
      ),
    ];
  }
}

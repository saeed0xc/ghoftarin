import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/engine.dart';
import '../audio/mic.dart';
import '../data/partner.dart';
import '../data/store.dart';
import '../data/word_lessons.dart' show starsFor;
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/visuals.dart';

/// A conversation with the partner: it says a line out loud, then waits —
/// as long as needed — for the user's answer, measuring the pause before it
/// and how each phrase starts. Pops with the scene score (0..1), or null.
class PartnerScreen extends StatefulWidget {
  final AppState app;
  final Scene scene;
  const PartnerScreen({super.key, required this.app, required this.scene});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

enum _P { intro, noMic, partner, listening, interrupted, done }

class _Said {
  final int turn;
  final List<PhraseResult> phrases;
  _Said(this.turn, this.phrases);
  int get soft => phrases.where((p) => p.onset == OnsetClass.soft).length;
}

class _PartnerScreenState extends State<PartnerScreen>
    with WidgetsBindingObserver {
  Mic? _micOrNull;
  Mic get _mic => _micOrNull ??= Mic();
  AudioPlayer? _player;
  FluencyEngine? _engine;
  _P _s = _P.intro;
  int _turn = 0;
  final List<_Said> _said = [];
  List<PhraseResult> _now = [];
  double _pause = 0;
  bool _speaking = false;
  bool _calibrated = false;
  Timer? _quiet; // shows a gentle note if nothing is said for a long time
  bool _longQuiet = false;
  final _scroll = ScrollController();

  Scene get scene => widget.scene;
  double get _wait => widget.app.waitTarget.clamp(0.8, 1.2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quiet?.cancel();
    _player?.dispose();
    _micOrNull?.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) &&
        (_s == _P.listening || _s == _P.partner)) {
      _quiet?.cancel();
      _mic.stop();
      _player?.stop();
      _engine?.stop();
      setState(() => _s = _P.interrupted);
    }
  }

  Future<void> _begin() async {
    await Coach.stop();
    if (!await _mic.ensurePermission()) {
      setState(() => _s = _P.noMic);
      return;
    }
    WakelockPlus.enable().catchError((_) {});
    await _partnerSays();
  }

  Future<void> _partnerSays() async {
    setState(() {
      _s = _P.partner;
      _now = [];
      _longQuiet = false;
    });
    _scrollDown();
    final line = scene.turns[_turn].partner;
    try {
      final p = _player ??= AudioPlayer();
      await p.stop();
      final done = p.onPlayerComplete.first;
      await p.play(AssetSource(scene.audio(_turn)));
      await done.timeout(Duration(milliseconds: 3000 + line.length * 120));
    } catch (_) {
      // no audio (or a slow device): give the user time to read instead
      await Future<void>.delayed(
        Duration(milliseconds: 800 + line.length * 60),
      );
    }
    if (!mounted || _s != _P.partner) return;
    await _listen();
  }

  Future<void> _listen() async {
    _calibrated = false;
    _engine = FluencyEngine(
      // thinking pauses inside an answer do not split it
      config: EngineConfig(waitTarget: _wait, endMs: 1500),
      syllables: const [],
      onPhrase: (r) {
        if (!mounted) return;
        setState(() => _now.add(r));
        _quiet?.cancel();
      },
      onState: _onState,
    )..start();
    setState(() {
      _s = _P.listening;
      _pause = 0;
      _speaking = false;
    });
    _quiet?.cancel();
    _quiet = Timer(const Duration(seconds: 25), () {
      if (mounted && _now.isEmpty) setState(() => _longQuiet = true);
    });
    await _mic.start((x) => _engine?.addSamples(x));
  }

  void _onState(EngineState st, double e) {
    if (!mounted || _s != _P.listening) return;
    if (st == EngineState.pausing) {
      if (!_calibrated) _calibrated = true;
      // the answer is over after a long, calm silence
      if (_now.isNotEmpty && e >= turnEndSec) {
        _endTurn();
        return;
      }
      if (_speaking || (e - _pause).abs() >= 0.05 || e < _pause) {
        setState(() {
          _speaking = false;
          _pause = e;
        });
      }
    } else if (st == EngineState.speaking) {
      setState(() {
        _speaking = true;
        _longQuiet = false;
      });
    }
  }

  Future<void> _endTurn() async {
    if (_s != _P.listening) return;
    _quiet?.cancel();
    _s = _P.partner; // blocks a second end from the next engine callback
    await _mic.stop();
    _engine?.stop();
    _said.add(_Said(_turn, List.of(_now)));
    if (!mounted) return;
    if (_turn + 1 >= scene.turns.length) {
      await _finish();
      return;
    }
    setState(() => _turn++);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) await _partnerSays();
  }

  Future<void> _replay() async {
    if (_s != _P.listening || _now.isNotEmpty) return;
    _quiet?.cancel();
    await _mic.stop();
    _engine?.stop();
    await _partnerSays();
  }

  List<PhraseResult> get _all => [for (final s in _said) ...s.phrases];

  double get _score {
    final s = SessionSummary.of(_all);
    if (s.phrases == 0) return 0;
    return 0.7 * s.softRatio + 0.3 * s.pauseRatio;
  }

  Future<void> _finish() async {
    WakelockPlus.disable().catchError((_) {});
    if (_all.isNotEmpty) {
      await widget.app.addSession(
        SessionRecord(
          date: DateTime.now(),
          passageId: scene.id,
          waitTarget: _wait,
          results: _all,
          kind: Kind.partner,
        )..score = _score,
      );
    }
    if (!mounted) return;
    Coach.of(widget.app).say(_score >= 0.7 ? 'session_good' : 'session_ok');
    setState(() => _s = _P.done);
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
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
                            .pop(_s == _P.done ? _score : null),
                    icon: const Icon(
                      Icons.close,
                      color: C.lockedDark,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: LessonProgress(
                      value: _said.length / scene.turns.length,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (_s) {
                  _P.intro => _intro(),
                  _P.noMic => _message(
                    'برای گفت‌وگو، اجازه‌ی میکروفون لازم است. صدا فقط روی همین گوشی تحلیل می‌شود.',
                    'دوباره امتحان کن',
                    _begin,
                  ),
                  _P.interrupted => _message(
                    'گفت‌وگو متوقف شد. از همین جمله ادامه می‌دهیم.',
                    'ادامه',
                    () {
                      WakelockPlus.enable().catchError((_) {});
                      _partnerSays();
                    },
                  ),
                  _P.done => _done(),
                  _ => _chat(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: _Avatar(level: scene.level, size: 88)),
      const SizedBox(height: 12),
      Text(
        scene.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      Text(
        'هم‌صحبت تو: ${scene.role}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, color: C.muted),
      ),
      const SizedBox(height: 20),
      const AppCard(
        child: Text(
          'هم‌صحبت جمله‌اش را بلند می‌گوید و بعد صبر می‌کند؛ هر قدر لازم باشد. '
          'یک نفس آرام بکش، جوابت را با شروع نرم بگو و هر وقت حرفت تمام شد، کمی ساکت بمان. '
          'لازم نیست جوابت درست یا کامل باشد؛ مهم آرام حرف زدن است.',
          style: TextStyle(fontSize: 15, height: 1.9),
        ),
      ),
      const Spacer(),
      ChunkyButton(label: 'شروع گفت‌وگو', onPressed: _begin, icon: Icons.forum),
    ],
  );

  Widget _chat() {
    final listening = _s == _P.listening;
    final p = _pause / _wait;
    final mode = !_calibrated
        ? OrbMode.idle
        : (_speaking
              ? OrbMode.speaking
              : (p >= 1 ? OrbMode.ready : OrbMode.waiting));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            children: [
              for (var t = 0; t <= _turn && t < scene.turns.length; t++) ...[
                _PartnerBubble(scene: scene, text: scene.turns[t].partner),
                if (t == _turn &&
                    scene.turns[t].hint.isNotEmpty &&
                    (listening || _s == _P.partner))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 56, top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: C.goldDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            scene.turns[t].hint,
                            style: const TextStyle(
                              fontSize: 13,
                              color: C.muted,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (t < _said.length) _UserBubble(said: _said[t]),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (listening) ...[
          Row(
            children: [
              BreathOrb(progress: p, mode: mode, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _longQuiet
                      ? 'هر وقت آماده بودی جواب بده؛ هم‌صحبت منتظر می‌ماند.'
                      : switch (mode) {
                          OrbMode.idle => 'یک نفس آرام…',
                          OrbMode.speaking => 'گوش می‌دهم…',
                          OrbMode.ready =>
                            _now.isEmpty
                                ? 'هر وقت آماده‌ای، نرم شروع کن'
                                : 'اگر حرفت تمام شد، کمی ساکت بمان',
                          _ => 'یک نفس آرام…',
                        },
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: mode == OrbMode.ready ? C.softDark : C.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _now.isEmpty ? _replay : null,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('دوباره بگو'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyButton(
                  label: _now.isEmpty ? 'رد شو' : 'جوابم تمام شد',
                  color: _now.isEmpty ? C.surface : C.blue,
                  shadow: _now.isEmpty ? C.line : C.blueDark,
                  textColor: _now.isEmpty ? C.muted : Colors.white,
                  onPressed: _endTurn,
                ),
              ),
            ],
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.graphic_eq, color: C.blue),
                SizedBox(width: 8),
                Text(
                  'هم‌صحبت حرف می‌زند…',
                  style: TextStyle(fontSize: 15, color: C.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _done() {
    final s = SessionSummary.of(_all);
    final stars = s.phrases == 0 ? 1 : starsFor(_score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        StarRow(stars: stars),
        const SizedBox(height: 12),
        const Text(
          'گفت‌وگو تمام شد',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: C.goldDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatTile(label: 'جمله‌های تو', value: faNum(s.phrases)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'شروع نرم',
                value: faPercent(s.softRatio),
                valueColor: C.softDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'مکث پیش از جواب',
                value: faPercent(s.pauseRatio),
                valueColor: C.blueDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          s.softRatio >= 0.8
              ? 'در یک گفت‌وگوی واقعی، شروع‌ها نرم ماند. همین را امروز با یک آدم واقعی امتحان کن.'
              : 'گفت‌وگو سخت‌تر از خواندن است و این طبیعی است. پیش از هر جواب، یک نفس و یک شروع نرم.',
          style: const TextStyle(fontSize: 14, height: 1.8, color: C.muted),
        ),
        const Spacer(),
        ChunkyButton(
          label: 'ادامه',
          onPressed: () => Navigator.of(context).pop(_score),
        ),
      ],
    );
  }

  Widget _message(String text, String button, VoidCallback onTap) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
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

class _Avatar extends StatelessWidget {
  final int level;
  final double size;
  const _Avatar({required this.level, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (level) {
        1 => C.blue,
        2 => C.purple,
        _ => C.warm,
      },
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: C.line, offset: Offset(0, 3))],
    ),
    child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
  );
}

class _PartnerBubble extends StatelessWidget {
  final Scene scene;
  final String text;
  const _PartnerBubble({required this.scene, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: C.surface,
            border: Border.all(color: C.line, width: 2),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(18),
              topEnd: Radius.circular(18),
              bottomStart: Radius.circular(18),
              bottomEnd: Radius.circular(4),
            ).resolve(Directionality.of(context)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 17, height: 1.8)),
        ),
      ),
      const SizedBox(width: 8),
      _Avatar(level: scene.level),
    ],
  );
}

class _UserBubble extends StatelessWidget {
  final _Said said;
  const _UserBubble({required this.said});

  @override
  Widget build(BuildContext context) {
    final n = said.phrases.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: n == 0 ? C.line : C.blueBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 0 ? 'رد شد' : 'جواب تو · ${faNum(n)} جمله',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.blueDark,
                  ),
                ),
                if (n > 0) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in said.phrases)
                        switch (p.onset) {
                          OnsetClass.soft => const Chip2(
                            'نرم',
                            fg: C.softDark,
                            bg: C.softBg,
                          ),
                          OnsetClass.medium => const Chip2(
                            'متوسط',
                            fg: C.blueDark,
                            bg: Colors.white,
                          ),
                          OnsetClass.hard => const Chip2(
                            'ناگهانی',
                            fg: C.warmDark,
                            bg: C.warmBg,
                          ),
                        },
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/engine.dart';
import '../audio/mic.dart';
import '../audio/recording.dart';
import '../data/content.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'guide.dart';

/// Live reading: listens to the mic, lights the current phrase, fills the
/// breath ring during the pause and rates each phrase start.
/// [guided] = false is the assessment mode: no ring target, natural reading.
class SessionView extends StatefulWidget {
  final Passage passage;
  final double waitTarget;
  final bool guided;
  final void Function(List<PhraseResult> results) onFinished;
  final VoidCallback onClose;

  /// When given, the session audio is kept here for listening back.
  final SessionRecording? recording;

  const SessionView({
    super.key,
    required this.passage,
    required this.waitTarget,
    required this.guided,
    required this.onFinished,
    required this.onClose,
    this.recording,
  });

  @override
  State<SessionView> createState() => _SessionViewState();
}

enum _Ui {
  intro,
  noPermission,
  calibrating,
  pausing,
  speaking,
  interrupted,
  done,
}

class _SessionViewState extends State<SessionView> with WidgetsBindingObserver {
  final _mic = Mic();
  late FluencyEngine _engine;
  _Ui _ui = _Ui.intro;
  double _pause = 0;
  PhraseResult? _last;
  final List<PhraseResult> _results = [];
  String? _notice; // microphone / room quality hint
  bool _buzzed = false;
  int _seenResets = 0;

  int get _index => _results.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = FluencyEngine(
      config: EngineConfig(waitTarget: widget.waitTarget),
      syllables: widget.passage.syllables,
      phraseTotal: widget.passage.phrases.length,
      onState: _onState,
      onPhrase: _onPhrase,
    );
  }

  bool get _listening =>
      _ui == _Ui.calibrating || _ui == _Ui.pausing || _ui == _Ui.speaking;

  /// A phone call or leaving the app cuts the microphone: stop cleanly and
  /// offer to continue from the same phrase, instead of measuring silence.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) &&
        _listening) {
      _mic.stop();
      _engine.stop();
      WakelockPlus.disable().catchError((_) {});
      setState(() => _ui = _Ui.interrupted);
    }
  }

  Future<void> _resume() async {
    await Coach.stop();
    if (!await _mic.ensurePermission()) {
      setState(() => _ui = _Ui.noPermission);
      return;
    }
    _engine.resume();
    setState(() => _ui = _Ui.calibrating);
    WakelockPlus.enable().catchError((_) {});
    final rec = widget.recording;
    await _mic.start(
      rec == null
          ? _engine.addSamples
          : (samples) {
              rec.add(samples);
              _engine.addSamples(samples);
            },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mic.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _start() async {
    await Coach.stop(); // never let the coach's voice into the calibration
    final ok = await _mic.ensurePermission();
    if (!ok) {
      setState(() => _ui = _Ui.noPermission);
      return;
    }
    _results.clear();
    _last = null;
    _notice = null;
    _seenResets = 0;
    widget.recording?.clear();
    _engine.start();
    setState(() => _ui = _Ui.calibrating);
    // keep the screen on: a sleeping screen stops the microphone
    WakelockPlus.enable().catchError((_) {});
    final rec = widget.recording;
    await _mic.start(
      rec == null
          ? _engine.addSamples
          : (samples) {
              rec.add(samples);
              _engine.addSamples(samples);
            },
    );
  }

  void _onState(EngineState s, double elapsed) {
    if (!mounted) return;
    switch (s) {
      case EngineState.calibrating:
        if (_ui != _Ui.calibrating) setState(() => _ui = _Ui.calibrating);
      case EngineState.pausing:
        final changed =
            _ui != _Ui.pausing ||
            (elapsed - _pause).abs() >= 0.05 ||
            elapsed < _pause;
        if (_ui == _Ui.calibrating && _engine.noisyRoom) {
          _notice = 'اتاق پرسروصداست و اندازه‌گیری‌ها دقیق نیست. اگر می‌توانی جای آرام‌تری برو یا گوشی را نزدیک‌تر بگذار.';
        }
        if (_engine.noiseResets > _seenResets) {
          _seenResets = _engine.noiseResets;
          _notice = 'صدای ثابتی در اتاق شروع شد (مثل پنکه یا کولر). اپ خودش را تنظیم کرد؛ اگر می‌شود آن را خاموش کن.';
        }
        // a short vibration when the ring fills, so eyes can stay on the text
        if (widget.guided && !_buzzed && elapsed >= widget.waitTarget) {
          _buzzed = true;
          HapticFeedback.lightImpact();
        }
        if (changed) {
          setState(() {
            if (_ui != _Ui.pausing) {
              _buzzed = elapsed >= widget.waitTarget;
            }
            _ui = _Ui.pausing;
            _pause = elapsed;
          });
        }
      case EngineState.speaking:
        setState(() {
          _ui = _Ui.speaking;
          _pause = elapsed;
        });
      case EngineState.done:
        _finish();
      case EngineState.idle:
        break;
    }
  }

  void _onPhrase(PhraseResult r) {
    if (!mounted) return;
    setState(() {
      _results.add(r);
      _last = r;
      if (r.peak >= 0.98) {
        _notice = 'صدا به حداکثر رسید و بریده شد. گوشی را کمی دورتر بگذار (حدود ۳۰ سانتی‌متر).';
      } else if (r.peak > 0 && r.peak < 0.03) {
        _notice = 'صدا خیلی آهسته به میکروفون می‌رسد. گوشی را نزدیک‌تر بگذار.';
      }
    });
  }

  void _redo() {
    final r = _engine.undoLast();
    if (r == null) return;
    setState(() {
      _results.removeLast();
      _last = _results.isEmpty ? null : _results.last;
    });
  }

  Future<void> _finish() async {
    await _mic.stop();
    WakelockPlus.disable().catchError((_) {});
    if (!mounted) return;
    setState(() => _ui = _Ui.done);
    widget.onFinished(List.unmodifiable(_results));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final n = widget.passage.phrases.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'بستن',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: C.surface,
                    side: const BorderSide(color: C.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(44, 44),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.guided
                                ? (widget.passage.id.startsWith('lesson') ||
                                          widget.passage.id.startsWith(
                                            'words',
                                          ) ||
                                          widget.passage.id == 'slow'
                                      ? widget.passage.title
                                      : 'خواندن کتاب: ${widget.passage.title}')
                                : 'ارزیابی: خواندن متن',
                            style: const TextStyle(
                              fontSize: 12,
                              color: C.muted,
                            ),
                          ),
                          Text(
                            'عبارت ${faNum((_index + 1).clamp(1, n))} از ${faNum(n)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: C.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _index / n,
                          minHeight: 6,
                          color: C.brand,
                          backgroundColor: C.line,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BookPage(
              source: widget.passage.source,
              phrases: widget.passage.phrases,
              separator: widget.passage.separator,
              current:
                  _ui == _Ui.intro ||
                      _ui == _Ui.noPermission ||
                      _ui == _Ui.calibrating
                  ? -1
                  : _index,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stage(),
                    if (_notice != null) ...[
                      const SizedBox(height: 10),
                      AppCard(
                        color: C.warmBg,
                        border: false,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.mic_external_on_outlined,
                              color: C.warmDark,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _notice!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_ui == _Ui.intro || _ui == _Ui.noPermission)
              FilledButton(
                onPressed: _start,
                child: Text(
                  _ui == _Ui.noPermission ? 'دوباره امتحان کن' : 'شروع',
                ),
              ),
            if (_ui == _Ui.pausing && _results.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _redo,
                icon: const Icon(Icons.replay),
                label: const Text('عبارت قبلی را دوباره بخوانم'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stage() {
    switch (_ui) {
      case _Ui.intro:
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.guided ? 'چطور تمرین کنیم' : 'چطور بخوانیم',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.guided
                    ? 'گوشی را جلوی خودت بگذار. پیش از هر عبارت، همراه با بزرگ شدن دایره یک نفس آرام بکش. وقتی سبز شد، هر وقت آماده بودی عبارت پررنگ را با شروع نرم بگو. عجله‌ای نیست؛ بین عبارت‌ها ساکت بمان.'
                    : 'متن را مثل همیشه و بدون تکنیک خاصی بلند بخوان. بین عبارت‌ها کمی مکث کن تا هر عبارت جدا شناخته شود. ابتدا چند لحظه سکوت لازم است.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: Color(0xFF33454B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'صدا فقط روی همین گوشی تحلیل می‌شود و ذخیره یا ارسال نمی‌شود.',
                style: TextStyle(fontSize: 12, color: C.muted),
              ),
              if (widget.guided)
                const Wrap(
                  children: [
                    GuideLink(pageId: 'pause', label: 'مکث چطور؟'),
                    GuideLink(pageId: 'soft', label: 'شروع نرم چطور؟'),
                  ],
                ),
            ],
          ),
        );
      case _Ui.noPermission:
        return AppCard(
          color: C.warnBg,
          border: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'برای تمرین، اپ به میکروفون نیاز دارد. صدا فقط روی همین گوشی تحلیل می‌شود. اگر قبلاً اجازه نداده‌ای، از تنظیمات گوشی › برنامه‌ها › گفتارین › مجوزها میکروفون را روشن کن.',
                style: TextStyle(fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _start,
                child: const Text('دوباره امتحان کن'),
              ),
            ],
          ),
        );
      case _Ui.interrupted:
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.pause_circle_outline, size: 48, color: C.brand),
              const SizedBox(height: 8),
              const Text(
                'تمرین متوقف شد',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _results.isEmpty
                    ? 'از اول عبارت اول ادامه می‌دهیم.'
                    : '${faNum(_results.length)} عبارت ثبت شده است. از عبارت ${faNum(_results.length + 1)} ادامه می‌دهیم.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: C.muted,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _resume, child: const Text('ادامه')),
            ],
          ),
        );
      case _Ui.calibrating:
        return _ringCard(
          ring: const BreathOrb(progress: 0, mode: OrbMode.idle),
          title: 'چند لحظه سکوت…',
          hint: 'سطح صدای اتاق را اندازه می‌گیرم.',
        );
      case _Ui.pausing:
        if (!widget.guided) {
          return _ringCard(
            ring: const BreathOrb(progress: 0, mode: OrbMode.idle, size: 120),
            title: 'عبارت پررنگ را بخوان',
            hint: 'مثل همیشه بخوان.',
          );
        }
        final p = _pause / widget.waitTarget;
        final ready = p >= 1;
        return _ringCard(
          ring: BreathOrb(
            progress: p,
            mode: ready ? OrbMode.ready : OrbMode.waiting,
          ),
          title: ready ? 'هر وقت آماده‌ای' : 'یک نفس آرام…',
          titleColor: ready ? C.softDark : C.ink,
          hint: ready
              ? 'عبارت پررنگ را با صدایی آهسته شروع کن؛ عجله‌ای نیست.'
              : 'همراه با بزرگ شدن دایره، آرام نفس بکش.',
          extra: _last == null ? null : _lastResult(_last!),
        );
      case _Ui.speaking:
        // no warning while the person is speaking: interrupting attention
        // mid-phrase adds pressure. The gentle note comes after the phrase.
        return _ringCard(
          ring: BreathOrb(
            progress: 1,
            mode: OrbMode.speaking,
            size: widget.guided ? 176 : 120,
          ),
          title: 'ادامه بده…',
          hint: 'آرام و پیوسته.',
        );
      case _Ui.done:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
    }
  }

  Widget _ringCard({
    required Widget ring,
    required String title,
    required String hint,
    Color titleColor = C.ink,
    Widget? extra,
  }) {
    return AppCard(
      child: Column(
        children: [
          ring,
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: C.muted),
          ),
          if (extra != null) ...[const SizedBox(height: 14), extra],
        ],
      ),
    );
  }

  Widget _lastResult(PhraseResult r) {
    final (label, color) = switch (r.onset) {
      OnsetClass.soft => ('شروع نرم بود', C.soft),
      OnsetClass.medium => ('شروع متوسط', C.brand),
      OnsetClass.hard => ('شروع کمی ناگهانی بود', C.warm),
    };
    final note = r.early
        ? 'مکث کمی کوتاه بود؛ این بار دایره را تا آخر همراهی کن.'
        : null;
    return Column(
      children: [
        const Divider(color: C.line, height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'عبارت قبل: ',
              style: const TextStyle(fontSize: 13, color: C.muted),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        OnsetWave(values: r.onsetEnvelope, color: color, height: 44),
        if (widget.guided && note != null) ...[
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontSize: 12, color: C.warmDark)),
        ],
      ],
    );
  }
}

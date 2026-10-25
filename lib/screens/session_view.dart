import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../audio/mic.dart';
import '../data/content.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';

/// Live reading: listens to the mic, lights the current phrase, fills the
/// breath ring during the pause and rates each phrase start.
/// [guided] = false is the assessment mode: no ring target, natural reading.
class SessionView extends StatefulWidget {
  final Passage passage;
  final double waitTarget;
  final bool guided;
  final void Function(List<PhraseResult> results) onFinished;
  final VoidCallback onClose;

  const SessionView({
    super.key,
    required this.passage,
    required this.waitTarget,
    required this.guided,
    required this.onFinished,
    required this.onClose,
  });

  @override
  State<SessionView> createState() => _SessionViewState();
}

enum _Ui { intro, noPermission, calibrating, pausing, speaking, done }

class _SessionViewState extends State<SessionView> {
  final _mic = Mic();
  late FluencyEngine _engine;
  _Ui _ui = _Ui.intro;
  double _pause = 0;
  bool _earlyNow = false;
  DateTime _lastCue = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showEarlyText = false;
  PhraseResult? _last;
  final List<PhraseResult> _results = [];

  int get _index => _results.length;

  @override
  void initState() {
    super.initState();
    _engine = FluencyEngine(
      config: EngineConfig(waitTarget: widget.waitTarget),
      syllables: widget.passage.syllables,
      onState: _onState,
      onPhrase: _onPhrase,
    );
  }

  @override
  void dispose() {
    _mic.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await _mic.ensurePermission();
    if (!ok) {
      setState(() => _ui = _Ui.noPermission);
      return;
    }
    _results.clear();
    _last = null;
    _engine.start();
    setState(() => _ui = _Ui.calibrating);
    await _mic.start(_engine.addSamples);
  }

  void _onState(EngineState s, double elapsed) {
    if (!mounted) return;
    switch (s) {
      case EngineState.calibrating:
        if (_ui != _Ui.calibrating) setState(() => _ui = _Ui.calibrating);
      case EngineState.pausing:
        final changed = _ui != _Ui.pausing || (elapsed - _pause).abs() >= 0.05 || elapsed < _pause;
        if (changed) {
          setState(() {
            if (_ui != _Ui.pausing) {
              _earlyNow = false;
              _showEarlyText = false;
            }
            _ui = _Ui.pausing;
            _pause = elapsed;
          });
        }
      case EngineState.speaking:
        final early = widget.guided && elapsed < widget.waitTarget;
        final now = DateTime.now();
        // at most one spoken-style cue every 20 s (spec); the ring colour always shows
        final showText = early && now.difference(_lastCue).inSeconds >= 20;
        if (showText) _lastCue = now;
        setState(() {
          _ui = _Ui.speaking;
          _earlyNow = early;
          _showEarlyText = showText;
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
            Row(children: [
              IconButton.outlined(
                tooltip: 'بستن',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                    backgroundColor: C.surface,
                    side: const BorderSide(color: C.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(44, 44)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(widget.guided ? 'خواندن کتاب' : 'ارزیابی: خواندن متن',
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                    Text('عبارت ${faNum((_index + 1).clamp(1, n))} از ${faNum(n)}',
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: _index / n, minHeight: 6, color: C.brand, backgroundColor: C.line),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            BookPage(
              source: widget.passage.source,
              phrases: widget.passage.phrases,
              current: _ui == _Ui.intro || _ui == _Ui.noPermission || _ui == _Ui.calibrating ? -1 : _index,
            ),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: _stage())),
            const SizedBox(height: 12),
            if (_ui == _Ui.intro || _ui == _Ui.noPermission)
              FilledButton(onPressed: _start, child: Text(_ui == _Ui.noPermission ? 'دوباره امتحان کن' : 'شروع')),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.guided ? 'چطور تمرین کنیم' : 'چطور بخوانیم',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              widget.guided
                  ? 'گوشی را جلوی خودت بگذار. پیش از هر عبارت صبر کن تا حلقه پر شود (${faNum(widget.waitTarget, 1)} ثانیه)، بعد عبارت پررنگ را با صدایی بسیار آرام شروع کن و بگذار کم‌کم بلند شود. بین عبارت‌ها ساکت بمان.'
                  : 'متن را مثل همیشه و بدون تکنیک خاصی بلند بخوان. بین عبارت‌ها کمی مکث کن تا هر عبارت جدا شناخته شود. ابتدا چند لحظه سکوت لازم است.',
              style: const TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF33454B)),
            ),
            const SizedBox(height: 8),
            const Text('صدا فقط روی همین گوشی تحلیل می‌شود و ذخیره یا ارسال نمی‌شود.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ]),
        );
      case _Ui.noPermission:
        return const AppCard(
          color: C.warnBg,
          border: false,
          child: Text('برای تمرین، اپ به میکروفون نیاز دارد. اجازه‌ی میکروفون را بده؛ اگر قبلاً رد کرده‌ای، از تنظیمات گوشی › برنامه‌ها › گفتارین › مجوزها آن را روشن کن.',
              style: TextStyle(fontSize: 14, height: 1.8)),
        );
      case _Ui.calibrating:
        return _ringCard(
          ring: const BreathRing(progress: 0.15, label: '…'),
          title: 'چند لحظه سکوت…',
          hint: 'سطح صدای اتاق را اندازه می‌گیرم.',
        );
      case _Ui.pausing:
        if (!widget.guided) {
          return _ringCard(
            ring: BreathRing(progress: 0, label: faNum(_index + 1), color: C.brand),
            title: 'عبارت پررنگ را بخوان',
            hint: 'مثل همیشه بخوان.',
          );
        }
        final p = _pause / widget.waitTarget;
        final ready = p >= 1;
        return _ringCard(
          ring: BreathRing(
            progress: p,
            color: ready ? C.soft : C.brand,
            label: ready ? '✓' : faNum((widget.waitTarget - _pause).clamp(0, 9), 1),
          ),
          title: ready ? 'حالا آرام شروع کن' : 'نفس بکش و صبر کن',
          titleColor: ready ? C.softDark : C.ink,
          hint: ready
              ? 'صدای اول را خیلی آهسته بگو و بگذار کم‌کم بلند شود.'
              : 'وقتی حلقه پر شد، عبارت پررنگ را آرام شروع کن.',
          extra: _last == null ? null : _lastResult(_last!),
        );
      case _Ui.speaking:
        return _ringCard(
          ring: BreathRing(
            progress: 1,
            color: !widget.guided ? C.brand : (_earlyNow ? C.warn : C.soft),
            label: !widget.guided ? faNum(_index + 1) : (_earlyNow ? '!' : '✓'),
          ),
          title: _showEarlyText ? 'کمی زود شروع کردی' : 'ادامه بده…',
          titleColor: _showEarlyText ? C.warn : C.ink,
          hint: _showEarlyText
              ? 'این عبارت را تمام کن؛ پیش از عبارت بعد صبر کن تا حلقه پر شود.'
              : 'آرام و پیوسته.',
        );
      case _Ui.done:
        return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
  }

  Widget _ringCard({required Widget ring, required String title, required String hint, Color titleColor = C.ink, Widget? extra}) {
    return AppCard(
      child: Column(children: [
        ring,
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor)),
        const SizedBox(height: 4),
        Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.muted)),
        if (extra != null) ...[const SizedBox(height: 14), extra],
      ]),
    );
  }

  Widget _lastResult(PhraseResult r) {
    final (label, color) = switch (r.onset) {
      OnsetClass.soft => ('شروع نرم بود', C.soft),
      OnsetClass.medium => ('شروع متوسط', C.brand),
      OnsetClass.hard => ('شروع کمی ناگهانی بود', C.warm),
    };
    return Column(children: [
      const Divider(color: C.line, height: 1),
      const SizedBox(height: 10),
      Row(children: [
        Text('عبارت قبل: ', style: const TextStyle(fontSize: 13, color: C.muted)),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 6),
      OnsetWave(values: r.onsetEnvelope, color: color, height: 44),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _mini('${faNum(r.pauseSec, 1)} ث', 'مکث', warn: widget.guided && r.early)),
        const SizedBox(width: 8),
        Expanded(child: _mini('${faNum(r.riseMs)} م‌ث', 'اوج‌گیری')),
        const SizedBox(width: 8),
        Expanded(child: _mini(r.syllablesPerSec == null ? '—' : faNum(r.syllablesPerSec!, 1), 'هجا/ثانیه')),
      ]),
    ]);
  }

  Widget _mini(String v, String l, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: warn ? C.warnBg : C.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: warn ? C.warn : C.ink)),
          Text(l, style: const TextStyle(fontSize: 11, color: C.muted)),
        ]),
      );
}

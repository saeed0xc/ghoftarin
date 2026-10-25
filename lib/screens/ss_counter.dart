import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/recording.dart';
import '../fa.dart';
import '../theme.dart';

class SsResult {
  final double percent;
  final String rater;
  const SsResult(this.percent, this.rater);
}

const raterNames = {
  'self': 'خودم',
  'parent': 'والد',
  'therapist': 'گفتاردرمانگر',
};

/// Percent syllables stuttered (%SS), counted by a listener: play the reading
/// back and tap once for every clearly stuttered syllable. This is the
/// standard clinical measure; the denominator is the known syllable count of
/// the text that was read.
class SsCounterScreen extends StatefulWidget {
  final SessionRecording recording;
  final int totalSyllables;
  final bool forChild;
  const SsCounterScreen({
    super.key,
    required this.recording,
    required this.totalSyllables,
    this.forChild = false,
  });

  @override
  State<SsCounterScreen> createState() => _SsCounterScreenState();
}

class _SsCounterScreenState extends State<SsCounterScreen> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  late String _rater = widget.forChild ? 'parent' : 'self';
  int _count = 0;
  bool _playing = false;
  bool _finished = false;
  Duration _pos = Duration.zero;

  Duration get _total =>
      Duration(milliseconds: (widget.recording.seconds * 1000).round());

  @override
  void initState() {
    super.initState();
    _subs.add(
      _player.onPositionChanged.listen((p) => setState(() => _pos = p)),
    );
    _subs.add(
      _player.onPlayerComplete.listen(
        (_) => setState(() {
          _playing = false;
          _finished = true;
          _pos = _total;
        }),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    if (_pos == Duration.zero || _finished) {
      setState(() {
        _count = 0;
        _finished = false;
      });
      await _player.play(
        BytesSource(widget.recording.toWav(), mimeType: 'audio/wav'),
      );
    } else {
      await _player.resume();
    }
    setState(() => _playing = true);
  }

  double get _percent =>
      widget.totalSyllables == 0 ? 0 : _count * 100 / widget.totalSyllables;

  String _clock(Duration d) => faDigits(
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
  );

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'شمارش هجاهای لکنت‌دار',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const AppCard(
            color: C.brandTint,
            border: false,
            child: Text(
              'به ضبط خواندن گوش کن و برای هر هجایی که لکنت آشکار داشت یک بار دکمه را بزن: تکرار صدا یا هجا («پ‌پ‌پدر»)، کشیدن صدا («ســـلام»)، یا گیر کردن پیش از کلمه. این همان روشی است که گفتاردرمانگرها برای اندازه‌گیری «درصد هجاهای لکنت‌دار» به کار می‌برند. اگر گفتاردرمانگر یا یکی از والدین بشمارد، دقیق‌تر است.',
              style: TextStyle(fontSize: 13, height: 1.9),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'چه کسی می‌شمارد؟',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final e in raterNames.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {_rater},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _rater = s.first),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      iconSize: 30,
                      tooltip: _playing ? 'توقف' : 'پخش',
                      onPressed: _toggle,
                      icon: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: C.brand,
                          backgroundColor: C.line,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_clock(_pos)} / ${_clock(_total)}',
                      style: const TextStyle(fontSize: 12, color: C.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Semantics(
                  button: true,
                  label: 'یک هجای لکنت‌دار',
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: ElevatedButton(
                      onPressed: _playing
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _count++);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: C.warm,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE9EDEA),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            faNum(_count),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text('لکنت', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _count > 0 ? () => setState(() => _count--) : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('یکی کم کن'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_finished) ...[
            AppCard(
              child: Column(
                children: [
                  Text(
                    '${faNum(_percent, 1)}٪',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: C.brandDark,
                    ),
                  ),
                  Text(
                    'هجاهای لکنت‌دار (${faNum(_count)} از ${faNum(widget.totalSyllables)} هجا)',
                    style: const TextStyle(fontSize: 13, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(SsResult(_percent, _rater)),
              child: const Text('ثبت'),
            ),
          ] else
            const Text(
              'تا پایان ضبط گوش کن؛ بعد نتیجه نشان داده می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: C.muted),
            ),
        ],
      ),
    );
  }
}

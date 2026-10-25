import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../audio/recording.dart';
import '../fa.dart';
import '../theme.dart';
import 'visuals.dart';

/// Listen back to the session, phrase by phrase (Camperdown-style
/// self-evaluation). The audio lives only in memory.
class PlaybackPanel extends StatefulWidget {
  final SessionRecording recording;
  final List<PhraseResult> results;
  final List<String> phrases;
  const PlaybackPanel({
    super.key,
    required this.recording,
    required this.results,
    required this.phrases,
  });

  @override
  State<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<PlaybackPanel> {
  final _player = AudioPlayer();
  int? _playing; // phrase index, -1 = all
  StreamSubscription<void>? _done;

  @override
  void initState() {
    super.initState();
    _done = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _done?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(int i) async {
    await _player.stop();
    if (_playing == i) {
      setState(() => _playing = null);
      return;
    }
    final rec = widget.recording;
    final bytes = i < 0
        ? rec.toWav()
        : rec.toWav(
            fromSec: widget.results[i].startSec - 0.4,
            toSec: widget.results[i].endSec + 0.3,
          );
    setState(() => _playing = i);
    try {
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recording.lengthSamples == 0 || widget.results.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'به خودت گوش کن',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'شروع نرم بود؟ مکث کافی بود؟ ضبط فقط تا جلسه‌ی بعد روی گوشی می‌ماند.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: C.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'پخش کل جلسه',
                onPressed: () => _play(-1),
                icon: Icon(
                  _playing == -1
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in widget.results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'پخش عبارت ${faNum(r.index + 1)}',
                    onPressed: () => _play(r.index),
                    icon: Icon(
                      _playing == r.index
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color: C.brand,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.index < widget.phrases.length
                          ? widget.phrases[r.index]
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  switch (r.onset) {
                    OnsetClass.soft => const Chip2(
                      'نرم',
                      fg: C.softDark,
                      bg: C.softBg,
                    ),
                    OnsetClass.medium => const Chip2('متوسط'),
                    OnsetClass.hard => const Chip2(
                      'ناگهانی',
                      fg: C.warmDark,
                      bg: C.warmBg,
                    ),
                  },
                ],
              ),
            ),
        ],
      ),
    );
  }
}

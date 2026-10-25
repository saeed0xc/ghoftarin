import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/self_rating.dart';
import '../widgets/visuals.dart';
import 'session_view.dart';

/// A practice session: guided reading → summary + daily self-rating → saved.
class PracticeScreen extends StatefulWidget {
  final AppState app;
  final Passage passage;
  const PracticeScreen({super.key, required this.app, required this.passage});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<PhraseResult>? _results;
  int? _rating;
  late final double _wait = widget.app.waitTarget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _results == null
          ? SessionView(
              passage: widget.passage,
              waitTarget: _wait,
              guided: true,
              onClose: () => Navigator.of(context).pop(),
              onFinished: (r) => setState(() => _results = r),
            )
          : _summary(),
    );
  }

  Widget _summary() {
    final rs = _results!;
    final s = SessionSummary.of(rs);
    final needRating = widget.app.todaySession?.selfRating == null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(widget.passage.title, style: const TextStyle(fontSize: 13, color: C.muted)),
          const Text('آفرین، جلسه تمام شد', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatTile(label: 'مکث کافی', value: '${faNum(s.pauseOkCount)} از ${faNum(s.phrases)}')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(label: 'شروع نرم', value: '${faNum(s.softCount)} از ${faNum(s.phrases)}')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: StatTile(label: 'میانه‌ی مکث', value: '${faNum(s.medianPause, 1)} ث')),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(label: 'سرعت', value: s.meanRate == null ? '—' : faNum(s.meanRate!, 1), note: 'هجا در ثانیه')),
          ]),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final r in rs) _phraseRow(r),
            ]),
          ),
          if (needRating) ...[
            const SizedBox(height: 12),
            AppCard(child: SelfRating(value: _rating, forChild: widget.app.forChild, onChanged: (v) => setState(() => _rating = v))),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: needRating && _rating == null ? null : _save,
            child: const Text('ذخیره و پایان'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بدون ذخیره خارج شو')),
        ],
      ),
    );
  }

  Widget _phraseRow(PhraseResult r) {
    final (label, fg, bg) = switch (r.onset) {
      OnsetClass.soft => ('نرم', C.softDark, C.softBg),
      OnsetClass.medium => ('متوسط', C.brandDark, C.brandTint),
      OnsetClass.hard => ('ناگهانی', C.warmDark, C.warmBg),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 26, child: Text(faNum(r.index + 1), style: const TextStyle(color: C.muted))),
        Expanded(
          child: Text(widget.passage.phrases[r.index],
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        r.early
            ? Chip2('${faNum(r.pauseSec, 1)} ث', fg: C.warn, bg: C.warnBg)
            : Chip2('${faNum(r.pauseSec, 1)} ث', fg: C.muted, bg: C.bg),
        const SizedBox(width: 6),
        Chip2(label, fg: fg, bg: bg),
      ]),
    );
  }

  Future<void> _save() async {
    final rec = SessionRecord(
      date: DateTime.now(),
      passageId: widget.passage.id,
      waitTarget: _wait,
      results: _results!,
      selfRating: _rating,
    );
    final before = widget.app.waitTarget;
    await widget.app.addSession(rec);
    if (!mounted) return;
    if (widget.app.waitTarget < before) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('عالی! سه جلسه پشت سر هم مکث‌ها درست بود. زمان مکث از این به بعد ${faNum(widget.app.waitTarget, 1)} ثانیه است.',
            style: const TextStyle(fontFamily: kUiFont)),
      ));
    }
    Navigator.of(context).pop();
  }
}

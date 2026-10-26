import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../data/store.dart';
import '../data/words.dart';
import '../fa.dart';
import '../services/coach.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'guide.dart';
import 'session_view.dart';

/// Word practice: choose hard sounds, then climb the ladder
/// word → two-word phrase → short sentence.
class WordsScreen extends StatefulWidget {
  final AppState app;
  const WordsScreen({super.key, required this.app});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  late final Set<String> _sel = {...widget.app.wordGroups};

  AppState get app => widget.app;

  @override
  Widget build(BuildContext context) {
    final techs = _sel.map((id) => groupById(id).technique).toSet();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'تمرین کلمه',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Text(
            'روی کدام صداها بیشتر گیر می‌کنی؟',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'یک تا سه صدا انتخاب کن. کلمه‌ها، عبارت‌ها و جمله‌ها با همین صداها شروع می‌شوند.',
            style: TextStyle(fontSize: 13, height: 1.7, color: C.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in soundGroups)
                FilterChip(
                  label: Text(
                    g.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: _sel.contains(g.id),
                  onSelected: (on) => setState(() {
                    if (on && _sel.length < 3) {
                      _sel.add(g.id);
                    } else {
                      _sel.remove(g.id);
                    }
                  }),
                  selectedColor: C.brandSoft,
                  showCheckmark: false,
                  side: const BorderSide(color: C.line),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final t in techs) ...[
            AppCard(
              color: C.brandTint,
              border: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${techniqueNames[t]}: ${_sel.where((id) => groupById(id).technique == t).map((id) => groupById(id).label).join('، ')}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GuideLink(
                        pageId: switch (t) {
                          Technique.softOnset => 'soft',
                          Technique.lightContact => 'contact',
                          Technique.continuous => 'continuous',
                        },
                      ),
                    ],
                  ),
                  Text(
                    techniqueCues[t]!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.8,
                      color: Color(0xFF33454B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'نردبان تمرین',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'وقتی دست‌کم ۸۰٪ شروع‌ها نرم باشد، پله‌ی بعد باز می‌شود.',
                  style: TextStyle(fontSize: 12, color: C.muted),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < 3; i++) _stepRow(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int i) {
    final unlocked = i <= app.wordStep;
    final current = i == app.wordStep;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: i < app.wordStep
                ? C.softBg
                : (current ? C.brand : const Color(0xFFE9EDEA)),
            child: i < app.wordStep
                ? const Icon(Icons.check, size: 18, color: C.softDark)
                : Text(
                    faNum(i + 1),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: current ? Colors.white : C.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ladderNames[i],
              style: TextStyle(fontSize: 15, color: unlocked ? C.ink : C.muted),
            ),
          ),
          if (unlocked)
            OutlinedButton(
              onPressed: _sel.isEmpty ? null : () => _run(i),
              style: OutlinedButton.styleFrom(minimumSize: const Size(88, 44)),
              child: const Text('تمرین'),
            )
          else
            const Icon(Icons.lock_outline, color: C.muted),
        ],
      ),
    );
  }

  Future<void> _run(int step) async {
    app.wordGroups = _sel.toList();
    await app.save();
    if (!mounted) return;
    final passage = ladderStep(app.wordGroups, step);
    final wait = app.waitTarget < 1.5 ? app.waitTarget : 1.5;
    Coach.of(app).say('words_intro');
    final results = await Navigator.of(context).push<List<PhraseResult>>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          body: SessionView(
            passage: passage,
            waitTarget: wait,
            guided: true,
            onClose: () => Navigator.of(ctx).pop(),
            onFinished: (r) => Navigator.of(ctx).pop(r),
          ),
        ),
      ),
    );
    if (results == null || !mounted) return;
    await app.addSession(
      SessionRecord(
        date: DateTime.now(),
        passageId: passage.id,
        waitTarget: wait,
        results: results,
        kind: Kind.words,
      ),
    );
    if (!mounted) return;
    final s = SessionSummary.of(results);
    final passed = s.phrases > 0 && s.softRatio >= 0.8;
    if (passed && step == app.wordStep && app.wordStep < 2) {
      app.wordStep++;
      await app.save();
    }
    if (!mounted) return;
    setState(() {});
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              passed ? 'آفرین! شروع‌ها نرم بود' : 'خوب بود، یک بار دیگر',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'شروع نرم',
                    value: '${faNum(s.softCount)} از ${faNum(s.phrases)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'مکث کافی',
                    value: '${faNum(s.pauseOkCount)} از ${faNum(s.phrases)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              passed
                  ? (step < 2
                        ? 'پله‌ی «${ladderNames[step + 1]}» باز شد.'
                        : 'هر سه پله را رد کردی. همین تکنیک را در خواندن کتاب هم به کار ببر.')
                  : 'برای رفتن به پله‌ی بعد، دست‌کم ۸۰٪ شروع‌ها باید نرم باشد. آرام‌تر و با هوای بیشتر شروع کن.',
              style: const TextStyle(fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('باشه'),
            ),
          ],
        ),
      ),
    );
  }
}

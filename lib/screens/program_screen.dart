import 'package:flutter/material.dart';

import '../data/program.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import 'guide.dart';
import 'home.dart';

/// The whole program at a glance: what each stage is for and exactly what
/// the app is waiting to measure before moving on.
class ProgramScreen extends StatelessWidget {
  final AppState app;
  const ProgramScreen({super.key, required this.app});

  static const _what = {
    1: 'تمرین آهسته‌ی عبارت‌های کوتاه و کلمه‌ها، با مکث بلند و شروع خیلی نرم. هدف این است که تکنیک را در بدنت حس کنی.',
    2: 'هر روز یک متن کوتاه با مکث و شروع نرم. هر بار سه جلسه پشت سر هم خوب باشد، اپ زمان مکث را کمی کوتاه‌تر می‌کند تا گفتار طبیعی‌تر شود.',
    3: 'همان روش را در صحبت آزاد و بعد در موقعیت‌های واقعی به کار می‌بری؛ از آسان‌ترین موقعیت شروع می‌کنی.',
    4: 'تمرین کوتاه چند روز در هفته. اگر چند جلسه پشت سر هم سخت شد، اپ خودش یک دور تمرین آهسته پیشنهاد می‌کند.',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: C.bg,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'برنامه‌ی چهار مرحله‌ای',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const Text(
              'گفتارین تو را قدم‌به‌قدم جلو می‌برد. رفتن به مرحله‌ی بعد با اندازه‌گیری خود اپ است، نه با حدس.',
              style: TextStyle(fontSize: 14, height: 1.8, color: C.muted),
            ),
            const SizedBox(height: 16),
            for (final s in stages) ...[
              _StageCard(app: app, info: s, what: _what[s.n]!),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: GuideLink(
                pageId: 'sources',
                label: 'این برنامه از کجا آمده؟',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final AppState app;
  final StageInfo info;
  final String what;
  const _StageCard({required this.app, required this.info, required this.what});

  @override
  Widget build(BuildContext context) {
    final cur = info.n == app.stage;
    final past = info.n < app.stage;
    return AppCard(
      color: cur ? C.surface : (past ? C.softBg : C.bg),
      border: cur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: past ? C.soft : (cur ? C.brand : C.line),
                child: past
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        faNum(info.n),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cur ? Colors.white : C.muted,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  info.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (cur)
                const Text(
                  'اکنون',
                  style: TextStyle(
                    fontSize: 12,
                    color: C.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            what,
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: cur ? C.ink : C.muted,
            ),
          ),
          if (cur && criteria(app).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 16),
            for (final c in criteria(app)) CriterionRow(c: c),
          ],
        ],
      ),
    );
  }
}

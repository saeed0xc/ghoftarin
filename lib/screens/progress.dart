import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import '../services/report.dart';

import 'package:share_plus/share_plus.dart';

class ProgressScreen extends StatefulWidget {
  final AppState app;
  const ProgressScreen({super.key, required this.app});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

enum _Metric { pause, soft }

class _ProgressScreenState extends State<ProgressScreen> {
  _Metric _m = _Metric.pause;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final recent = app.sessions.length <= 7
        ? app.sessions
        : app.sessions.sublist(app.sessions.length - 7);
    final ratings = app.sessions.where((s) => s.selfRating != null).toList();
    final lastRatings = ratings.length <= 7
        ? ratings
        : ratings.sublist(ratings.length - 7);
    final allRecent = SessionSummary.of(
      app.sessions.reversed.take(5).expand((s) => s.results).toList(),
    );
    final base = app.assessment?.summary;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'پیشرفت',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              if (app.sessions.isNotEmpty || app.situationLogs.isNotEmpty)
                TextButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: buildTherapistReport(app),
                      subject: 'گزارش تمرین گفتارین',
                    ),
                  ),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('گزارش برای درمانگر'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (app.sessions.isEmpty)
            const AppCard(
              child: Text(
                'هنوز جلسه‌ای ثبت نشده. بعد از اولین جلسه، پیشرفتت اینجا نشان داده می‌شود.',
                style: TextStyle(fontSize: 14, height: 1.8),
              ),
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_Metric>(
                    segments: const [
                      ButtonSegment(
                        value: _Metric.pause,
                        label: Text('مکث کافی'),
                      ),
                      ButtonSegment(
                        value: _Metric.soft,
                        label: Text('شروع نرم'),
                      ),
                    ],
                    selected: {_m},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _m = s.first),
                  ),
                  const SizedBox(height: 16),
                  _bars(recent),
                  const SizedBox(height: 8),
                  Text(
                    _m == _Metric.pause
                        ? 'درصد عبارت‌هایی که پیش از شروع، به اندازه‌ی هدف مکث کردی (${faNum(recent.length)} جلسه‌ی اخیر).'
                        : 'درصد عبارت‌هایی که با شروع نرم گفته شد (${faNum(recent.length)} جلسه‌ی اخیر).',
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'روزهای تمرین',
                    value: '${faNum(app.practiceDays(30))} روز',
                    note: 'در ۳۰ روز گذشته',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'مکث هدف فعلی',
                    value: '${faNum(app.waitTarget, 1)} ث',
                    note: 'کم‌کم کوتاه‌تر می‌شود',
                  ),
                ),
              ],
            ),
            if (base != null && base.phrases > 0) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'از ارزیابی اول تا حالا',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'میانگین ۵ جلسه‌ی اخیر در برابر ارزیابی اولیه',
                      style: TextStyle(fontSize: 12, color: C.muted),
                    ),
                    const SizedBox(height: 8),
                    _compare(
                      'میانه‌ی مکث',
                      '${faNum(base.medianPause, 1)} ث',
                      '${faNum(allRecent.medianPause, 1)} ث',
                    ),
                    _compare(
                      'شروع نرم',
                      faPercent(base.softRatio),
                      faPercent(allRecent.softRatio),
                    ),
                    _compare(
                      'سرعت (هجا/ث)',
                      base.meanRate == null ? '—' : faNum(base.meanRate!, 1),
                      allRecent.meanRate == null
                          ? '—'
                          : faNum(allRecent.meanRate!, 1),
                    ),
                  ],
                ),
              ),
            ],
            if (lastRatings.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'خودارزیابی روزانه',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      '۰ بدون لکنت · ۹ بسیار شدید',
                      style: TextStyle(fontSize: 12, color: C.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (app.assessment != null)
                          _ratingDot(
                            'شروع',
                            app.assessment!.selfRating,
                            first: true,
                          ),
                        for (final s in lastRatings)
                          _ratingDot(
                            faDate(s.date).split(' ').skip(1).join(' '),
                            s.selfRating!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _bars(List<SessionRecord> rs) {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < rs.length; i++)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 44),
                  child: _bar(rs, i),
                ),
              ),
            ),
          // keep 7 slots so a single session is not one full-width bar
          for (var i = rs.length; i < 7; i++) const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _bar(List<SessionRecord> rs, int i) {
    return SizedBox(
      height: 170,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LayoutBuilder(
                builder: (context, box) {
                  final s = rs[i].summary;
                  final v = _m == _Metric.pause ? s.pauseRatio : s.softRatio;
                  final last = i == rs.length - 1;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        faNum((v * 100).round()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: last ? FontWeight.w700 : FontWeight.w400,
                          color: last ? C.ink : C.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: (box.maxHeight - 56) * v + 2,
                        decoration: BoxDecoration(
                          color: last ? C.brand : const Color(0xFFA9C9D1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        last ? 'آخرین' : faNum(i + 1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: last ? FontWeight.w700 : FontWeight.w400,
                          color: last ? C.ink : C.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compare(String label, String before, String now) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(before, style: const TextStyle(fontSize: 14, color: C.muted)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16, color: C.muted),
        ),
        Text(
          now,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _ratingDot(String label, int v, {bool first = false}) => Column(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: first ? C.warmBg : C.brandTint,
        child: Text(
          faNum(v),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: first ? C.warmDark : C.brandDark,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: C.muted)),
    ],
  );
}

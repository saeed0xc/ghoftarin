import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'practice.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  final AppState app;
  final VoidCallback openTalk;
  const HomeScreen({super.key, required this.app, required this.openTalk});

  @override
  Widget build(BuildContext context) {
    final passage = passageForDay(DateTime.now(), child: app.forChild);
    final done = app.practicedToday;
    final week = app.ratios(7);
    final prev = app.ratios(7, offsetDays: 7);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(faDate(DateTime.now()), style: const TextStyle(fontSize: 13, color: C.muted)),
                Text(done ? 'تمرین امروز انجام شد' : 'سلام! آماده‌ی تمرین امروز؟',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
            IconButton(
              tooltip: 'تنظیمات',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(app: app))),
              icon: const Icon(Icons.settings_outlined, color: C.muted),
            ),
          ]),
          const SizedBox(height: 8),
          if (app.streak > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip2('${faNum(app.streak)} روز پیاپی', fg: C.warmDark, bg: C.warmBg),
            ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('جلسه‌ی امروز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('مکث هدف: ${faNum(app.waitTarget, 1)} ثانیه', style: const TextStyle(fontSize: 13, color: C.muted)),
              ]),
              const SizedBox(height: 14),
              _step(done ? null : 1, 'خواندن کتاب: ${passage.title}', '${faNum(passage.phrases.length)} عبارت · مکث پیش از هر عبارت',
                  done: done),
              const SizedBox(height: 12),
              _step(done ? null : 2, 'خودارزیابی روزانه', 'شدت لکنت امروز از ۰ تا ۹', done: done && app.todaySession?.selfRating != null),
              const SizedBox(height: 12),
              _step(3, 'گفت‌وگو با هم‌صحبت', 'در نسخه‌ی بعدی', muted: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => PracticeScreen(app: app, passage: passage))),
                child: Text(done ? 'یک جلسه‌ی دیگر' : 'شروع جلسه'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (week.phrases > 0)
            Row(children: [
              Expanded(
                  child: StatTile(
                      label: 'مکث کافی (۷ روز)', value: faPercent(week.pause), note: _delta(week.pause, prev.pause, prev.phrases))),
              const SizedBox(width: 12),
              Expanded(
                  child: StatTile(
                      label: 'شروع نرم (۷ روز)', value: faPercent(week.soft), note: _delta(week.soft, prev.soft, prev.phrases))),
            ]),
          if (week.phrases > 0) const SizedBox(height: 12),
          const AppCard(
            color: C.brandTint,
            border: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.graphic_eq, color: C.brandDark),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تکنیک: شروع نرم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('صدای اول کلمه را مثل یک بازدم آرام شروع کن؛ اول زمزمه، بعد کم‌کم بلند.',
                      style: TextStyle(fontSize: 13, height: 1.7, color: Color(0xFF33454B))),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String? _delta(double now, double before, int beforeCount) {
    if (beforeCount == 0) return null;
    final d = ((now - before) * 100).round();
    if (d == 0) return 'مثل هفته‌ی قبل';
    return d > 0 ? '${faNum(d)}٪ بهتر از هفته‌ی قبل' : '${faNum(-d)}٪ کمتر از هفته‌ی قبل';
  }

  Widget _step(int? n, String title, String sub, {bool done = false, bool muted = false}) {
    final Widget badge = done
        ? const CircleAvatar(radius: 16, backgroundColor: C.softBg, child: Icon(Icons.check, size: 18, color: C.softDark))
        : CircleAvatar(
            radius: 16,
            backgroundColor: muted ? const Color(0xFFE9EDEA) : C.brand,
            child: Text(faNum(n ?? 0),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted ? C.muted : Colors.white)),
          );
    return Row(children: [
      badge,
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: muted ? C.muted : C.ink)),
          Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
        ]),
      ),
    ]);
  }
}

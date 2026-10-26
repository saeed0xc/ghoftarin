import 'package:flutter/material.dart';

import '../data/program.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'guide.dart';
import 'plan_runner.dart';
import 'program_screen.dart';
import 'settings.dart';

/// Today: the user's stage, today's plan and one button. The app decides
/// what to practise; the user only has to start.
class HomeScreen extends StatelessWidget {
  final AppState app;
  const HomeScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final plan = todayPlan(app);
    final next = plan.where((s) => !s.done).firstOrNull;
    final left = planMinutes(plan);
    final week = app.ratios(7);
    final prev = app.ratios(7, offsetDays: 7);
    final crit = criteria(app);
    final stage = stageInfo(app.stage);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  faDate(DateTime.now()),
                  style: const TextStyle(fontSize: 13, color: C.muted),
                ),
              ),
              IconButton(
                tooltip: 'راهنما',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GuideScreen())),
                icon: const Icon(Icons.help_outline, color: C.muted),
              ),
              IconButton(
                tooltip: 'تنظیمات',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsScreen(app: app)),
                ),
                icon: const Icon(Icons.settings_outlined, color: C.muted),
              ),
            ],
          ),
          Text(
            next == null ? 'تمرین امروز کامل شد' : 'برنامه‌ی امروز',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            next == null
                ? 'فردا برنامه‌ی تازه‌ای آماده است.'
                : 'حدود ${faNum(left)} دقیقه · ${faNum(plan.where((s) => s.done).length)} از ${faNum(plan.length)} قدم انجام شده',
            style: const TextStyle(fontSize: 14, color: C.muted),
          ),
          const SizedBox(height: 16),

          // ---- the plan ----
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < plan.length; i++) ...[
                  _StepRow(
                    n: i + 1,
                    step: plan[i],
                    current: identical(plan[i], next),
                    onTap: () => runStep(context, app, plan[i]),
                  ),
                  if (i < plan.length - 1) const SizedBox(height: 4),
                ],
                const SizedBox(height: 14),
                if (next != null)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => runStep(context, app, next),
                    child: Text(
                      plan.first == next ? 'شروع' : 'ادامه: ${next.title}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: C.softBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: C.softDark),
                        SizedBox(width: 8),
                        Text(
                          'آفرین؛ همین استمرار است که اثر می‌کند',
                          style: TextStyle(
                            color: C.softDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- stage ----
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ProgramScreen(app: app))),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'مرحله‌ی ${faNum(app.stage)} از ۴ · ${stage.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: C.muted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StageBar(stage: app.stage),
                  const SizedBox(height: 12),
                  if (crit.isEmpty)
                    const Text(
                      'مرحله‌ی آخر: هفته‌ای دست‌کم چهار روز تمرین کوتاه. اگر روزهای سخت پشت سر هم شد، اپ خودش تمرین آهسته را برمی‌گرداند.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.8,
                        color: C.muted,
                      ),
                    )
                  else ...[
                    const Text(
                      'برای مرحله‌ی بعد:',
                      style: TextStyle(fontSize: 13, color: C.muted),
                    ),
                    const SizedBox(height: 6),
                    for (final c in crit) CriterionRow(c: c, dense: true),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- this week ----
          if (week.phrases > 0) ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'شروع نرم · ۷ روز',
                    value: faPercent(week.soft),
                    note: _delta(week.soft, prev.soft, prev.phrases),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'مکث کافی · ۷ روز',
                    value: faPercent(week.pause),
                    note: _delta(week.pause, prev.pause, prev.phrases),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (app.streak > 1)
            Center(
              child: Chip2(
                '${faNum(app.streak)} روز پشت سر هم',
                fg: C.warmDark,
                bg: C.warmBg,
              ),
            ),
        ],
      ),
    );
  }

  String? _delta(double now, double before, int beforeCount) {
    if (beforeCount == 0) return null;
    final d = ((now - before) * 100).round();
    if (d == 0) return 'مثل هفته‌ی قبل';
    return d > 0
        ? '${faNum(d)}٪ بهتر از هفته‌ی قبل'
        : '${faNum(-d)}٪ کمتر از هفته‌ی قبل';
  }
}

class _StepRow extends StatelessWidget {
  final int n;
  final PlanStep step;
  final bool current;
  final VoidCallback onTap;
  const _StepRow({
    required this.n,
    required this.step,
    required this.current,
    required this.onTap,
  });

  static IconData icon(StepKind k) => switch (k) {
    StepKind.lessons => Icons.school_outlined,
    StepKind.slow => Icons.slow_motion_video,
    StepKind.read => Icons.menu_book_outlined,
    StepKind.words => Icons.record_voice_over_outlined,
    StepKind.talk => Icons.forum_outlined,
    StepKind.situation => Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return Material(
      color: current ? C.brandTint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: done
                    ? C.softBg
                    : (current ? C.brand : C.brandTint),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: C.softDark,
                      )
                    : Icon(
                        icon(step.kind),
                        size: 19,
                        color: current ? Colors.white : C.brandDark,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: done ? C.muted : C.ink,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: C.muted,
                      ),
                    ),
                    Text(
                      step.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: C.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                step.minutes > 0
                    ? '${faNum(step.minutes)} دقیقه'
                    : 'در طول روز',
                style: const TextStyle(fontSize: 12, color: C.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four segments, one per stage.
class StageBar extends StatelessWidget {
  final int stage;
  const StageBar({super.key, required this.stage});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'مرحله‌ی ${faNum(stage)} از ۴',
    child: Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < stage ? C.soft : (i == stage ? C.brand : C.line),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 6),
        ],
      ],
    ),
  );
}

class CriterionRow extends StatelessWidget {
  final Criterion c;
  final bool dense;
  const CriterionRow({super.key, required this.c, this.dense = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: dense ? 4 : 8),
    child: Row(
      children: [
        Icon(
          c.met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: c.met ? C.soft : C.line,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            c.label,
            style: TextStyle(fontSize: dense ? 13 : 14, height: 1.6),
          ),
        ),
        const SizedBox(width: 8),
        if (c.need > 1)
          Text(
            '${faNum(c.have.clamp(0, c.need))} از ${faNum(c.need)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.met ? C.softDark : C.muted,
            ),
          ),
      ],
    ),
  );
}

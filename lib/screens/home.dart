import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/path.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'guide.dart';
import 'node_runner.dart';
import 'settings.dart';

/// The path: units and their lessons, unlocked one by one.
class HomeScreen extends StatefulWidget {
  final AppState app;
  const HomeScreen({super.key, required this.app});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _current = GlobalKey();

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    // bring the current lesson into view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _current.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.4);
    });
  }

  static Color unitColor(int n) => switch (n) {
    1 => C.brand,
    2 => C.blue,
    _ => C.purple,
  };
  static Color unitShadow(int n) => switch (n) {
    1 => C.brandDark,
    2 => C.blueDark,
    _ => const Color(0xFFA568CC),
  };

  @override
  Widget build(BuildContext context) {
    final stars = app.pathStars;
    final cur = currentNode(stars, lessonsDone: app.lessonsDone);
    final curUnit = unitOf(cur.index);
    final shownUnits = units
        .where((u) => u.first <= stars.length || u.n == curUnit.n + 1)
        .toList();
    if (!shownUnits.contains(units.first)) shownUnits.insert(0, units.first);

    return SafeArea(
      child: Column(
        children: [
          // ---- top bar: streak, stars, help, settings ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                _TopStat(
                  icon: Icons.local_fire_department,
                  color: C.warm,
                  value: app.streak,
                  label: 'روز پشت سر هم',
                ),
                const SizedBox(width: 14),
                _TopStat(
                  icon: Icons.star_rounded,
                  color: C.gold,
                  value: app.totalStars,
                  label: 'ستاره',
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'راهنما',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuideScreen()),
                  ),
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
          ),
          const Divider(height: 1, thickness: 2, color: C.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                for (final u in shownUnits) ...[
                  _UnitBanner(
                    unit: u,
                    color: unitColor(u.n),
                    shadow: unitShadow(u.n),
                    locked: u.first > stars.length,
                  ),
                  const SizedBox(height: 20),
                  for (final i in _nodesOf(u, stars.length))
                    _NodeRow(
                      key: (!cur.review && i == cur.index) ? _current : null,
                      index: i,
                      offset: math.sin(i * math.pi / 4) * 72,
                      state: cur.review && i == cur.index
                          ? _NodeState.current
                          : (i < stars.length
                                ? _NodeState.done
                                : (i == cur.index
                                      ? _NodeState.current
                                      : _NodeState.locked)),
                      stars: i < stars.length ? stars[i] : 0,
                      kind: nodeAt(i).mainKind,
                      color: unitColor(u.n),
                      shadow: unitShadow(u.n),
                      review: cur.review && i == cur.index,
                      onTap: () => _open(
                        i < stars.length && !(cur.review && i == cur.index)
                            ? nodeAt(i)
                            : cur,
                        i,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nodes to draw for a unit: all of a finite unit; for the endless one,
  /// up to five beyond the current lesson.
  List<int> _nodesOf(UnitInfo u, int done) {
    final last = u.last ?? math.max(done + 5, u.first + 5);
    return [for (var i = u.first; i <= last; i++) i];
  }

  Future<void> _open(PathNode node, int tapped) async {
    final stars = app.pathStars;
    final cur = currentNode(stars, lessonsDone: app.lessonsDone);
    final isCurrent = tapped == cur.index;
    final done = tapped < stars.length && !(cur.review && isCurrent);
    if (!isCurrent && !done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('این درس بعد از تمام کردن درس‌های قبلی باز می‌شود.'),
        ),
      );
      return;
    }
    final run = done ? PathNode(node.index, node.parts, review: true) : node;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              run.review && !done ? 'مرور' : 'درس ${faNum(run.index + 1)}',
              style: const TextStyle(
                fontSize: 14,
                color: C.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              run.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            if (run.review && !done)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'برای رفتن به بخش بعد، چند درس باید دست‌کم ۲ ستاره داشته باشند. این درس را یک بار دیگر تمرین کن.',
                  style: TextStyle(fontSize: 13, height: 1.8, color: C.muted),
                ),
              ),
            const SizedBox(height: 12),
            for (final p in run.parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_icon(p.kind), color: C.blueDark),
                    const SizedBox(width: 10),
                    Text(_partName(p), style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'حدود ${faNum(run.minutes)} دقیقه',
              style: const TextStyle(fontSize: 13, color: C.muted),
            ),
            const SizedBox(height: 18),
            ChunkyButton(
              label: done ? 'تمرین دوباره' : 'شروع',
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    if (go == true && mounted) {
      await runNode(context, app, run);
      if (mounted) setState(() {});
    }
  }

  static IconData _icon(PartKind k) => switch (k) {
    PartKind.lessons => Icons.school,
    PartKind.words => Icons.record_voice_over,
    PartKind.book => Icons.menu_book,
    PartKind.partner => Icons.forum,
  };

  static String _partName(Part p) => switch (p.kind) {
    PartKind.lessons => 'آموزش کوتاه: مکث و شروع نرم',
    PartKind.words =>
      p.index < 14 ? 'کلمه‌های تازه، کشیده و نرم' : 'گرم کردن با کلمه',
    PartKind.book => 'نیم صفحه از داستان: ${bookPassage(p.index).title}',
    PartKind.partner => 'هم‌صحبت: ${partnerScene(p.index).title}',
  };
}

class _TopStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _TopStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${faNum(value)} $label',
    excludeSemantics: true,
    child: Row(
      children: [
        Icon(icon, color: value > 0 ? color : C.lockedDark, size: 28),
        const SizedBox(width: 4),
        Text(
          faNum(value),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: value > 0 ? color : C.lockedDark,
          ),
        ),
      ],
    ),
  );
}

class _UnitBanner extends StatelessWidget {
  final UnitInfo unit;
  final Color color, shadow;
  final bool locked;
  const _UnitBanner({
    required this.unit,
    required this.color,
    required this.shadow,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: locked ? C.lockedDark : shadow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: locked ? C.locked : color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بخش ${faNum(unit.n)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: locked
                        ? C.muted
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  unit.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: locked ? C.muted : Colors.white,
                  ),
                ),
                Text(
                  unit.sub,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: locked ? C.muted : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (locked) const Icon(Icons.lock, color: C.lockedDark),
        ],
      ),
    ),
  );
}

enum _NodeState { done, current, locked }

class _NodeRow extends StatelessWidget {
  final int index;
  final double offset;
  final _NodeState state;
  final int stars;
  final PartKind kind;
  final Color color, shadow;
  final bool review;
  final VoidCallback onTap;
  const _NodeRow({
    super.key,
    required this.index,
    required this.offset,
    required this.state,
    required this.stars,
    required this.kind,
    required this.color,
    required this.shadow,
    required this.review,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cur = state == _NodeState.current;
    final face = switch (state) {
      _NodeState.done => C.gold,
      _NodeState.current => color,
      _ => C.locked,
    };
    final base = switch (state) {
      _NodeState.done => C.goldDark,
      _NodeState.current => shadow,
      _ => C.lockedDark,
    };
    final icon = state == _NodeState.locked
        ? Icons.lock
        : (review
              ? Icons.replay
              : (state == _NodeState.done
                    ? Icons.check_rounded
                    : switch (kind) {
                        PartKind.partner => Icons.forum,
                        PartKind.book => Icons.menu_book,
                        _ => Icons.record_voice_over,
                      }));
    final size = cur ? 78.0 : 68.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Column(
          children: [
            if (cur)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: C.surface,
                  border: Border.all(color: C.line, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  review ? 'مرور' : 'شروع',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: shadow,
                  ),
                ),
              ),
            Semantics(
              button: true,
              label:
                  'درس ${faNum(index + 1)}${state == _NodeState.locked ? '، قفل' : (state == _NodeState.done ? '، ${faNum(stars)} ستاره' : '، درس فعلی')}',
              excludeSemantics: true,
              onTap: onTap,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: face,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: state == _NodeState.locked
                          ? C.lockedDark
                          : Colors.white,
                      size: size * 0.45,
                    ),
                  ),
                ),
              ),
            ),
            if (state == _NodeState.done)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StarRow(stars: stars, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

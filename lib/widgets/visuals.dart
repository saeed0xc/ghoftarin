import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The breath ring: fills while the user pauses before speaking.
class BreathRing extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final Color track;
  final String label;
  final double size;
  final double stroke;
  final double fontSize;
  const BreathRing({
    super.key,
    required this.progress,
    required this.label,
    this.color = C.brand,
    this.track = C.brandSoft,
    this.size = 168,
    this.stroke = 12,
    this.fontSize = 28,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'نمودار حلقه',
    value: label == '✓' ? 'آماده' : (label == '!' ? 'زود شروع شد' : label),
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1), color, track, stroke),
        child: Center(
          // '✓' is drawn as an icon: the bundled fonts have no check mark glyph
          child: label == '✓'
              ? Icon(Icons.check_rounded, size: fontSize * 1.4, color: C.ink)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: C.ink,
                  ),
                  textDirection: TextDirection.rtl,
                ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double p;
  final Color color, track;
  final double stroke;
  _RingPainter(this.p, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(c, r, base);
    if (p > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * p,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.p != p || o.color != color || o.track != track;
}

/// Loudness curve of a phrase start (oldest value on the right in RTL).
class OnsetWave extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const OnsetWave({
    super.key,
    required this.values,
    required this.color,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _WavePainter(values, color)),
  );
}

class _WavePainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _WavePainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = v.reduce(math.max);
    if (maxV <= 0) return;
    // time runs right-to-left, matching the reading direction
    Offset pt(int i) => Offset(
      size.width * (1 - i / (v.length - 1)),
      size.height - 4 - (size.height - 8) * v[i] / maxV,
    );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.v != v || o.color != color;
}

/// A book page with the current phrase highlighted.
class BookPage extends StatelessWidget {
  final String source;
  final List<String> phrases;
  final int current; // -1 = none; phrases.length = all done
  final String separator;
  const BookPage({
    super.key,
    required this.source,
    required this.phrases,
    required this.current,
    this.separator = ' ',
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < phrases.length; i++) {
      final isCur = i == current;
      final done = i < current;
      spans.add(
        TextSpan(
          text: phrases[i],
          style: TextStyle(
            color: isCur || done ? C.ink : const Color(0xFF8E9A9E),
            backgroundColor: isCur ? C.brandSoft : null,
          ),
        ),
      );
      if (i < phrases.length - 1) {
        spans.add(
          TextSpan(
            text: separator,
            style: const TextStyle(color: Color(0xFFB0BABD)),
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: C.paper,
        border: Border.all(color: C.paperLine),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(source, style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(
              fontFamily: kBookFont,
              fontSize: 21,
              height: 2.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label.
class Chip2 extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const Chip2(
    this.text, {
    super.key,
    this.fg = C.brandDark,
    this.bg = C.brandTint,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
    ),
  );
}

/// Stat tile: big number with a label.
class StatTile extends StatelessWidget {
  final String label, value;
  final String? note;
  final Color valueColor;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.valueColor = C.brandDark,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        if (note != null)
          Text(note!, style: const TextStyle(fontSize: 12, color: C.muted)),
      ],
    ),
  );
}

enum OrbMode { idle, waiting, ready, speaking }

/// Calm pause visual: no numbers, no countdown. A soft circle slowly grows
/// with the breath while the user pauses; when the pause is long enough it
/// turns a quiet green. Nothing turns red.
class BreathOrb extends StatelessWidget {
  final double progress; // 0..1 of the pause target
  final OrbMode mode;
  final double size;
  const BreathOrb({
    super.key,
    required this.progress,
    required this.mode,
    this.size = 176,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    // ease in-out so the growth feels like a slow inhale
    final eased = p < 0.5 ? 2 * p * p : 1 - (-2 * p + 2) * (-2 * p + 2) / 2;
    final scale = switch (mode) {
      OrbMode.idle => 0.5,
      OrbMode.waiting => 0.5 + 0.5 * eased,
      OrbMode.ready => 1.0,
      OrbMode.speaking => 0.82,
    };
    final fill = switch (mode) {
      OrbMode.ready => C.softBg,
      OrbMode.speaking => C.brandTint,
      _ => C.brandSoft,
    };
    final edge = switch (mode) {
      OrbMode.ready => C.soft,
      OrbMode.speaking => C.brand.withValues(alpha: 0.35),
      _ => C.brand.withValues(alpha: 0.45),
    };
    return Semantics(
      label: 'دایره‌ی نفس',
      value: switch (mode) {
        OrbMode.ready => 'آماده',
        OrbMode.speaking => 'در حال صحبت',
        _ => 'مکث',
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // faint outline of the full breath
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: C.line, width: 1.5),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: scale),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, s, child) => Container(
                width: size * s,
                height: size * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: edge, width: 2),
                ),
              ),
            ),
            if (mode == OrbMode.ready)
              const Icon(Icons.check_rounded, color: C.softDark, size: 34),
          ],
        ),
      ),
    );
  }
}

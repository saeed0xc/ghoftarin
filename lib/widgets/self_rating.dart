import 'package:flutter/material.dart';

import '../fa.dart';
import '../theme.dart';

/// Daily severity self-rating, 0 (no stuttering) .. 9 (extremely severe),
/// the Lidcombe Program severity scale (Camperdown uses a similar 1..9 scale).
class SelfRating extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;
  final bool forChild;
  const SelfRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.forChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          forChild
              ? 'لکنت فرزندتان امروز در کل روز چقدر بود؟'
              : 'لکنت امروزت در کل روز چقدر بود؟',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '۰ یعنی بدون لکنت، ۹ یعنی بسیار شدید.',
          style: TextStyle(fontSize: 13, color: C.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(10, (i) {
            final sel = value == i;
            return SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                onPressed: () => onChanged(i),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  backgroundColor: sel ? C.brand : C.surface,
                  foregroundColor: sel ? Colors.white : C.ink,
                  side: BorderSide(color: sel ? C.brand : C.line),
                ),
                child: Text(
                  faNum(i),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('بدون لکنت', style: TextStyle(fontSize: 12, color: C.muted)),
            Text('بسیار شدید', style: TextStyle(fontSize: 12, color: C.muted)),
          ],
        ),
      ],
    );
  }
}

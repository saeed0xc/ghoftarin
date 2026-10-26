import 'package:flutter/material.dart';

import '../data/partner.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import 'partner_screen.dart';

/// Every conversation scene, easy to hard, open at any time.
class PartnerListScreen extends StatelessWidget {
  final AppState app;
  const PartnerListScreen({super.key, required this.app});

  static const _levels = {1: 'آسان', 2: 'متوسط', 3: 'سخت‌تر'};

  @override
  Widget build(BuildContext context) {
    final done = {
      for (final s in app.sessions)
        if (s.kind == Kind.partner) s.passageId,
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const Text(
            'هم‌صحبت',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'گفت‌وگوهای روزمره با صدای واقعی. هم‌صحبت همیشه صبر می‌کند تا حرفت تمام شود.',
            style: TextStyle(fontSize: 14, height: 1.8, color: C.muted),
          ),
          for (final level in [1, 2, 3]) ...[
            const SizedBox(height: 18),
            Text(
              _levels[level]!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final s in scenesByLevel.where((s) => s.level == level))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PartnerScreen(app: app, scene: s),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: C.line, width: 2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: switch (level) {
                              1 => C.blue,
                              2 => C.purple,
                              _ => C.warm,
                            },
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${s.role} · ${faNum(s.turns.length)} نوبت',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: C.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (done.contains(s.id))
                            const Icon(Icons.check_circle, color: C.brand),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

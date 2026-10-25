import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import 'practice.dart';
import 'words.dart';
import 'lessons.dart';

/// All reading passages; any can be practised at any time.
class LibraryScreen extends StatelessWidget {
  final AppState app;
  const LibraryScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final list = [...passages]
      ..sort((a, b) {
        int rank(Passage p) => p.audience == 'all'
            ? 0
            : (p.audience == (app.forChild ? 'child' : 'adult') ? 0 : 1);
        return rank(a) - rank(b);
      });
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'کتاب‌ها',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'هر متنی را می‌توانی انتخاب کنی. کتاب‌های بیشتر به‌زودی اضافه می‌شوند.',
            style: TextStyle(fontSize: 13, color: C.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => app.lessonsDone
                    ? WordsScreen(app: app)
                    : LessonsScreen(app: app, startPracticeAfter: false),
              ),
            ),
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('تمرین کلمه روی صداهای سخت'),
          ),
          const SizedBox(height: 16),
          for (final p in list) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => app.lessonsDone
                      ? PracticeScreen(app: app, passage: p)
                      : LessonsScreen(app: app, startPracticeAfter: false),
                ),
              ),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 60,
                      decoration: BoxDecoration(
                        color: C.paper,
                        border: Border.all(color: C.paperLine),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: C.brandDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${p.source} · ${faNum(p.phrases.length)} عبارت · ${_aud(p.audience)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: C.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.phrases.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: kBookFont,
                              fontSize: 15,
                              color: Color(0xFF33454B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: C.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _aud(String a) => switch (a) {
    'child' => 'کودک',
    'adult' => 'بزرگسال',
    _ => 'همه',
  };
}

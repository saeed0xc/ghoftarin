import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../fa.dart';
import '../theme.dart';
import 'lessons.dart';
import 'monologue.dart';
import 'plan_runner.dart';
import 'practice.dart';
import 'situations.dart';
import 'words.dart';

/// Every exercise and every book, for practising beyond today's plan.
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
            'تمرین‌ها',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'برنامه‌ی امروز کافی است؛ این‌ها برای وقتی است که بیشتر می‌خواهی.',
            style: TextStyle(fontSize: 13, color: C.muted),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _tile(
                context,
                Icons.slow_motion_video,
                'تمرین آهسته',
                'مکث بلند، شروع خیلی نرم',
                PracticeScreen(
                  app: app,
                  passage: slowPassage,
                  overrideWait: slowWait(app),
                ),
              ),
              _tile(
                context,
                Icons.record_voice_over_outlined,
                'تمرین کلمه',
                'صداهایی که سخت‌ترند',
                WordsScreen(app: app),
              ),
              _tile(
                context,
                Icons.forum_outlined,
                'صحبت آزاد',
                'یک یا سه دقیقه',
                MonologueScreen(app: app),
              ),
              _tile(
                context,
                Icons.storefront_outlined,
                'موقعیت‌های واقعی',
                'از آسان به سخت',
                SituationsScreen(app: app),
                needsLessons: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'کتاب‌ها',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
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

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    Widget page, {
    bool needsLessons = true,
  }) => Material(
    color: C.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => !needsLessons || app.lessonsDone
              ? page
              : LessonsScreen(app: app, startPracticeAfter: false),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: C.brandDark, size: 26),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ],
        ),
      ),
    ),
  );

  String _aud(String a) => switch (a) {
    'child' => 'کودک',
    'adult' => 'بزرگسال',
    _ => 'همه',
  };
}

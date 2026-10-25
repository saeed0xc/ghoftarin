import 'package:flutter/material.dart';

import '../data/guide.dart';
import '../fa.dart';
import '../theme.dart';

/// List of guide pages.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('راهنما', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (final p in guidePages) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidePageScreen(pageId: p.id))),
              child: AppCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(p.summary, style: const TextStyle(fontSize: 13, height: 1.7, color: C.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_left, color: C.muted),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          const Text(guideReviewNote, style: TextStyle(fontSize: 12, height: 1.8, color: C.muted)),
        ],
      ),
    );
  }
}

/// One guide page.
class GuidePageScreen extends StatelessWidget {
  final String pageId;
  const GuidePageScreen({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final p = guidePages.firstWhere((g) => g.id == pageId);
    return Scaffold(
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(p.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(p.summary, style: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF33454B))),
          const SizedBox(height: 16),
          for (final s in p.sections) ...[
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (var i = 0; i < s.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (s.lines.length > 1)
                        SizedBox(
                          width: 26,
                          child: s.numbered
                              ? CircleAvatar(
                                  radius: 11,
                                  backgroundColor: C.brandTint,
                                  child: Text(faNum(i + 1),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.brandDark)),
                                )
                              : const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: CircleAvatar(radius: 3, backgroundColor: C.brand),
                                ),
                        ),
                      Expanded(child: Text(s.lines[i], style: const TextStyle(fontSize: 14, height: 1.9))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          const Text(guideReviewNote, style: TextStyle(fontSize: 12, height: 1.8, color: C.muted)),
        ],
      ),
    );
  }
}

/// Small "how?" link that opens a guide page.
class GuideLink extends StatelessWidget {
  final String pageId;
  final String label;
  const GuideLink({super.key, required this.pageId, this.label = 'چطور؟'});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidePageScreen(pageId: pageId))),
        icon: const Icon(Icons.help_outline, size: 18),
        label: Text(label),
      );
}

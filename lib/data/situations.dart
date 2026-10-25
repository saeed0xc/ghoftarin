/// Everyday speaking situations for gradual real-life practice (transfer and
/// graded exposure). Ordered roughly from easier to harder; each person's own
/// order comes from their anxiety ratings.
library;

class Situation {
  final String id;
  final String title;
  final String tip;
  const Situation(this.id, this.title, this.tip);
}

const situations = <Situation>[
  Situation(
    'greet',
    'سلام و احوال‌پرسی با یک آشنا',
    'پیش از «سلام» یک مکث کوتاه و شروع نرم؛ نیازی به عجله نیست.',
  ),
  Situation(
    'friend',
    'چند دقیقه حرف زدن با یک دوست نزدیک',
    'یک موضوع ساده انتخاب کن و روی مکث پیش از هر جمله تمرکز کن.',
  ),
  Situation(
    'shop',
    'سفارش دادن در مغازه، نانوایی یا کافه',
    'جمله‌ات را از قبل در ذهن مرور کن و کلمه‌ی اول را نرم شروع کن.',
  ),
  Situation(
    'ask',
    'پرسیدن آدرس یا یک سؤال از یک غریبه',
    'نگاهت را آرام نگه دار؛ مکث پیش از شروع طبیعی است.',
  ),
  Situation(
    'answer',
    'جواب دادن به تلفن',
    'پیش از «الو» یک نفس آرام؛ لازم نیست فوراً حرف بزنی.',
  ),
  Situation(
    'call',
    'تماس تلفنی، مثلاً با یک فروشگاه یا مطب',
    'اول جمله‌ی شروع را بنویس، بعد با مکث و شروع نرم بگو.',
  ),
  Situation(
    'intro',
    'معرفی خودم به یک فرد تازه',
    'اسم خودت را با شروع نرم بگو؛ اگر گیر کردی، مکث کن و دوباره نرم شروع کن.',
  ),
  Situation(
    'group',
    'صحبت در کلاس، جلسه یا جمع',
    'اول یک جمله‌ی کوتاه؛ هر بار کمی بیشتر.',
  ),
];

Situation situationById(String id) =>
    situations.firstWhere((s) => s.id == id, orElse: () => situations.first);

class SituationLog {
  final DateTime date;
  final String situationId;
  final int anxietyBefore; // 0..10
  final int anxietyAfter; // 0..10
  final int severity; // 0..9
  final bool avoided; // planned but did not do it

  SituationLog({
    required this.date,
    required this.situationId,
    required this.anxietyBefore,
    required this.anxietyAfter,
    required this.severity,
    this.avoided = false,
  });

  Map<String, dynamic> toJson() => {
    'd': date.toIso8601String(),
    's': situationId,
    'b': anxietyBefore,
    'a': anxietyAfter,
    'v': severity,
    if (avoided) 'x': true,
  };

  factory SituationLog.fromJson(Map<String, dynamic> j) => SituationLog(
    date: DateTime.parse(j['d'] as String),
    situationId: j['s'] as String,
    anxietyBefore: j['b'] as int,
    anxietyAfter: j['a'] as int,
    severity: j['v'] as int,
    avoided: j['x'] as bool? ?? false,
  );
}

/// The next situation to try: one not done in the last 2 days, preferring
/// the lowest recent anxiety, so practice climbs gradually.
Situation nextSituation(List<SituationLog> logs, DateTime now) {
  double avgAnxiety(String id) {
    final l = logs.where((x) => x.situationId == id && !x.avoided).toList();
    if (l.isEmpty) return double.infinity;
    final recent = l.length > 3 ? l.sublist(l.length - 3) : l;
    return recent.map((x) => x.anxietyBefore).reduce((a, b) => a + b) /
        recent.length;
  }

  bool recent(String id) => logs.any(
    (x) => x.situationId == id && now.difference(x.date).inHours < 48,
  );
  final tried =
      situations
          .where((s) => avgAnxiety(s.id).isFinite && !recent(s.id))
          .toList()
        ..sort((a, b) => avgAnxiety(a.id).compareTo(avgAnxiety(b.id)));
  // move on to a new situation once the easiest tried one feels manageable (≤ 3)
  final firstNew = situations.where((s) => !avgAnxiety(s.id).isFinite).toList();
  if (tried.isNotEmpty && (avgAnxiety(tried.first.id) > 3 || firstNew.isEmpty)) {
    return tried.first;
  }
  if (firstNew.isNotEmpty) return firstNew.first;
  return situations.firstWhere(
    (s) => !recent(s.id),
    orElse: () => situations.first,
  );
}

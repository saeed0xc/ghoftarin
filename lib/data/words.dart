/// Word-practice bank, grouped by the first sound.
///
/// Each sound group is practised with the fluency-shaping target that fits its
/// type (to be confirmed by the advising speech therapist):
/// - vowel starts → soft onset (easy onset)
/// - stops (پ ب ت د ک گ) → light contact
/// - continuants (م ن س ش) → continuous voice
library;

import 'content.dart';

enum Technique { softOnset, lightContact, continuous }

class SoundGroup {
  final String id;
  final String label; // what the user sees, e.g. «پ»
  final Technique technique;
  final List<String> words;
  final List<String> phrases;
  final List<String> sentences;
  const SoundGroup(
    this.id,
    this.label,
    this.technique,
    this.words,
    this.phrases,
    this.sentences,
  );
}

const techniqueNames = {
  Technique.softOnset: 'شروع نرم',
  Technique.lightContact: 'تماس نرم',
  Technique.continuous: 'صدای پیوسته',
};

const techniqueCues = {
  Technique.softOnset:
      'صدای اول را مثل یک بازدم آرام شروع کن؛ اول زمزمه، بعد کم‌کم بلند.',
  Technique.lightContact:
      'لب‌ها یا زبان فقط آرام به هم برسند، بدون فشار؛ بعد آرام رها کن.',
  Technique.continuous: 'صدای اول را نرم و کمی کشیده شروع کن و بدون قطع شدن به بقیه‌ی کلمه وصل کن.',
};

const soundGroups = <SoundGroup>[
  SoundGroup(
    'a',
    'آ / ا',
    Technique.softOnset,
    ['آب', 'امروز', 'اسم', 'آسمان'],
    ['آب سرد', 'امروز صبح', 'اسم من'],
    ['امروز هوا خوب است.', 'آسمان آبی است.'],
  ),
  SoundGroup(
    'p',
    'پ',
    Technique.lightContact,
    ['پدر', 'پنجره', 'پرنده', 'پول'],
    ['پدر من', 'پنجره‌ی باز', 'پرنده‌ی کوچک'],
    ['پدرم به خانه آمد.', 'پرنده روی درخت نشست.'],
  ),
  SoundGroup(
    'b',
    'ب',
    Technique.lightContact,
    ['بابا', 'باران', 'باغ', 'بستنی'],
    ['باران تند', 'باغ بزرگ', 'بستنی سرد'],
    ['باران شروع شد.', 'بابا بستنی خرید.'],
  ),
  SoundGroup(
    't',
    'ت',
    Technique.lightContact,
    ['توپ', 'تابستان', 'تلفن', 'تخته'],
    ['توپ قرمز', 'تابستان گرم', 'تلفن همراه'],
    ['تلفن زنگ زد.', 'تابستان را دوست دارم.'],
  ),
  SoundGroup(
    'd',
    'د',
    Technique.lightContact,
    ['دست', 'درخت', 'دوست', 'دریا'],
    ['دست راست', 'درخت بلند', 'دوست خوب'],
    ['دریا آرام بود.', 'دوستم را دیدم.'],
  ),
  SoundGroup(
    'k',
    'ک',
    Technique.lightContact,
    ['کتاب', 'کوه', 'کلید', 'کار'],
    ['کتاب تازه', 'کوه بلند', 'کلید خانه'],
    ['کتاب را باز کردم.', 'کار امروز تمام شد.'],
  ),
  SoundGroup(
    'g',
    'گ',
    Technique.lightContact,
    ['گل', 'گربه', 'گرم', 'گوش'],
    ['گل سرخ', 'گربه‌ی سفید', 'گوش کن'],
    ['گل‌ها باز شدند.', 'گربه خوابیده است.'],
  ),
  SoundGroup(
    'm',
    'م',
    Technique.continuous,
    ['مادر', 'ماه', 'مدرسه', 'میز'],
    ['مادر مهربان', 'ماه کامل', 'میز چوبی'],
    ['مادرم غذا پخت.', 'ماه در آسمان است.'],
  ),
  SoundGroup(
    'n',
    'ن',
    Technique.continuous,
    ['نان', 'نامه', 'نور', 'نقاشی'],
    ['نان تازه', 'نامه‌ی بلند', 'نور خورشید'],
    ['نان را خریدم.', 'نامه‌ام رسید.'],
  ),
  SoundGroup(
    's',
    'س',
    Technique.continuous,
    ['سلام', 'سیب', 'سفر', 'ساعت'],
    ['سلام دوست من', 'سیب سرخ', 'ساعت پنج'],
    ['سلام، حالت چطور است؟', 'سفر خوبی بود.'],
  ),
  SoundGroup(
    'sh',
    'ش',
    Technique.continuous,
    ['شب', 'شهر', 'شیر', 'شنبه'],
    ['شب بخیر', 'شهر بزرگ', 'شیر گرم'],
    ['شب آرامی بود.', 'شنبه می‌بینمت.'],
  ),
];

SoundGroup groupById(String id) =>
    soundGroups.firstWhere((g) => g.id == id, orElse: () => soundGroups.first);

const ladderNames = ['کلمه', 'عبارت دوکلمه‌ای', 'جمله‌ی کوتاه'];

/// Builds the practice list for one ladder step from the chosen groups.
/// Up to [max] items, interleaving the groups so every chosen sound appears.
Passage ladderStep(List<String> groupIds, int step, {int max = 8}) {
  final groups = groupIds.map(groupById).toList();
  final lists = groups
      .map(
        (g) => switch (step) {
          0 => g.words,
          1 => g.phrases,
          _ => g.sentences,
        },
      )
      .toList();
  final items = <String>[];
  for (var i = 0; items.length < max; i++) {
    var added = false;
    for (final l in lists) {
      if (i < l.length && items.length < max) {
        items.add(l[i]);
        added = true;
      }
    }
    if (!added) break;
  }
  return Passage(
    id: 'words-$step-${groupIds.join('_')}',
    title: 'تمرین کلمه: ${ladderNames[step]}',
    source: 'صداها: ${groups.map((g) => g.label).join('، ')}',
    audience: 'all',
    phrases: items,
    syllables: List.filled(items.length, 0),
    separator: step == 0 ? '  ·  ' : '  ·  ',
  );
}

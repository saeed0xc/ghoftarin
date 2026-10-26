/// Reading passages. Each phrase carries a hand-counted syllable count, used
/// for the speech-rate figure. Golestan is public domain; the other passages
/// are original text written for the app.
class Passage {
  final String id;
  final String title;
  final String source;
  final String audience; // 'adult' | 'child' | 'all'
  final List<String> phrases;
  final List<int> syllables; // 0 = not counted (no speech-rate figure)
  final String separator; // between phrases on the page

  const Passage({
    required this.id,
    required this.title,
    required this.source,
    required this.audience,
    required this.phrases,
    required this.syllables,
    this.separator = ' ',
  });
}

/// Short phrases for the slow practice round: vowel and soft-consonant starts
/// first, then a little longer. Not part of the daily reading rotation.
const slowPassage = Passage(
  id: 'slow',
  title: 'تمرین آهسته',
  source: 'عبارت‌های کوتاه',
  audience: 'all',
  phrases: [
    'آب',
    'امروز',
    'اسم من',
    'او آمد',
    'هوا خوب است',
    'ما می‌رویم',
    'این نان است',
    'آرام حرف می‌زنم',
  ],
  syllables: [1, 2, 3, 3, 4, 4, 3, 6],
  separator: '  ·  ',
);

const passages = <Passage>[
  Passage(
    id: 'golestan-1',
    title: 'گلستان، دیباچه',
    source: 'گلستان سعدی',
    audience: 'adult',
    phrases: [
      'منّت خدای را عزّ و جلّ',
      'که طاعتش موجب قربت است',
      'و به شکر اندرش مزید نعمت.',
      'هر نفسی که فرو می‌رود ممدّ حیات است',
      'و چون برمی‌آید مفرّح ذات.',
      'پس در هر نفسی دو نعمت موجود است',
      'و بر هر نعمتی شکری واجب.',
    ],
    syllables: [8, 10, 11, 16, 11, 12, 10],
  ),
  Passage(
    id: 'morning',
    title: 'صبح نان تازه',
    source: 'متن تمرینی گفتارین',
    audience: 'all',
    phrases: [
      'صبح زود از خانه بیرون آمدم.',
      'هوا خنک بود و خیابان آرام.',
      'کنار نانوایی ایستادم.',
      'بوی نان تازه همه جا را پر کرده بود.',
      'دو نان گرم خریدم و به خانه برگشتم.',
      'صبحانه را با خانواده خوردیم',
      'و روزمان با لبخند شروع شد.',
    ],
    syllables: [10, 11, 9, 14, 14, 11, 10],
  ),
  Passage(
    id: 'pishi',
    title: 'پیشی و توپ قرمز',
    source: 'متن تمرینی گفتارین',
    audience: 'child',
    phrases: [
      'یک گربه‌ی کوچک در باغ بود.',
      'اسمش پیشی بود.',
      'پیشی توپ قرمزش را دوست داشت.',
      'یک روز توپ زیر درخت رفت.',
      'پیشی آرام آرام جلو رفت',
      'و توپ را پیدا کرد.',
      'پیشی خیلی خوشحال شد.',
    ],
    syllables: [9, 5, 10, 8, 9, 6, 7],
  ),
  Passage(
    id: 'bazaar',
    title: 'بازار روز',
    source: 'متن تمرینی گفتارین',
    audience: 'all',
    phrases: [
      'جمعه صبح به بازار روز رفتیم.',
      'میوه‌ها تازه و رنگارنگ بودند.',
      'فروشنده با لبخند سلام کرد.',
      'یک کیلو سیب و کمی انگور خریدیم.',
      'قیمت‌ها را پرسیدم و حساب کردم.',
      'سبد پر شده بود و دستم سنگین.',
      'آرام آرام به خانه برگشتیم.',
    ],
    syllables: [10, 11, 10, 12, 12, 11, 10],
  ),
  Passage(
    id: 'phone',
    title: 'یک تماس کاری',
    source: 'متن تمرینی گفتارین',
    audience: 'adult',
    phrases: [
      'تلفن زنگ زد و جواب دادم.',
      'سلام، وقت بخیر، بفرمایید.',
      'درباره‌ی جلسه‌ی فردا تماس گرفته بودند.',
      'گفتم ساعت ده برای من مناسب است.',
      'آدرس را یادداشت کردم.',
      'از تماسشان تشکر کردم',
      'و با آرامش خداحافظی کردم.',
    ],
    syllables: [10, 10, 17, 14, 7, 10, 12],
  ),
  Passage(
    id: 'rain',
    title: 'باران',
    source: 'متن تمرینی گفتارین',
    audience: 'all',
    phrases: [
      'عصر آسمان ابری شد.',
      'اول چند قطره‌ی کوچک افتاد.',
      'بعد باران تند شد.',
      'بوی خاک نم‌خورده همه جا پیچید.',
      'پنجره را باز کردم و نفس عمیقی کشیدم.',
      'صدای باران آرامم می‌کرد.',
      'تا شب کنار پنجره نشستم.',
    ],
    syllables: [7, 10, 5, 12, 17, 10, 11],
  ),
  Passage(
    id: 'golestan-2',
    title: 'گلستان، حکایت اسیر',
    source: 'گلستان سعدی، باب اول',
    audience: 'adult',
    phrases: [
      'پادشاهی را شنیدم',
      'که به کشتن اسیری اشارت کرد.',
      'بیچاره در آن حالت نومیدی',
      'ملک را دشنام دادن گرفت',
      'و سقط گفتن،',
      'که گفته‌اند هر که دست از جان بشوید',
      'هر چه در دل دارد بگوید.',
    ],
    syllables: [8, 12, 11, 9, 5, 12, 9],
  ),
  Passage(
    id: 'work',
    title: 'معرفی در جلسه',
    source: 'متن تمرینی گفتارین',
    audience: 'adult',
    phrases: [
      'سلام، من سارا هستم.',
      'در بخش طراحی کار می‌کنم.',
      'پنج سال است که در این شرکت هستم.',
      'امروز می‌خواهم طرح تازه‌مان را نشان بدهم.',
      'این طرح کار مشتری را ساده‌تر می‌کند.',
      'اگر سؤالی بود، خوشحال می‌شوم بپرسید.',
      'ممنون که وقت گذاشتید.',
    ],
    syllables: [7, 10, 10, 16, 15, 14, 7],
  ),
  Passage(
    id: 'tea',
    title: 'چای عصر',
    source: 'متن تمرینی گفتارین',
    audience: 'all',
    phrases: [
      'کتری را روی گاز گذاشتم.',
      'آب که جوش آمد، چای را دم کردم.',
      'بوی هل در آشپزخانه پیچید.',
      'دو استکان روی سینی گذاشتم.',
      'مادرم از اتاق آمد.',
      'کنار پنجره نشستیم و چای خوردیم',
      'و از روزمان برای هم گفتیم.',
    ],
    syllables: [9, 10, 10, 11, 8, 13, 11],
  ),
  Passage(
    id: 'trip',
    title: 'سفر به شمال',
    source: 'متن تمرینی گفتارین',
    audience: 'adult',
    phrases: [
      'تابستان به شمال سفر کردیم.',
      'جاده از میان جنگل می‌گذشت.',
      'هوا مه‌آلود و خنک بود.',
      'کنار دریا چادر زدیم.',
      'شب صدای موج‌ها را می‌شنیدیم.',
      'صبح زود ماهیگیرها به دریا رفتند.',
      'آن سفر هنوز در یادم مانده است.',
    ],
    syllables: [10, 11, 9, 9, 11, 11, 11],
  ),
  Passage(
    id: 'park',
    title: 'گنجشک پارک',
    source: 'متن تمرینی گفتارین',
    audience: 'child',
    phrases: [
      'با بابا به پارک رفتیم.',
      'من تاب سوار شدم.',
      'تاب بالا رفت و پایین آمد.',
      'یک گنجشک روی درخت بود.',
      'برایش نان ریختم.',
      'گنجشک آمد و نان خورد.',
      'بعد با هم بستنی خوردیم.',
    ],
    syllables: [7, 6, 9, 8, 6, 7, 8],
  ),
];

Passage passageById(String id) =>
    passages.firstWhere((p) => p.id == id, orElse: () => passages.first);

/// The passage used for the first assessment (neutral modern prose).
const assessmentPassageId = 'morning';

/// Today's passage: rotates by day, preferring the user's audience.
Passage passageForDay(DateTime day, {required bool child}) {
  final pool = passages
      .where(
        (p) => p.audience == 'all' || p.audience == (child ? 'child' : 'adult'),
      )
      .toList();
  final n = DateTime(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime(2026, 1, 1)).inDays;
  return pool[n.abs() % pool.length];
}

/// Initial questionnaire about speaking confidence. Written for the app; it is
/// not a diagnostic scale. Answers 1 (never) .. 5 (always); items marked
/// `reverse` are scored the other way.
class Question {
  final String text;
  final bool reverse;
  const Question(this.text, {this.reverse = false});
}

const confidenceQuestions = <Question>[
  Question('در جمع راحت صحبت می‌کنم.'),
  Question(
    'از ترس گیر کردن، کلمه‌ای را عوض می‌کنم یا حرفم را نمی‌زنم.',
    reverse: true,
  ),
  Question('تلفن جواب دادن یا تماس گرفتن برایم سخت است.', reverse: true),
  Question('وقتی حرف می‌زنم، به نظر شنونده اهمیت زیادی می‌دهم.', reverse: true),
  Question('حرف زدن با غریبه‌ها، مثل فروشنده، برایم آسان است.'),
];

const answerLabels = ['هرگز', 'به‌ندرت', 'گاهی', 'اغلب', 'همیشه'];

/// 0..100 from answers (1..5).
int confidenceScore(List<int> answers) {
  var sum = 0;
  for (var i = 0; i < answers.length; i++) {
    final a = answers[i];
    sum += confidenceQuestions[i].reverse ? (5 - a) : (a - 1);
  }
  return (sum * 100 / (4 * answers.length)).round();
}

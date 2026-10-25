/// Reading passages. Each phrase carries a hand-counted syllable count, used
/// for the speech-rate figure. Golestan is public domain; the other passages
/// are original text written for the app.
class Passage {
  final String id;
  final String title;
  final String source;
  final String audience; // 'adult' | 'child' | 'all'
  final List<String> phrases;
  final List<int> syllables;

  const Passage({
    required this.id,
    required this.title,
    required this.source,
    required this.audience,
    required this.phrases,
    required this.syllables,
  });
}

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
];

Passage passageById(String id) => passages.firstWhere((p) => p.id == id, orElse: () => passages.first);

/// The passage used for the first assessment (neutral modern prose).
const assessmentPassageId = 'morning';

/// Today's passage: rotates by day, preferring the user's audience.
Passage passageForDay(DateTime day, {required bool child}) {
  final pool = passages.where((p) => p.audience == 'all' || p.audience == (child ? 'child' : 'adult')).toList();
  final n = DateTime(day.year, day.month, day.day).difference(DateTime(2026, 1, 1)).inDays;
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
  Question('از ترس گیر کردن، کلمه‌ای را عوض می‌کنم یا حرفم را نمی‌زنم.', reverse: true),
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

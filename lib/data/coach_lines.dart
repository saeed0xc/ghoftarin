/// What the voice coach says. The audio in assets/coach/ID.mp3 is
/// generated offline from this text (tool/make_coach.sh), so the app speaks
/// without internet. Keep lines short and calm; no countdowns, no pressure.
library;

const coachLines = <String, String>{
  'session_intro': 'یک نفس آرام بکش. وقتی دایره سبز شد، عبارت پررنگ را نرم شروع کن. عجله‌ای نیست.',
  'slow_intro': 'این دور آهسته است. صبر کن تا دایره کامل شود، بعد صدای اول را خیلی نرم، مثل یک بازدم، شروع کن.',
  'words_intro': 'هر کلمه را کشیده بگو، مثل یک آواز آهسته. صدای اول را نرم و با کمی هوا شروع کن. بین کلمه‌ها صبر کن تا دایره سبز شود.',
  'talk_intro': 'حالا آزادانه درباره‌ی موضوع صحبت کن. پیش از هر جمله یک مکث کوتاه، و شروع نرم.',
  'situation_intro': 'امروز یک موقعیت واقعی را امتحان کن. کمی اضطراب طبیعی است. مهم این است که انجامش بدهی، نه اینکه بی‌نقص باشد.',
  'session_good': 'عالی بود. مکث‌ها و شروع‌ها همان‌طور بود که باید باشد.',
  'session_ok': 'خوب بود. دفعه‌ی بعد صدای اول را کمی نرم‌تر شروع کن.',
  'session_hard':
      'امروز سخت‌تر بود و این کاملاً طبیعی است. یک دور تمرین آهسته کمک می‌کند.',
  'day_done':
      'تمرین امروز کامل شد. همین استمرار است که اثر می‌کند. فردا می‌بینمت.',
};

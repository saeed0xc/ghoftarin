/// Specific, varied feedback after a session. Each message names what went
/// well or what to change next, rather than a generic "good job".
library;

import '../audio/engine.dart';

class SessionFeedback {
  final String title;
  final String tip;

  /// Camperdown-style rule: when the trial goes poorly, go back to a slower,
  /// exaggerated practice round before trying again.
  final bool suggestSlowRound;
  const SessionFeedback(this.title, this.tip, {this.suggestSlowRound = false});
}

String _pick(List<String> options, int seed) =>
    options[seed.abs() % options.length];

SessionFeedback sessionFeedback(
  SessionSummary s, {
  required int seed,
  bool slow = false,
}) {
  if (s.phrases == 0) {
    return const SessionFeedback(
      'عبارتی شنیده نشد',
      'گوشی را نزدیک‌تر بگذار و بین عبارت‌ها کمی ساکت بمان.',
    );
  }
  final soft = s.softRatio, pause = s.pauseRatio;
  if (soft >= 0.8 && pause >= 0.8) {
    return SessionFeedback(
      _pick([
        'عالی بود، هم مکث‌ها و هم شروع‌ها',
        'یک جلسه‌ی خیلی خوب',
        'آرام و کنترل‌شده؛ همین است',
      ], seed),
      slow
          ? 'تکنیک را حس کردی. چند روز دیگر همین دور آهسته را تکرار کن تا خودکار شود؛ برنامه خودش می‌گوید کی وقت قدم بعد است.'
          : _pick([
              'حالا همین آرامش را امروز در یک گفت‌وگوی کوتاه واقعی امتحان کن.',
              'اگر سه جلسه پشت سر هم همین‌طور باشد، زمان مکث خودش کوتاه‌تر می‌شود.',
              'یک بار ضبط را گوش کن و ببین کدام شروع از همه نرم‌تر بود.',
            ], seed),
    );
  }
  if (pause < 0.6 && soft >= 0.6) {
    return SessionFeedback(
      _pick([
        'شروع‌ها خوب بود؛ مکث‌ها کوتاه',
        'نرم شروع کردی، فقط کمی عجله',
      ], seed),
      'پیش از هر عبارت بگذار دایره‌ی نفس کامل پر و سبز شود؛ لازم نیست عجله کنی. روی اندروید یک لرزش کوتاه هم آماده بودن را خبر می‌دهد.',
      suggestSlowRound: pause < 0.4,
    );
  }
  if (soft < 0.6 && pause >= 0.6) {
    return SessionFeedback(
      _pick([
        'مکث‌ها خوب بود؛ شروع‌ها را نرم‌تر کن',
        'صبر کردن را یاد گرفته‌ای؛ قدم بعد شروع نرم',
      ], seed),
      'صدای اول را با کمی هوای آزاد شروع کن، مثل یک «هـ» خیلی آهسته، و بگذار در هجای اول بلند شود.',
      suggestSlowRound: soft < 0.4,
    );
  }
  return SessionFeedback(
    _pick([
      'شروع خوبی بود؛ یک دور آهسته‌تر کمک می‌کند',
      'تمرین امروز سخت‌تر بود',
    ], seed),
    'روزهای سخت طبیعی است. یک دور تمرینی آرام‌تر با مکث بلندتر انجام بده، بعد دوباره امتحان کن.',
    suggestSlowRound: true,
  );
}

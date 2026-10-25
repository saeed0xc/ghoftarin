import '../audio/engine.dart';
import '../data/situations.dart';
import '../data/store.dart';
import '../fa.dart';

/// Plain-text progress report for the speech therapist (shared by the user;
/// nothing is sent automatically).
String buildTherapistReport(AppState app, {int days = 14}) {
  final now = DateTime.now();
  final from = now.subtract(Duration(days: days));
  final ss = app.sessionsBetween(from, now.add(const Duration(minutes: 1)));
  final all = SessionSummary.of(ss.expand((s) => s.results).toList());
  final b = StringBuffer()
    ..writeln('گزارش تمرین گفتارین — ${faDate(now)}')
    ..writeln('بازه: ${faNum(days)} روز گذشته')
    ..writeln()
    ..writeln(
      'روزهای تمرین: ${faNum(app.practiceDays(days))} از ${faNum(days)}',
    )
    ..writeln(
      'تعداد جلسه‌ها: ${faNum(ss.length)} (${faNum(all.phrases)} عبارت)',
    )
    ..writeln('زمان مکث هدف فعلی: ${faNum(app.waitTarget, 1)} ثانیه')
    ..writeln(
      'مکث کافی: ${faPercent(all.pauseRatio)} · شروع نرم: ${faPercent(all.softRatio)}',
    )
    ..writeln(
      all.eventsPer100Syllables == null
          ? 'نشانه‌های احتمالی ناروانی (خودکار، آزمایشی): قابل اندازه‌گیری نبود'
          : 'نشانه‌های احتمالی ناروانی (خودکار، آزمایشی): ${faNum(all.eventsPer100Syllables!, 1)} در هر ۱۰۰ هجا '
                '(تکرار ${faNum(all.events.repetitions)}، کشیدن ${faNum(all.events.prolongations)}، مکث درون عبارت ${faNum(all.events.blocks)})',
    )
    ..writeln(
      'میانه‌ی مکث: ${faNum(all.medianPause, 1)} ثانیه'
      '${all.meanRate == null ? '' : ' · سرعت میانگین: ${faNum(all.meanRate!, 1)} هجا در ثانیه'}',
    );
  final a = app.assessment;
  if (a != null) {
    final s = a.summary;
    b
      ..writeln()
      ..writeln('ارزیابی اولیه (${faDate(a.date)}):')
      ..writeln(
        '  شدت از نگاه خود فرد: ${faNum(a.selfRating)} از ۹ · راحتی در صحبت: ${faNum(a.confidence)} از ۱۰۰',
      )
      ..writeln(
        '  میانه‌ی مکث: ${faNum(s.medianPause, 1)} ث · شروع نرم: ${faPercent(s.softRatio)}',
      );
    if (a.ssPercent != null) {
      b.writeln(
        '  درصد هجاهای لکنت‌دار (%SS، شمارش با گوش دادن، ${a.ssRater ?? ''}): ${faNum(a.ssPercent!, 1)}٪',
      );
    }
  }
  final counted = ss.where((s) => s.ssPercent != null).toList();
  if (counted.isNotEmpty) {
    b
      ..writeln()
      ..writeln('درصد هجاهای لکنت‌دار در جلسه‌ها (شمارش با گوش دادن):')
      ..writeln(
        '  ${counted.map((s) => '${faDate(s.date).split(' ').skip(1).join(' ')}: ${faNum(s.ssPercent!, 1)}٪').join(' · ')}',
      );
  }
  final ratings = ss.where((s) => s.selfRating != null).toList();
  if (ratings.isNotEmpty) {
    b
      ..writeln()
      ..writeln('خودارزیابی روزانه‌ی شدت (۰ تا ۹، مقیاس لیدکامب):')
      ..writeln(
        '  ${ratings.map((s) => '${faDate(s.date).split(' ').skip(1).join(' ')}: ${faNum(s.selfRating!)}').join(' · ')}',
      );
  }
  final logs = app.situationLogs.where((l) => !l.date.isBefore(from)).toList();
  if (logs.isNotEmpty) {
    b
      ..writeln()
      ..writeln('موقعیت‌های واقعی:');
    for (final l in logs) {
      final t = situationById(l.situationId).title;
      b.writeln(
        l.avoided
            ? '  ${faDate(l.date)} · $t · انجام نشد (اضطراب پیش از آن ${faNum(l.anxietyBefore)}/۱۰)'
            : '  ${faDate(l.date)} · $t · اضطراب ${faNum(l.anxietyBefore)} ← ${faNum(l.anxietyAfter)} از ۱۰ · شدت ${faNum(l.severity)}/۹',
      );
    }
  }
  b
    ..writeln()
    ..writeln(
      'اندازه‌گیری‌ها خودکار و تقریبی‌اند (مکث از سکوت پیش از عبارت؛ شروع نرم از زمان اوج‌گیری صدا، آستانه‌ی ۱۵۰ میلی‌ثانیه).',
    );
  return b.toString();
}

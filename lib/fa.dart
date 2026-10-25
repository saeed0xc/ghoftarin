/// Persian number and date helpers.
library;

const _fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Converts ASCII digits to Persian and '.' to the Persian decimal mark.
String faDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final c = ch.codeUnitAt(0);
    if (c >= 48 && c <= 57) {
      b.write(_fa[c - 48]);
    } else if (ch == '.') {
      b.write('٫');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

String faNum(num n, [int decimals = 0]) =>
    faDigits(n.toStringAsFixed(decimals));

String faPercent(double ratio) => '${faNum((ratio * 100).round())}٪';

const _weekdays = [
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنج‌شنبه',
  'جمعه',
  'شنبه',
  'یکشنبه',
];
const _months = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// Gregorian → Jalali (algorithm by Borkowski / jdf).
List<int> toJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days =
      355666 +
      365 * gy +
      (gy2 + 3) ~/ 4 -
      (gy2 + 99) ~/ 100 +
      (gy2 + 399) ~/ 400 +
      gd +
      gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

/// e.g. "یکشنبه ۳ آبان"
String faDate(DateTime d) {
  final j = toJalali(d.year, d.month, d.day);
  return '${_weekdays[d.weekday - 1]} ${faNum(j[2])} ${_months[j[1] - 1]}';
}

String faTime(int hour, int minute) => faDigits(
  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
);

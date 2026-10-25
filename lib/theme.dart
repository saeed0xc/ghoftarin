import 'package:flutter/material.dart';

/// Colors from the prototype (calm teal + sage).
class C {
  static const bg = Color(0xFFF3F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const paper = Color(0xFFFBF8F1);
  static const paperLine = Color(0xFFE6E0D2);
  static const ink = Color(0xFF1F2A2E);
  static const muted = Color(0xFF5F6D72);
  static const line = Color(0xFFDCE2DE);
  static const brand = Color(0xFF3F7584);
  static const brandDark = Color(0xFF2C5763);
  static const brandSoft = Color(0xFFD5E6EA);
  static const brandTint = Color(0xFFE4EEF0);
  static const soft = Color(0xFF4D8A5C);
  static const softDark = Color(0xFF2F6B3E);
  static const softBg = Color(0xFFE2F0E5);
  static const warm = Color(0xFFB9732F);
  static const warmDark = Color(0xFF7A4A1C);
  static const warmBg = Color(0xFFFBF1E6);
  static const warn = Color(0xFFA4483A);
  static const warnBg = Color(0xFFF5E1DD);
}

const kUiFont = 'Vazirmatn';
const kBookFont = 'NotoNaskhArabic';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kUiFont,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.brand,
      primary: C.brand,
      surface: C.surface,
      onSurface: C.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: kUiFont),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: kUiFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.brandDark,
        minimumSize: const Size(48, 54),
        side: const BorderSide(color: C.line),
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: kUiFont, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.brand,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontFamily: kUiFont, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      indicatorColor: C.brandTint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: kUiFont,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? C.brandDark : C.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.brandDark : C.muted)),
    ),
    sliderTheme: const SliderThemeData(activeTrackColor: C.brand, thumbColor: C.brand, inactiveTrackColor: C.brandSoft),
  );
}

/// White rounded card used across screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.color = C.surface,
      this.border = true});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: border ? Border.all(color: C.line) : null,
        ),
        child: child,
      );
}

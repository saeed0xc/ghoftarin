import 'package:flutter/material.dart';

/// Bright, friendly palette in the style of Duolingo: green for progress and
/// main actions, blue for information, yellow for stars, orange for streaks.
class C {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const paper = Color(0xFFFFFBF0);
  static const paperLine = Color(0xFFF1E7CF);
  static const ink = Color(0xFF3C3C3C);
  static const muted = Color(0xFF6F6F6F);
  static const line = Color(0xFFE5E5E5);
  static const brand = Color(0xFF58CC02); // feather green
  static const brandDark = Color(0xFF46A302); // its shadow / text on light
  static const brandSoft = Color(0xFFD7FFB8);
  static const brandTint = Color(0xFFF0FFE4);
  static const soft = Color(0xFF58CC02);
  static const softDark = Color(0xFF3E8F02);
  static const softBg = Color(0xFFE5FFD1);
  static const warm = Color(0xFFFF9600); // fox orange
  static const warmDark = Color(0xFFB35F00);
  static const warmBg = Color(0xFFFFF0D9);
  static const warn = Color(0xFFEA2B2B);
  static const warnBg = Color(0xFFFFDFE0);
  static const blue = Color(0xFF1CB0F6); // macaw blue
  static const blueDark = Color(0xFF1899D6);
  static const blueBg = Color(0xFFDDF4FF);
  static const gold = Color(0xFFFFC800); // bee yellow
  static const goldDark = Color(0xFFE5A800);
  static const purple = Color(0xFFCE82FF);
  static const locked = Color(0xFFE5E5E5);
  static const lockedDark = Color(0xFFC7C7C7);
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
    textTheme: base.textTheme.apply(
      bodyColor: C.ink,
      displayColor: C.ink,
      fontFamily: kUiFont,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: kUiFont,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.blueDark,
        minimumSize: const Size(48, 54),
        side: const BorderSide(color: C.line, width: 2),
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: kUiFont,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.blueDark,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(
          fontFamily: kUiFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      indicatorColor: C.blueBg,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: kUiFont,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? C.blueDark : C.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? C.blueDark : C.muted,
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.brand,
      thumbColor: C.brand,
      inactiveTrackColor: C.brandSoft,
    ),
  );
}

/// White rounded card used across screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = C.surface,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: border ? Border.all(color: C.line, width: 2) : null,
    ),
    child: child,
  );
}

/// The chunky 3D button: a solid face on a darker base that sinks when
/// pressed.
class ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadow;
  final Color textColor;
  final IconData? icon;
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = C.brand,
    this.shadow = C.brandDark,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    final face = on ? widget.color : C.locked;
    final base = on ? widget.shadow : C.lockedDark;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      excludeSemantics: true,
      // screen readers (and taps routed through semantics) activate it too
      onTap: on ? widget.onPressed : null,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: on
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          margin: EdgeInsets.only(top: _down ? 4 : 0),
          padding: EdgeInsets.only(bottom: _down ? 0 : 4),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: on ? widget.textColor : C.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: on ? widget.textColor : C.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

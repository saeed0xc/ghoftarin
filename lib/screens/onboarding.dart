import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'safety.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState app;
  const OnboardingScreen({super.key, required this.app});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _child = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 56),
              child: IntrinsicHeight(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: BreathRing(progress: 0.68, label: '', size: 140)),
                  const SizedBox(height: 16),
                  const Text('گفتارین',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.brand)),
                  const SizedBox(height: 12),
                  const Text('هر روز چند دقیقه،\nآرام‌تر حرف بزن',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, height: 1.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text(
                    'تمرین روزانه با روش‌های علمی گفتاردرمانی: مکث پیش از صحبت، شروع نرم و خواندن کتاب، با بازخورد زنده روی همین گوشی.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.9, color: Color(0xFF4A5A60)),
                  ),
                  const SizedBox(height: 28),
                  const Text('این اپ برای چه کسی است؟', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _who(false, Icons.person_outline, 'برای خودم', 'نوجوان و بزرگسال')),
                    const SizedBox(width: 12),
                    Expanded(child: _who(true, Icons.family_restroom_outlined, 'برای فرزندم', 'همراه با والدین')),
                  ]),
                  const Spacer(),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      widget.app.forChild = _child;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyScreen(app: widget.app)));
                    },
                    child: const Text('شروع ارزیابی ۵ دقیقه‌ای'),
                  ),
                  const SizedBox(height: 12),
                  const Text('این اپ جایگزین گفتاردرمانگر نیست؛ کنار درمان، تمرین روزانه را آسان می‌کند.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.8, color: C.muted)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _who(bool child, IconData icon, String title, String sub) {
    final sel = _child == child;
    return Semantics(
      selected: sel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _child = child),
        child: Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? C.brand : C.line, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: C.brandDark, size: 26),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
      ),
    );
  }
}

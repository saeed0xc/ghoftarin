import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/visuals.dart';

/// Placeholder until the AI conversation partner ships (phase 2).
class TalkScreen extends StatelessWidget {
  const TalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: const [
          Text(
            'گفت‌وگو',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 24),
          Center(child: BreathRing(progress: 0.66, label: '', size: 120)),
          SizedBox(height: 20),
          Text(
            'هم‌صحبت فارسی‌زبان، به‌زودی',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          AppCard(
            child: Text(
              'در نسخه‌ی بعدی می‌توانی هر روز با «سارا» یا «آرش» درباره‌ی روزمرگی‌ها حرف بزنی. هم‌صحبت صبر می‌کند تا حلقه‌ی مکث پر شود، حرف‌هایت را یادش می‌ماند و بعد از گفت‌وگو مکث‌ها و شروع‌های نرم را نشانت می‌دهد.',
              style: TextStyle(
                fontSize: 14,
                height: 1.9,
                color: Color(0xFF33454B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

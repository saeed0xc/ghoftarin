// Renders the main screens to PNG with the real fonts, for review.
// Run: flutter test --update-goldens --tags screenshots
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goftarin/audio/engine.dart';
import 'package:goftarin/data/content.dart';
import 'package:goftarin/data/store.dart';
import 'package:goftarin/main.dart';
import 'package:goftarin/screens/onboarding.dart';
import 'package:goftarin/screens/progress.dart';
import 'package:goftarin/screens/guide.dart';
import 'package:goftarin/screens/safety.dart';
import 'package:goftarin/screens/words.dart';
import 'package:goftarin/theme.dart';
import 'package:goftarin/widgets/visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(Future.value(ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer)));
    }
    await l.load();
  }

  await family('Vazirmatn', ['Vazirmatn-Regular.ttf', 'Vazirmatn-Medium.ttf', 'Vazirmatn-Bold.ttf', 'Vazirmatn-ExtraBold.ttf']);
  await family('NotoNaskhArabic', ['NotoNaskhArabic-Regular.ttf', 'NotoNaskhArabic-SemiBold.ttf']);
  // Material icons
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? '/opt/dev/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await l.load();
  }
}

PhraseResult pr(int i, double pause, double rise, double dur, int syl, double wait) => PhraseResult(
      index: i,
      pauseSec: pause,
      early: pause < wait,
      riseMs: rise,
      onset: classifyOnset(rise, const EngineConfig()),
      durationSec: dur,
      syllablesPerSec: syl / dur,
      onsetEnvelope: const [],
    );

AppState demoState() {
  final app = AppState()
    ..onboarded = true
    ..waitTarget = 1.8
    ..reminderOn = false;
  final p = passageById('golestan-1');
  app.assessment = Assessment(
    date: DateTime.now().subtract(const Duration(days: 10)),
    results: [for (var i = 0; i < 7; i++) pr(i, 0.5 + i * 0.05, i.isEven ? 70 : 160, 2.0, p.syllables[i], 2.0)],
    confidence: 48,
    selfRating: 5,
  );
  final pauses = [
    [1.2, 2.1, 1.5, 2.2, 1.9, 0.9, 2.3],
    [2.1, 2.0, 1.6, 2.4, 2.2, 2.1, 1.4],
    [2.2, 2.3, 2.1, 1.7, 2.4, 2.0, 2.2],
    [1.9, 2.2, 2.3, 2.4, 2.1, 2.0, 2.2],
    [2.4, 2.1, 2.2, 2.0, 2.3, 1.6, 2.5],
    [2.0, 2.2, 2.4, 2.1, 2.3, 2.2, 2.0],
  ];
  final rises = [
    [80, 160, 70, 170, 120, 60, 155],
    [160, 90, 170, 150, 80, 175, 130],
    [170, 160, 85, 180, 155, 120, 165],
    [150, 175, 165, 95, 170, 160, 180],
    [180, 160, 170, 175, 140, 165, 185],
    [170, 185, 160, 175, 190, 150, 180],
  ];
  for (var d = 0; d < 6; d++) {
    app.sessions.add(SessionRecord(
      date: DateTime.now().subtract(Duration(days: 5 - d)),
      passageId: p.id,
      waitTarget: 2.0,
      results: [for (var i = 0; i < 7; i++) pr(i, pauses[d][i], rises[d][i].toDouble(), 2.2, p.syllables[i], 2.0)],
      selfRating: [5, 5, 4, 4, 3, 3][d],
    ));
  }
  return app;
}

Widget wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadFonts();
  });

  Future<void> shoot(WidgetTester t, Widget w, String name) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.77;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrap(w));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));
  }

  testWidgets('onboarding', (t) async => shoot(t, OnboardingScreen(app: AppState()), '1-onboarding'));
  testWidgets('home', (t) async => shoot(t, Shell(app: demoState()), '2-home'));
  testWidgets('progress', (t) async => shoot(t, Scaffold(body: ProgressScreen(app: demoState())), '3-progress'));
  testWidgets('reading', (t) async {
    final p = passageById('golestan-1');
    await shoot(
      t,
      Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              BookPage(source: p.source, phrases: p.phrases, current: 3),
              const SizedBox(height: 16),
              const AppCard(
                child: Column(children: [
                  BreathRing(progress: 0.6, label: '۰٫۷'),
                  SizedBox(height: 12),
                  Text('نفس بکش و صبر کن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('وقتی حلقه پر شد، عبارت پررنگ را آرام شروع کن.', style: TextStyle(fontSize: 13, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      '4-reading',
    );
  });

  testWidgets('safety', (t) async => shoot(t, SafetyScreen(app: AppState()), '5-safety'));
  testWidgets('guide', (t) async => shoot(t, const GuidePageScreen(pageId: 'soft'), '6-guide-soft'));
  testWidgets('words', (t) async {
    final app = demoState()..wordGroups = ['p', 'a']..wordStep = 1;
    await shoot(t, WordsScreen(app: app), '7-words');
  });
}

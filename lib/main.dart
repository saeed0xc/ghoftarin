import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'screens/home.dart';
import 'screens/partner_list.dart';
import 'screens/library.dart';
import 'screens/onboarding.dart';
import 'screens/progress.dart';
import 'services/reminders.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.load();
  runApp(GoftarinApp(app: app));
  // schedule the daily reminder without blocking the first frame
  if (app.onboarded && app.reminderOn) {
    Reminders.schedule(
      app.reminderHour,
      app.reminderMinute,
    ).catchError((e) => debugPrint('reminder: $e'));
  }
}

class GoftarinApp extends StatelessWidget {
  final AppState app;
  const GoftarinApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'گفتارین',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) =>
            app.onboarded ? Shell(app: app) : OnboardingScreen(app: app),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final AppState app;
  const Shell({super.key, required this.app});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(app: widget.app),
      PartnerListScreen(app: widget.app),
      LibraryScreen(app: widget.app),
      ProgressScreen(app: widget.app),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'مسیر',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'هم‌صحبت',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'تمرین‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'پیشرفت',
          ),
        ],
      ),
    );
  }
}

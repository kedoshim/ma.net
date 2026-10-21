import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/controller_screen.dart';
import 'l10n/app_localizations.dart';
import 'utils/render_watchdog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  startRenderWatchdog();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  final localeNotifier = LocaleNotifier();

  runApp(
    AppLocalizations(
      notifier: localeNotifier,
      child: const ControllerApp(),
    ),
  );
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ma•net',
      theme: ThemeData(
        fontFamily: 'momo_sans',
      ),
      locale: context.currentLocale,
      home: const ControllerScreen(),
    );
  }
}

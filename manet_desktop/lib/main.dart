import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'services/server_process_service.dart';
import 'screens/start_page/start_page_widget.dart';
import 'utils/app_logger.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  MediaKit.ensureInitialized();
  AppLogger.init();

  const options = WindowOptions(
    center: true,
    title: 'ma.net',
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  bool _isClosing = false;
  late final LocaleNotifier _localeNotifier;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _localeNotifier = LocaleNotifier();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;

    _isClosing = true;

    debugPrint('Closing app...');
    await ServerProcessService.instance.stopServer();

    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return AppLocalizations(
      notifier: _localeNotifier,
      child: Builder(
        builder: (context) {
          return MaterialApp(
            locale: context.currentLocale,
            home: const StartPageWidget(),
          );
        },
      ),
    );
  }
}
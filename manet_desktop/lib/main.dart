import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/app_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'services/sound_effect_service.dart';
import 'services/server_process_service.dart';
import 'screens/start_page/start_page_widget.dart';
import 'utils/app_logger.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  // After a hot restart the previous server is still running; stop it before
  // anything tries to start a new one on the same port.
  await ServerProcessService.instance.stopServerFromPreviousRun();
  // Preload UI sounds in the background; the start button plays one.
  SoundEffectService.instance.init();
  AppLogger.init();
  await AppPreferences.initLauncherPreferences();

  const options = WindowOptions(
    center: true,
    title: 'ma.net',
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await AppPreferences.applyFullScreen();
    await windowManager.focus();
  });

  // F11 toggles full screen and remembers the choice.
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      AppPreferences.fullScreen().then((on) => AppPreferences.setFullScreen(!on));
      return true;
    }
    return false;
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
    // Disappear immediately; stopping the server happens behind the scenes.
    await windowManager.hide();
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
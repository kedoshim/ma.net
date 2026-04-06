import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/start_page/start_page_widget.dart';
import 'screens/home_page/home_page_widget.dart';
import 'screens/home_page/gamepad_state.dart';
import 'services/host_api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ma.net',
      theme: AppTheme.theme,
      home: ChangeNotifierProvider(
        create: (context) => GamepadState(HostApiService())..initialize(),
        child: const HomePageWidget(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/server_process_service.dart';
import 'screens/start_page/start_page_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final ServerProcessService _serverService = ServerProcessService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    ServerProcessService().stopServer();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await _serverService.stopServer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const StartPageWidget(),
    );
  }
}
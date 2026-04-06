import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/controller_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ma•net',
      home: const OrientationWrapper(),
    );
  }
}

class OrientationWrapper extends StatelessWidget {
  const OrientationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (size.height > size.width) {
      final aspectHeight = size.width * 9 / 16;

      return Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: size.width,
            height: aspectHeight,
            child: const ControllerScreen(),
          ),
        ),
      );
    }

    return const ControllerScreen();
  }
}
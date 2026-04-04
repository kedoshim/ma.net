import 'package:flutter/material.dart';
import 'screens/controller_screen.dart';

void main() {
  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ma•net',
      home: const ControllerScreen(),
    );
  }
}

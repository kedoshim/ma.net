// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:controller_app/main.dart';

void main() {
  testWidgets('Controller screen loads and displays status', (WidgetTester tester) async {
    await tester.pumpWidget(const ControllerApp());

    expect(find.textContaining('Conectando'), findsOneWidget);

    // Toggle DPad switch should exist
    expect(find.byType(Switch), findsOneWidget);
  });
}

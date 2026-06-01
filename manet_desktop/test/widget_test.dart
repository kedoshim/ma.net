import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/main.dart';

void main() {
  testWidgets('Verify visual layout and flow of start page, lobby toolbar, widgets', (WidgetTester tester) async {
    // Set screen size for desktop layout
    final dpi = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(1280 * dpi, 800 * dpi);
    addTearDown(() => tester.view.resetPhysicalSize());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    // Pump frames to allow initialization, but do not wait for infinite animations to settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify start page title and start button render
    expect(find.text('ma•net'), findsOneWidget);
    expect(find.text('iniciar a festa'), findsOneWidget);
  });
}

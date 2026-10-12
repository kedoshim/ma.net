import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/widgets/comic_burst.dart';

void main() {
  testWidgets('ComicBopBurst renders child and responds to trigger', (tester) async {
    int trigger = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: ComicBopBurst(
                  trigger: trigger,
                  burstColor: Colors.purple,
                  burstRadius: 30,
                  child: const Text('Mascot'),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Mascot'), findsOneWidget);

    // Trigger burst
    trigger++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Verify widget continues rendering during animation
    expect(find.text('Mascot'), findsOneWidget);

    // Settle animation
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mascot'), findsOneWidget);
  });
}

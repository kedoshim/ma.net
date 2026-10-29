import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/widgets/ping_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'manet_locale_language_code': 'pt'}));

  test('the face gets sadder as the link gets slower', () {
    expect(pingFace(null), '...');
    expect(pingFace(12), ':D');
    expect(pingFace(80), ':)');
    expect(pingFace(150), ':|');
    expect(pingFace(200), ':(');
  });

  testWidgets('shows the latest ping as it arrives', (tester) async {
    final ping = ValueNotifier<int?>(null);
    await tester.pumpWidget(AppLocalizations(
      notifier: LocaleNotifier(),
      child: MaterialApp(home: Scaffold(body: Center(child: PingChip(ping: ping)))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('medindo ping...'), findsOneWidget);

    ping.value = 34;
    await tester.pumpAndSettle();
    expect(find.text('ping 34 ms'), findsOneWidget);
    expect(find.text(':D'), findsOneWidget);
  });
}

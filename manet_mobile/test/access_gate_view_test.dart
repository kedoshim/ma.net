import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/screens/controller_screen/access_gate_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget gate) => AppLocalizations(
  notifier: LocaleNotifier(),
  child: MaterialApp(home: Scaffold(body: Stack(children: [gate]))),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'manet_locale_language_code': 'pt'}));

  testWidgets('name step: blank is refused, no suggestion, the typed name is sent', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(AccessGateView(
      stage: AccessGateStage.name,
      onSubmitName: sent.add,
      onSubmitPassword: (_) {},
      onRetry: () {},
    )));
    await tester.pumpAndSettle();

    // Blank: an error, nothing sent.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('Escolha um nome'), findsOneWidget);

    // The player picks the name: no random suggestion.
    expect(find.byIcon(Icons.casino_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), '  Abraão  ');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(sent, ['Abraão']);
  });
}

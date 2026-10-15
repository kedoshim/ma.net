import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/player_face.dart';
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
      onSubmitName: (name, face) => sent.add('$name ${face.faceText}'),
      initialFace: const PlayerFaceData(
        color: Color(0xFF7C9CFF),
        faceText: ':)',
        rotation: PlayerFaceRotation.normal,
      ),
      onSubmitPassword: (_) {},
      onRetry: () {},
    )));
    await tester.pumpAndSettle();

    // Blank: an error, nothing sent.
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('Escolha um nome'), findsOneWidget);

    // The player picks the name: no random suggestion.
    expect(find.byIcon(Icons.casino_rounded), findsNothing);

    // Face text first (it is the first field), then the name.
    await tester.enterText(find.byType(TextField).first, 'xD');
    await tester.enterText(find.byType(TextField).last, '  Abraão  ');
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(sent, ['Abraão xD']);
  });
}

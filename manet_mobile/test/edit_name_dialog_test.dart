import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/player_face.dart';
import 'package:manet_mobile/screens/controller_screen/controller_default_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _face = PlayerFaceData(
  color: Color(0xFF7C9CFF),
  faceText: ':)',
  rotation: PlayerFaceRotation.normal,
);

Widget _app(void Function(BuildContext) open) => AppLocalizations(
  notifier: LocaleNotifier(),
  child: MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'manet_locale_language_code': 'pt'}));

  testWidgets('asking to join: the name dialog has no random-name dice', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(_app((context) => showEditNameDialog(context, '', picked.add, null, _face)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.casino_outlined), findsNothing);
    await tester.enterText(find.byType(TextField), '  Abraão ');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(picked, ['Abraão']);
  });

  testWidgets('in the lobby the dice is still there', (tester) async {
    await tester.pumpWidget(_app((context) => showEditNameDialog(context, 'Ana', (_) {}, () async => 'Zé', _face)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
  });
}

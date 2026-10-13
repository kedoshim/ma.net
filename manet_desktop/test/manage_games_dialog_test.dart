import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/screens/library/manage_games_dialog.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/session_controller.dart';

void main() {
  testWidgets('GameEditorDialog supports up to 16 players', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = HostApiService(host: '127.0.0.1', port: 8765);
    final sessionController = SessionController(api);

    await tester.pumpWidget(
      AppLocalizations(
        notifier: LocaleNotifier(),
        child: ChangeNotifierProvider.value(
          value: sessionController,
          child: const MaterialApp(
            home: Scaffold(
              body: GameEditorDialog(
                game: GameEntry(
                  id: 'mega_party',
                  name: 'Mega Party 16',
                  path: 'C:\\test\\party.exe',
                  minPlayers: 1,
                  maxPlayers: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('16'), findsWidgets);
  });
}

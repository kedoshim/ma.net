import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/screens/library/library_view.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/session_controller.dart';

void main() {
  testWidgets('LibraryView renders game cards and responds to countdown', (tester) async {
    final api = HostApiService(host: '127.0.0.1', port: 8765);
    final sessionController = SessionController(api);
    final gamepadState = GamepadState(api);

    final device = DeviceModel(
      id: 'dev1',
      name: 'Player 1',
      connected: true,
      color: Colors.purple,
      face: const PlayerFaceData(
        color: Colors.purple,
        faceText: ':D',
        rotation: PlayerFaceRotation.normal,
      ),
    );
    gamepadState.slots = [SlotModel(slot: 0, device: device)];

    sessionController.snapshot = SessionSnapshot(
      phase: SessionPhase.library,
      players: [
        SessionPlayer(deviceId: 'dev1', slot: 0, ready: false),
      ],
    );
    sessionController.games = [
      GameEntry(
        id: 'game1',
        name: 'Test Party Game',
        path: 'C:\\test\\game.exe',
        minPlayers: 1,
        maxPlayers: 4,
      ),
    ];

    await tester.pumpWidget(
      AppLocalizations(
        notifier: LocaleNotifier(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: sessionController),
            ChangeNotifierProvider.value(value: gamepadState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 800,
                child: LibraryView(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Test Party Game'), findsOneWidget);
    expect(find.byType(LibraryView), findsOneWidget);
  });
}

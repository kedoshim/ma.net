import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/network_mode_service.dart';
import 'package:manet_desktop/services/online_service.dart';
import 'package:manet_desktop/widgets/hotspot_wifi_qr.dart';
import 'package:manet_desktop/widgets/network_mode_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tunnel = OnlineStatus(
  state: OnlineState.online,
  url: 'https://quiet-fox.trycloudflare.com',
);

Future<NetworkModeService> _pump(
  WidgetTester tester,
  int port,
  Widget Function(HostApiService) build,
) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = HostApiService(host: '127.0.0.1', port: port);
  await tester.pumpWidget(
    AppLocalizations(
      notifier: LocaleNotifier(),
      child: MaterialApp(
        home: Scaffold(body: Center(child: build(api))),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return NetworkModeService.of(api);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('options panel shows one column per network in use', (
    tester,
  ) async {
    final network = await _pump(
      tester,
      11,
      (api) => NetworkOptionsPanel(api: api),
    );
    final strings = tester
        .element(find.byType(NetworkOptionsPanel))
        .l10n
        .network;

    expect(find.text(strings.localColumn), findsOneWidget);
    expect(find.text(strings.onlineColumn), findsNothing);

    await tester.tap(find.text(strings.modeBoth).first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(network.value.mode, NetworkMode.both);
    expect(find.text(strings.localColumn), findsOneWidget);
    expect(find.text(strings.onlineColumn), findsOneWidget);

    await tester.tap(find.text(strings.modeOnline).first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(strings.localColumn), findsNothing);
    expect(find.text(strings.onlineColumn), findsOneWidget);
    expect(
      await SharedPreferences.getInstance().then(
        (p) => p.getString('network_mode'),
      ),
      'online',
    );
  });

  testWidgets(
    'QR switch only in "both" with the tunnel up, and it picks the QR',
    (tester) async {
      final network = await _pump(
        tester,
        12,
        (api) => QrTargetSwitch(api: api),
      );
      final switchFinder = find.byKey(const ValueKey('qr-target-switch'));

      network.online.value = _tunnel;
      await tester.pump();
      expect(switchFinder, findsNothing);
      expect(network.effectiveTarget, QrTarget.local);

      await network.setMode(NetworkMode.both);
      network.online.value = _tunnel;
      await tester.pump();
      expect(switchFinder, findsOneWidget);
      // Turning the tunnel on points the QR at it.
      expect(network.effectiveTarget, QrTarget.online);
      expect(network.onlineConnection?.kind, 'internet');

      final strings = tester.element(switchFinder).l10n.network;
      await tester.tap(find.text(strings.modeLocal));
      await tester.pump();
      expect(network.effectiveTarget, QrTarget.local);
      expect(network.onlineConnection, isNull);

      await network.setMode(NetworkMode.online);
      network.online.value = _tunnel;
      await tester.pump();
      expect(switchFinder, findsNothing);
      expect(network.effectiveTarget, QrTarget.online);
    },
  );

  testWidgets('hotspot Wi-Fi QR only while the local QR is shown', (
    tester,
  ) async {
    final network = await _pump(tester, 13, (api) => HotspotWifiQr(api: api));
    final strings = tester.element(find.byType(HotspotWifiQr)).l10n.network;

    expect(find.text(strings.wifiQrTitle), findsNothing);

    network.value = network.value.copyWith(
      hotspot: const HotspotStatus(
        active: true,
        ssid: 'MANET-PC',
        hasPassword: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(strings.wifiQrTitle), findsOneWidget);
    expect(find.text(strings.wifiQrCaption('MANET-PC')), findsOneWidget);

    await network.setMode(NetworkMode.online);
    network.online.value = _tunnel;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(strings.wifiQrTitle), findsNothing);
  });

  testWidgets('QR switch shrinks to fit a narrow QR card', (tester) async {
    final network = await _pump(
      tester,
      14,
      (api) => SizedBox(
        width: 110,
        child: QrTargetSwitch(api: api, height: 48, fontSize: 18),
      ),
    );
    await network.setMode(NetworkMode.both);
    network.online.value = _tunnel;
    await tester.pump();
    expect(find.byKey(const ValueKey('qr-target-switch')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(QrTargetSwitch)).width, lessThanOrEqualTo(110));
  });
}

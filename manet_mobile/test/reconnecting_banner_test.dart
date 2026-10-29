import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/l10n/en_us.dart';
import 'package:manet_mobile/widgets/reconnecting_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _strings = EnUsDisconnectStrings();

Widget _app(Widget child) => AppLocalizations(
  notifier: LocaleNotifier(),
  child: MaterialApp(home: Scaffold(body: Center(child: child))),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'manet_locale_language_code': 'en'}));

  testWidgets('says reconnecting, adds the hint only after a while, tap retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_app(
      ReconnectingBanner(since: DateTime.now(), onTapRetry: () => retries++),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_strings.reconnecting), findsOneWidget);
    expect(find.text(_strings.stillTrying), findsNothing);

    await tester.pump(ReconnectingBanner.hintAfter);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_strings.stillTrying), findsOneWidget);

    await tester.tap(find.text(_strings.reconnecting));
    expect(retries, 1);
  });

  testWidgets('a long wait shows the hint right away', (tester) async {
    await tester.pumpWidget(_app(
      ReconnectingBanner(
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        onTapRetry: () {},
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_strings.stillTrying), findsOneWidget);
  });
}

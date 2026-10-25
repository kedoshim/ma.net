import 'package:flutter/widgets.dart';

import 'phone_game_frame_stub.dart'
    if (dart.library.html) 'phone_game_frame_web.dart' as impl;

/// The phone game's page in an iframe. Web only (the pad page is the only
/// place a browser game can live next to the pad); empty elsewhere.
Widget buildPhoneGameFrame(String url) => impl.buildPhoneGameFrame(url);

/// Lets Flutter get the touches on [child] while it's drawn over the game:
/// a page's iframe sits above Flutter's own touch handling, so without this
/// the Home button (and the pad, and the menu) only looked tappable and
/// their taps went to the game.
Widget phoneGameTouchShield(Widget child) => impl.phoneGameTouchShield(child);

/// The browser's back (button or gesture) would leave the pad page, and
/// the phone its seat. While a game is open it calls [onBack] instead.
void watchPhoneGameBack(void Function() onBack) =>
    impl.watchPhoneGameBack(onBack);

void stopWatchingPhoneGameBack() => impl.stopWatchingPhoneGameBack();

bool get isPhoneGameSupported => impl.isPhoneGameSupported;

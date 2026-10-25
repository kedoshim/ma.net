// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViews = {};

Widget buildPhoneGameFrame(String url) {
  final viewType = 'phone-game-${url.hashCode}';
  if (_registeredViews.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'white'
        ..allow = 'autoplay; clipboard-write; fullscreen'
        ..allowFullscreen = true;
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}

// An empty element over the iframe: touches on it reach the page, where
// Flutter reads them as usual (what package:pointer_interceptor does).
const _shieldViewType = 'phone-game-touch-shield';

Widget phoneGameTouchShield(Widget child) {
  if (_registeredViews.add(_shieldViewType)) {
    ui_web.platformViewRegistry.registerViewFactory(_shieldViewType, (int _) {
      return html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }
  return Stack(
    children: [
      const Positioned.fill(
        child: HtmlElementView(viewType: _shieldViewType),
      ),
      child,
    ],
  );
}

// One entry of our own on top of the history: back pops it (instead of the
// pad page) and it's put back, so the next back lands here again.
StreamSubscription<html.PopStateEvent>? _backWatch;

void watchPhoneGameBack(void Function() onBack) {
  stopWatchingPhoneGameBack();
  html.window.history.pushState({'manetPhoneGame': true}, '', null);
  _backWatch = html.window.onPopState.listen((_) {
    html.window.history.pushState({'manetPhoneGame': true}, '', null);
    onBack();
  });
}

void stopWatchingPhoneGameBack() {
  _backWatch?.cancel();
  _backWatch = null;
}

bool get isPhoneGameSupported => true;

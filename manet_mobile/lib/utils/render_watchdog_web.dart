import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/scheduler.dart';

import 'render_watchdog_check.dart';

// When a tab goes to the background the browser may drop its WebGL context.
// Flutter then makes a new one, but only on its next frame, and nothing asks
// for a frame when the tab comes back: the pad stays blank (touches still
// work) until something on screen changes. So a frame is forced on return,
// and if a canvas is still dead after that the page is reloaded (the phone
// keeps its device id, so it takes its seat back).

const _checkEvery = Duration(seconds: 2);
const _reloadKey = 'manet_render_reload_at';
const _minReloadGap = Duration(seconds: 30);

bool _started = false;

// Walks the whole page on every check (see RenderWatchdogCheck for why a
// cached list of canvases broke this).
final _watch = RenderWatchdogCheck<html.CanvasElement>(
  findCanvases: () => _flutterCanvases(html.document.querySelectorAll('*')),
  isLost: _contextLost,
);

void startRenderWatchdog() {
  if (_started) return;
  _started = true;
  html.document.onVisibilityChange.listen((_) {
    if (html.document.hidden == true) {
      _watch.tabHidden();
      return;
    }
    _repaintSoon();
  });
  html.window.onPageShow.listen((_) => _repaintSoon());
  Timer.periodic(_checkEvery, (_) => _check());
}

void _repaint() => SchedulerBinding.instance.scheduleForcedFrame();

void _repaintSoon() {
  // The context-lost event can arrive a little after the tab is visible.
  _repaint();
  Timer(const Duration(milliseconds: 300), _repaint);
  Timer(const Duration(seconds: 1), _repaint);
}

void _check() {
  if (html.document.hidden == true) return;
  switch (_watch.check()) {
    case WatchdogAction.none:
      break;
    case WatchdogAction.repaint:
      _repaint();
    case WatchdogAction.reload:
      _reload();
  }
}

bool _contextLost(html.CanvasElement canvas) {
  // Only looks up the canvas's existing context: Flutter's canvases always
  // have one, and asking for another type returns null.
  final context = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
  if (context == null) return false;
  try {
    return js_util.callMethod<bool>(context, 'isContextLost', const []) == true;
  } catch (_) {
    return false;
  }
}

/// Flutter's <canvas> elements, which live in shadow roots.
Iterable<html.CanvasElement> _flutterCanvases(List<html.Element> elements) sync* {
  for (final element in elements) {
    if (element is html.CanvasElement &&
        element.parent?.tagName.toLowerCase() == 'flt-canvas-container') {
      yield element;
    }
    final shadow = element.shadowRoot;
    if (shadow != null) yield* _flutterCanvases(shadow.querySelectorAll('*'));
  }
}

void _reload() {
  final storage = html.window.sessionStorage;
  final now = DateTime.now().millisecondsSinceEpoch;
  final last = int.tryParse(storage[_reloadKey] ?? '') ?? 0;
  if (now - last < _minReloadGap.inMilliseconds) return; // don't loop
  storage[_reloadKey] = '$now';
  html.window.location.reload();
}

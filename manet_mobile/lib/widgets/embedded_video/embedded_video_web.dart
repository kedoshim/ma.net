// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViews = {};

Widget buildEmbeddedVideo(String videoId) {
  final viewType = 'youtube-trailer-$videoId';
  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&rel=0'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        return iframe;
      },
    );
  }

  return HtmlElementView(viewType: viewType);
}

// hls.js plays HLS (Steam trailers) in browsers without native support
// (Chrome, Firefox); Safari plays it natively.
const String _hlsScript = 'https://cdn.jsdelivr.net/npm/hls.js@1.5.13/dist/hls.min.js';
Future<void>? _hlsLoading;
js.JsObject? _activeHls;

Future<void> _loadHls() {
  if (js.context.hasProperty('Hls')) return Future.value();
  return _hlsLoading ??= () {
    final done = Completer<void>();
    final script = html.ScriptElement()
      ..src = _hlsScript
      ..async = true;
    script.onLoad.first.then((_) => done.complete());
    script.onError.first.then((_) {
      _hlsLoading = null;
      done.completeError('hls.js failed to load');
    });
    html.document.head!.append(script);
    return done.future;
  }();
}

Widget buildEmbeddedStream(String url) {
  final viewType = 'stream-trailer-${url.hashCode}';
  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final video = html.VideoElement()
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..setAttribute('playsinline', 'true');
      _attach(video, url);
      return video;
    });
  }
  return HtmlElementView(viewType: viewType);
}

Future<void> _attach(html.VideoElement video, String url) async {
  stopEmbeddedStreams();
  final hls = url.toLowerCase().contains('.m3u8');
  if (!hls) {
    video.src = url;
    return;
  }
  try {
    await _loadHls();
    final hlsClass = js.context['Hls'] as js.JsFunction;
    if (hlsClass.callMethod('isSupported') == true) {
      final player = js.JsObject(hlsClass);
      player.callMethod('loadSource', [url]);
      player.callMethod('attachMedia', [video]);
      _activeHls = player;
      return;
    }
  } catch (_) {}
  // Safari (and hls.js unavailable): native HLS.
  video.src = url;
}

void stopEmbeddedStreams() {
  _activeHls?.callMethod('destroy');
  _activeHls = null;
}

bool get isEmbeddedVideoSupported => true;
